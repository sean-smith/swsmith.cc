---
title: Mount FSx Netapp ONTAP with AWS ParallelCluster
description:
date: 2022-05-16
tldr: Multi-Protocol filesystem for AWS ParallelCluster
draft: false
tags: [fsx, AWS ParallelCluster, hpc, s3, aws]
---

FSx Netapp ONTAP is a multi-protocol filesystem. It mounts on Windows as SMB, Linux as NFS and Mac. This allows cluster users to bridge their Windows and Linux machines with the same filesystem, potentially running both windows and linux machines for a post-processing workflow.

Since 3.2.0, FSx Netapp is a [supported filesystem](https://docs.aws.amazon.com/parallelcluster/latest/ug/SharedStorage-v3.html#SharedStorage-v3-FsxOntapSettings) type in AWS ParallelCluster, this means you can mount the filesystem directly through the config without having to specify a post-install script. For older versions and more flexibility i.e. custom the mount options, I've included the post-install script method as well.

![FSx Netapp Ontap Mounted on pcluster Architecture](/img/fsxn-pcluster/architecture.png)

**Pros**

* Multi-Protocol
* Hybrid support
* Multi-AZ (for High Availibility)

**Cons**

* Not as fast as FSx Lustre
* Harder to Setup with AWS ParallelCluster

In this guide we walk through how to create a FSx Netapp filesystem and how to mount it to parallelcluster. We will cover the steps needed to bridge this filesystem to on-prem in another doc.

## 1. Create Filesystem

1. Go to the [FSx Console](https://console.aws.amazon.com/fsx/home?) > **Create Filesystem** > Select FSx Netapp

2. Now set the filesystem name, select the **same VPC as the cluster**, and set the storage size:

    ![Storage Size](/img/fsxn-pcluster/create-fs.png)

Wait **~15 minutes** for the filesystem to create.

## 2. Modify Route Table

1. Go to the [FSx Console](https://console.aws.amazon.com/fsx/home?) > Select the filesystem
1. Under the Network & Security > Click on the Route Table:

    ![Route Table](/img/fsxn-pcluster/routetable.png)

1. Modify the Subnet association for the Route Table
1. Add the subnet that the cluster was launched in

    ![Subnets](/img/fsxn-pcluster/subnets.png)

## 3. Modify Security Group

Next we're going to add a new rule to FSxN's Security Group. To find the security group we need to scroll down the ENI.

1. Go to the [FSx Console](https://console.aws.amazon.com/fsx/home) > Select the filesystem
2. Then scroll down to the **Preferred subnet** > Click on the Elastic Network Interface (ENI):

    ![ENI](/img/fsxn-pcluster/eni.png)

3. Now check the box next to the ENI and scroll down to find the associated Security Group:

    ![Security Group](/img/fsxn-pcluster/security-group.png)

4. On that Security Group, Add a **Ingress rule** that allows **all traffic** from the **VPC's CIDR** range. If you'd like to be more specific, you can only allow the [ports specificied in the FSxN docs](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/limit-access-security-groups.html).

    | Rule      | CIDR Range | Description |
    | ----------- | ----------- | ----------- |
    | All Traffic      | 172.31.0.0/16       | FSx Netapp Ingress

    ![Security Group Rule](/img/fsxn-pcluster/security-group-rule.png)

## 4. Mount to Cluster (≥3.2.0)

In AWS ParallelCluster 3.2.0, simply select **FSx Netapp Ontap** from the filesystem types and select the filesystem id of the filesystem you created above:

![ParallelCluster Manager FSx Netapp Ontap](/img/fsxn-pcluster/pcm-fsxn.png)

If you're using the CLI, you'll specify a new Shared Filesystem in your [SharedStorage](https://docs.aws.amazon.com/parallelcluster/latest/ug/SharedStorage-v3.html#SharedStorage-v3.properties) section:

```yaml
- MountDir: /shared
  Name: FSxNetapOntap
  StorageType: FsxOntap
  FsxOntapSettings:
    VolumeId: fs-123456789
```

## 5. Mount to Cluster (<3.2.0)

If you're using a cluster with version < 3.2.0, or simply want more flexibility in the mount command, you can follow the next few steps to attach the filesystem to the cluster using a [Slurm Prolog](https://slurm.schedmd.com/prolog_epilog.html) script. Note, the following script only needs to be run on the **HeadNode** and can be done via a CustomAction, aka post-install script, or simply run on the **HeadNode** with no modification to the parallelcluster config.

1. First create a script called `mount-fsxn.sh` with the following content:

    ```bash
    #!/bin/bash

    # usage: mount-fsxn.sh svm-0b28f18aab8cea77a.fs-0464c49bc5b02f3c4.fsx.us-east-2.amazonaws.com /fsx

    FSX_DNS=$1
    MOUNT_DIR=$2

    . /etc/parallelcluster/cfnconfig
    test "$cfn_node_type" != "HeadNode" && exit

    # create a directory
    mkdir -p ${MOUNT_DIR}

    # mount on head node
    sudo mount -t nfs $FSX_DNS:/vol1 $MOUNT_DIR

    cat << EOF > /opt/slurm/etc/prolog.sh
    #!/bin/sh

    if mount | /bin/grep -q ${MOUNT_DIR} ; then
    exit 0
    else
    # create a directory
    mkdir -p ${MOUNT_DIR}

    # mount on compute node
    mount -t nfs $FSX_DNS:/vol1 $MOUNT_DIR
    fi
    EOF
    chmod 744 /opt/slurm/etc/prolog.sh

    echo "Prolog=/opt/slurm/etc/prolog.sh" >> /opt/slurm/etc/slurm.conf
    systemctl restart slurmctld
    ```

2. Upload `mount-fsxn.sh` to a S3 bucket:

    ```bash
    aws s3 cp mount.sh s3://bucket/mount-fsxn.sh
    ```

3. Include the following in your cluster's config in the [HeadNode/CustomActions](https://docs.aws.amazon.com/parallelcluster/latest/ug/HeadNode-v3.html#HeadNode-v3-CustomActions) section:

    ```yaml
    OnNodeConfigured:
      Script: s3://bucket/mount-fsxn.sh
      Args:
        - svm-0b28f18aab8cea77a.fs-0464c49bc5b02f3c4.fsx.us-east-2.amazonaws.com
        - /fsx
    Iam:
      S3Access:
        - BucketName: bucket
    ```
