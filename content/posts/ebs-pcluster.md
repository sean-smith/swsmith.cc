---
title: Local Storage for HPC Jobs with EBS 🗂
description: 
date: 2022-11-08
tldr: Setup Elastic Block Storage (EBS) on compute nodes with AWS ParallelCluster
draft: false
og_image: /img/ebs-pcluster/architecture.png
tags: [aws parallelcluster, ebs, aws]
---

![Architecture Diagram](/img/ebs-pcluster/architecture.png)

In previous blogposts we looked at several approaches to add shared storage to a cluster, these all focus on mounting a **shared filesystem**. If you have Multi-Node (MPI) style jobs, this is likely a requirement. You can follow those guides below:

* [Mount FSx Netapp ONTAP with AWS ParallelCluster](/posts/fsxn-pcluster.html)
* [Setup FSx Lustre PERSISTENT_2 with AWS ParallelCluster](/posts/fsx-persistent-2-pcluster.html)
* [Mount Additional EFS/FSx Lustre Filesystems in AWS ParallelCluster](/posts/aws-parallelcluster-multi-fs.html)

Let's say you don't need shared storage but rather local storage on each compute node. There's several ways to do this, by far the easiest is to just use an instance with local storage, instances such as the [c6id.32xlarge](https://aws.amazon.com/ec2/instance-types/c6i/), or any instance with a **d** in the name, have local NVME backed storage. This is [automatically mounted](https://docs.aws.amazon.com/parallelcluster/latest/ug/Scheduling-v3.html#yaml-Scheduling-SlurmQueues-ComputeSettings-LocalStorage-EphemeralVolume) at `/scratch` on the compute nodes.

Let's say you want to use a an instance type that doesn't have NVME but you want fast local storage mounted on that instance. Your next best option to mount an additional EBS drive to the instance.

## Setup

1. Create a script called `attach_ebs.sh`  with the following content:

    ```bash
    #!/bin/sh
    # copyright Sean Smith <seaam@amazon.com>
    # attach_ebs.sh - Attach an EBS volume to an EC2 instance.

    #   Usage:
    #   attach_ebs.sh /scratch gp2|gp3|io1|io2 100 /dev/xvdb
    #
    #   1. Create a EBS volume
    #   2. Wait for it to become availible
    #   3. Mount it
    #   4. Format filesystem

    mount_point="${1:-/scratch}"
    type="${2:-gp3}"
    size="${3:-100}"

    az=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
    instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

    # 1. create ebs volume
    volume_id=$(aws ec2 --region $region create-volume \
        --availability-zone ${az} \
        --volume-type ${type} \
        --size ${size} | jq -r .VolumeId)
    echo "Created $volume_id..."

    # 2. wait for volume to create
    aws ec2 --region $region wait volume-available \
        --volume-ids ${volume_id}

    # 3. attach volume
    aws ec2 --region $region attach-volume \
        --device /dev/sdf \
        --instance-id ${instance_id} \
        --volume-id ${volume_id}

    # 4. format filesystem
    mkfs -t ext4 /dev/xvdf

    # 5. mount filesystem
    mkdir -p ${mount_point}
    mount /dev/xvdf ${mount_point}
    ```

2. Upload it to an S3 bucket

    ```bash
    aws s3 cp attach_ebs.sh s3://bucket/
    ```

3. Create a cluster with AWS ParallelCluster and specify `attach_ebs.sh` as a [post install script](https://docs.aws.amazon.com/parallelcluster/latest/ug/custom-bootstrap-actions-v3.html).

    * In addition you'll need the IAM policies `arn:aws:iam::aws:policy/AmazonEC2FullAccess` and `arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess`

    ![PCM Post Install Script](/img/ebs-pcluster/post-install.png)

    The config will look something like:

```yaml
HeadNode:
InstanceType: t3.micro
Ssh:
    KeyName: amzn2
Networking:
    SubnetId: subnet-8b15a7c6
LocalStorage:
    RootVolume:
    VolumeType: gp3
Iam:
    AdditionalIamPolicies:
    - Policy: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
    - Policy: arn:aws:iam::aws:policy/AmazonEC2FullAccess
    - Policy: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
Scheduling:
Scheduler: slurm
SlurmQueues:
    - Name: queue0
    ComputeResources:
        - Name: queue0-t32xlarge
        MinCount: 0
        MaxCount: 4
        InstanceType: t3.2xlarge
    Networking:
        SubnetIds:
        - subnet-8b15a7c6
    ComputeSettings:
        LocalStorage:
        RootVolume:
            VolumeType: gp3
    CustomActions:
        OnNodeConfigured:
        Script: s3://spack-swsmith/attach_ebs.sh
        Args:
            - /scratch
            - gp3
            - '100'
    Iam:
        AdditionalIamPolicies:
        - Policy: arn:aws:iam::aws:policy/AmazonEC2FullAccess
        - Policy: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
Region: us-east-2
Image:
Os: alinux2
```

## Test

After the cluster has finished creating, ssh in and spin up a compute node:

```bash
salloc -N 1 
watch squeue
# wait a few minutes until job goes into 'R' running
ssh queue0-dy-queue0-c52xlarge-1
```

On the compute node you'll see the `/scratch` directory mounted & with the correct storage size:

```bash
[ec2-user@ip-172-31-42-37 scratch]$ df -h
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        473M     0  473M   0% /dev
tmpfs           483M     0  483M   0% /dev/shm
tmpfs           483M  568K  483M   1% /run
tmpfs           483M     0  483M   0% /sys/fs/cgroup
/dev/xvda1       35G   16G   20G  45% /
tmpfs            97M     0   97M   0% /run/user/0
/dev/xvdf        99G   24K   94G   1% /scratch
```

That's it!

## Debug

If the instance fails to create, you can debug it by looking at the `/var/log/cloud-init-output.log` file. Common errors include:

* IAM Permissions, make sure to attach the `EC2FullAccess` policy. Note parallelcluster manager needs additional permissions to allow you to attach that policy. You can add them by following instructions [here](https://pcluster.cloud/02-tutorials/02-slurm-accounting.html#step-3---add-permissions-to-your-lambda). This looks like:
```
An error occurred (UnauthorizedOperation) when calling the CreateVolume operation: You are not authorized to perform this operation. Encoded authorization failure message: zzdHSckogz8k6Y7...
```
* Specify the wrong device name, such as when using older i.e. t2 or c4 instances. These instances have an older block device mapping, and `/dev/sdf` will not work. You can read more about it [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html)

To debug faster, I suggest runnning on the HeadNode like so:

```bash
# download from s3
aws s3 cp s3://your-bucket/attach_ebs.sh .
# run as root
sudo bash attach_ebs.sh
```
