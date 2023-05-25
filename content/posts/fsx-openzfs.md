---
title: Setup Amazon FSx for OpenZFS with AWS ParallelCluster 🗂
description:
date: 2023-05-24
tldr: Mount a managed OpenZFS filesystem on your cluster.
draft: false
og_image: /img/fsx-openzfs/logo.png
tags: [FSx OpenZFS, AWS ParallelCluster, hpc, s3, aws]
---

{{< rawhtml >}}
<p align="center">
    <img src='/img/fsx-openzfs/logo.png' alt='FSx OpenZFS Logo' style='border: 0px; width: 200px;' />
</p>
{{< /rawhtml >}}

[FSx OpenZFS](https://aws.amazon.com/fsx/openzfs/) is a new filesystem offering that provides a managed OpenZFS filesystem. In previous blogposts we've showed how to use [FSx Lustre](fsx-persistent-2-pcluster.html), [FSx Netapp Ontap](fsxn-pcluster.html) and [EFS](aws-parallelcluster-multi-fs.html) with AWS ParallelCluster. In this blogpost we'll show you how to create and mount OpenZFS filesystems on ParallelCluster. Before we start, when should you use OpenZFS?

## So when should you **use** FSx OpenZFS?

* NFS compliant filesystem
* Fast filesystem performance for [30% cheaper](https://aws.amazon.com/fsx/openzfs/pricing/) than FSx Lustre
* Built in support for backups
* Multi-AZ support

## So when shouldn't you use FSx OpenZFS?

* Syncing data from a S3 Bucket in the same region. There's no native S3 integration, just use [FSx Lustre](fsx-persistent-2-pcluster.html).

## Setup

From the FSx OpenZFS [docs](https://docs.aws.amazon.com/fsx/latest/OpenZFSGuide/limit-access-security-groups.html#create-security-group) we learn that the following ports are required:

| Protocol | Ports         | Role                                       |
|----------|---------------|--------------------------------------------|
| TCP      | 111           | Remote procedure call for NFS              |
| UDP      | 111           | Remote procedure call for NFS              |
| TCP      | 2049          | NFS server daemon                          |
| UDP      | 2049          | NFS server daemon                          |
| TCP      | 20001 - 20003 | NFS mount, status monitor, and lock daemon |
| UDP      | 20001 - 20003 | NFS mount, status monitor, and lock daemon |

So we'll need to:

1. Create the Security Group
2. Create the filesystem & associate the security group
3. Create a cluster that mounts the filesystem

Since OpenZFS is built with NFS support, it requires no extra installation in AWS ParallelCluster image. We just need to mount the filesystem.

## 1. Create Security Group

1. Create a new Security Group by going to [Security Groups](https://console.aws.amazon.com/ec2/v2/home?#SecurityGroups:) > **Create Security Group**:

    * **Name** `FSx OpenZFS`
    * **Description** `Allow FSx OpenZFS to mount to ParallelCluster`
    * **VPC** `Same as pcluster vpc`

2. Create new **Inbound Rule**s, one for each port:

    | Protocol | Ports         | Role                                       |
    |----------|---------------|--------------------------------------------|
    | TCP      | 111           | Remote procedure call for NFS              |
    | UDP      | 111           | Remote procedure call for NFS              |
    | TCP      | 2049          | NFS server daemon                          |
    | UDP      | 2049          | NFS server daemon                          |
    | TCP      | 20001 - 20003 | NFS mount, status monitor, and lock daemon |
    | UDP      | 20001 - 20003 | NFS mount, status monitor, and lock daemon |

    i.e.

    * Custom TCP
    * Port `111`
    * Same CIDR as the VPC `10.0.0.0/16`

    ![Inbound Rules](/img/fsx-openzfs/inbound.png)

3. Leave **Outbound Rules** as the default:

    ![Outbound Rules](/img/fsx-openzfs/outbound.png)

## 2. Create FSx OpenZFS

1. Go to the [Amazon Console](https://console.aws.amazon.com/fsx/home?#file-systems) and click **Create FSx OpenZFS**.
2. Next give it a name and set the size, (smallest is `64 GB`)
3. On the next section specify the same VPC and subnet as your cluster.

    ![Setup Details](/img/fsx-openzfs/setup.png)

4.  Select the same Security Group you created earlier.

## 4. Attach Filesystem to AWS ParallelCluster

1. After the filesystem has finished creating, grab the mount command from the Amazon console:

    ![Mount Command](/img/fsx-openzfs/mount.png)

    We'll use the DNS name (including mount dir) to mount the filesystem below.

2. SSH into the HeadNode and create a script `mount-openzfs.sh` with the following content:

    ```bash
    #!/bin/bash

    # usage: mount-openzfs.sh fs-0177ce25ef8827c06.fsx.us-east-2.amazonaws.com:/fsx /zfs

    FSX_DNS=$1
    MOUNT_DIR=$2

    . /etc/parallelcluster/cfnconfig
    test "$cfn_node_type" != "HeadNode" && exit

    # create a directory
    mkdir -p ${MOUNT_DIR}

    # mount on head node
    sudo mount -t nfs -o nfsvers=4.1 ${FSX_DNS} ${MOUNT_DIR}

    cat << EOF > /opt/slurm/etc/prolog.sh
    #!/bin/sh

    if mount | /bin/grep -q ${MOUNT_DIR} ; then
    exit 0
    else

    # create a directory
    sudo mkdir -p ${MOUNT_DIR}

    # mount on compute node
    sudo mount -t nfs -o nfsvers=4.1 ${FSX_DNS} ${MOUNT_DIR}
    fi
    EOF
    chmod 744 /opt/slurm/etc/prolog.sh

    echo "Prolog=/opt/slurm/etc/prolog.sh" >> /opt/slurm/etc/slurm.conf
    systemctl restart slurmctld
    ```

3. Then run it from the HeadNode, specifying the filesystem DNS and mount directory like so:

    ```bash
    FSX_DNS=fs-0177ce25ef8827c06.fsx.us-east-2.amazonaws.com:/fsx
    MOUNT_DIR=/zfs
    sudo bash mount-zfs.sh ${FSX_DNS} ${MOUNT_DIR}
    ```

4. To verify that the filesystem mounted properly, you can run `df -h`. You should see a line like:

    ```bash
    df -h
    ...
    172.31.47.168@tcp:/wwu73bmv  1.2T   11M  1.2T   1% /zfs
    ```

5. Next let's allocate a compute node to ensure it gets mounted there as well:

    ```bash
    salloc -N 1
    # wait 2 minutes
    watch squeue
    # ssh into compute node once job goes into R
    ssh queue0-dy-queue0-hpc6a48xlarge-1
    ```

    If all worked properly you should again see:

    ```bash
    df -h
    ...
    172.31.47.168@tcp:/wwu73bmv  1.2T   11M  1.2T   1% /zfs
    ```
