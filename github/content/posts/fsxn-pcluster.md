---
title: Setup FSx Netapp Ontap with AWS ParallelCluster
description:
date: 2022-05-16
tldr: Multi-Protocol filesystem for AWS ParallelCluster
draft: false
tags: [fsx, AWS ParallelCluster, hpc, s3, aws]
---

# Mount FSx Netapp ONTAP with AWS ParallelCluster

FSx Netapp is a multi-protocol filesystem. It mounts on Windows as SMB, Linux as NFS and Mac. This allows cluster users to bridge their Windows and Linux machines with the same filesystem, potentially running both windows and linux machines for a post-processing workflow.

![Screen Shot 2022-03-07 at 5 29 23 PM](https://user-images.githubusercontent.com/5545980/157135878-f09c8b92-a536-4cb9-85a7-30fab9d8a588.png)

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

<img width="817" alt="image" src="https://user-images.githubusercontent.com/5545980/156285092-e376a42e-dc27-451a-ba96-0ef44ff7c48b.png">

Wait **~15 minutes** for the filesystem to create.

## 2. Modify Route Table

1. Go to the [FSx Console](https://console.aws.amazon.com/fsx/home?) > Select the filesystem
2. Click on the Route Table:

<img width="654" alt="Screen Shot 2022-03-01 at 6 51 32 PM" src="https://user-images.githubusercontent.com/5545980/156286373-b00b0b15-4bd1-4f62-8898-cd379625704b.png">

3. Modify the Subnet association for the Route Table
4. Add the subnet that the cluster is launched 

<img width="692" alt="image" src="https://user-images.githubusercontent.com/5545980/156286016-c717bbbf-e1c3-4d95-86a4-f23dd1bad259.png">

## 3. Modify Security Group

Next we're going to add a new rule to FSxN's Security Group. To find the security group we need to scroll down the 

1. Go to the FSx Console > Select the filesystem
2. Then scroll down to the **Preferred subnet** > Click on the Elastic Network Interface (ENI):

<img width="658" alt="Screen Shot 2022-03-01 at 7 06 09 PM" src="https://user-images.githubusercontent.com/5545980/156287433-3b2e772d-c891-4394-bf5b-3aabc38ef92e.png">

3. Now check the box next to the ENI and scroll down to find the associated Security Group:

<img width="1181" alt="Screen Shot 2022-03-01 at 7 08 50 PM" src="https://user-images.githubusercontent.com/5545980/156287708-246ead2a-f557-45cd-9848-3332043a2731.png">

4. On that Security Group, Add a **Ingress rule** that allows **all traffic** from the **VPC's CIDR** range. If you'd like to be more specific, you can only allow the [ports specificied in the FSxN docs](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/limit-access-security-groups.html).

| Rule      | CIDR Range | Description |
| ----------- | ----------- | ----------- |
| All Traffic      | 172.31.0.0/16       | FSx Netapp Ingress

<img width="1307" alt="image" src="https://user-images.githubusercontent.com/5545980/156286699-9ea9508e-8def-439c-b3ae-6e137b7b0e8e.png">



## 4. Mount to Cluster

Next we'll mount the filesystem on the cluster using a Slurm [Prolog](https://slurm.schedmd.com/prolog_epilog.html) script. This is only required to run on the head node.

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