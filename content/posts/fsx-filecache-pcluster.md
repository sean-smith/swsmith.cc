---
title: Setup FSx FileCache with AWS ParallelCluster 🗂
description:
date: 2022-10-24
tldr: access on-prem files easily from AWS ParallelCluster with FSx File Cache
draft: false
og_image: /img/filecache/logo.jpg
tags: [fsx lustre, AWS ParallelCluster, hpc, s3, aws]
---

![Amazon Filecache logo](/img/filecache/logo.jpg)

[Amazon FSx File Cache](https://aws.amazon.com/about-aws/whats-new/2022/09/amazon-file-cache-generally-available/) is a new service that provides a cache to use on-prem data in the cloud but it has a few advantages over SCP/SFTP and Datasync.

* Single namespace - files & metadata are copied up and down transparently to the user
* Support for S3 and NFSv3 (Not NFSv4 as of this writing)
* Lazy Loading - files are pulled in as needed, resulting in a smaller overall cache size

So when should you not use File Cache?

* Syncing data from a S3 Bucket in the same region - Just use FSx Lustre, it's 1/2 the cost.
* Syncing from a non-NFS source filesystem - use [datasync](https://aws.amazon.com/datasync/) or [transfer family](https://aws.amazon.com/aws-transfer-family/).

## Setup

From the AWS ParallelCluster [docs](https://docs.aws.amazon.com/parallelcluster/latest/ug/fsx-section.html) we learn:

> If using an existing file system (same for cache), it must be associated to a security group that allows inbound TCP traffic to port 988.

So we'll need to:

1. Create the Security Group
2. Create the cache & associate the security group
3. Create a cluster that mounts the cache

Since File Cache is built on the popular Lustre client, it requires no extra installation in AWS ParallelCluster image. We just need to mount the filesystem.

## 1. Create Security Group

1. Create a new Security Group by going to [Security Groups](https://console.aws.amazon.com/ec2/v2/home?#SecurityGroups:) > **Create Security Group**:

    * **Name** `FSx File Cache`
    * **Description** `Allow FSx File Cache to mount to ParallelCluster`
    * **VPC** `Same as pcluster vpc`

    ![FSx Filecache setup](/img/filecache/sg-setup.jpeg)

2. Create a new **Inbound Rule**

    * Custom TCP
    * Port `988`
    * Same CIDR as the VPC `172.31.0.0/16`

    ![image](https://user-images.githubusercontent.com/5545980/151906849-ebc39085-a21b-47de-8d48-788ee9690ed0.png)

3. Leave **Outbound Rules** as the default:

    ![image](https://user-images.githubusercontent.com/5545980/151907435-2720da9c-a536-46b4-a8c1-4151e4e13098.png)

## 2. Create FSx File Cache

1. Go to the [FSx Lustre Console](https://console.aws.amazon.com/fsx/home?#fc/file-caches) and click **Create Cache**.
2. Next give it a name and set the size, (smallest is `1.2TB`)

    ![Setup Details](/img/filecache/setup-details.png)

3. On the next section specify the same VPC and subnet as your cluster and make sure to select the Security Group you created earlier.

    ![Setup VPC/SG](/img/filecache/setup-vpc.png)

## 4. Create a Data Repository Association

Like FSx Lustre, FileCache has the notion of Data Repository Associations (DRA). This allows you to link either an S3 bucket in another region or a NFSv3 based filesystem. All the metadata will be imported automatically and files will be lazy loaded into the cache.

1. Create your DRA like so:

    ![Mount Command](/img/filecache/dra.png)

2. On the next screen review all the information and click "Create".

## 5. Attach Filesystem to AWS ParallelCluster

1. After the cache has finished creating, grab the mount command from the FSx console:

    ![Mount Command](/img/filecache/mount.png)

    We'll use the DNS name (including mount dir) to mount the cache below.

2. SSH into the HeadNode and create a script `mount-filecache.sh` with the following content:

    > Note on Lustre client version: Lustre client version `2.12` is required for filecache metadata lazy load to work. This requires kernel version `> 5.10` which is in the latest Amazon Linux 2 AMI. It's upgraded in the script below by running `sudo yum install -y lustre-client`. You can check version compatibility here: https://docs.aws.amazon.com/fsx/latest/LustreGuide/install-lustre-client.html#lustre-client-amazon-linux#lustre-client-matrix.

    ```bash
    #!/bin/bash

    # usage: mount-filecache.sh fc-05f5419216933fbe0.fsx.us-east-2.amazonaws.com@tcp:/wwu73bmv /mnt

    FSX_DNS=$1
    MOUNT_DIR=$2

    . /etc/parallelcluster/cfnconfig
    test "$cfn_node_type" != "HeadNode" && exit

    # create a directory
    mkdir -p ${MOUNT_DIR}

    # upgrade lustre version
    sudo yum install -y lustre-client

    # mount on head node
    sudo mount -t lustre -o relatime,flock ${FSX_DNS} ${MOUNT_DIR}

    cat << EOF > /opt/slurm/etc/prolog.sh
    #!/bin/sh

    if mount | /bin/grep -q ${MOUNT_DIR} ; then
    exit 0
    else

    # upgrade lustre version
    sudo yum install -y lustre-client

    # create a directory
    sudo mkdir -p ${MOUNT_DIR}

    # mount on compute node
    sudo mount -t lustre -o relatime,flock ${FSX_DNS} ${MOUNT_DIR}
    fi
    EOF
    chmod 744 /opt/slurm/etc/prolog.sh

    echo "Prolog=/opt/slurm/etc/prolog.sh" >> /opt/slurm/etc/slurm.conf
    systemctl restart slurmctld
    ```

3. Then run it from the HeadNode, specifying the filesystem DNS and mount directory like so:

    ```bash
    FILECACHE_DNS=fc-05f5419216933fbe0.fsx.us-east-2.amazonaws.com@tcp:/wwu73bmv
    MOUNT_DIR=/mnt
    sudo bash mount-filecache.sh ${FILECACHE_DNS} ${MOUNT_DIR}
    ```

4. To verify that the filesystem mounted properly, you can run `df -h`. You should see a line like:

    ```bash
    df -h
    ...
    172.31.47.168@tcp:/wwu73bmv  1.2T   11M  1.2T   1% /mnt
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
    172.31.47.168@tcp:/wwu73bmv  1.2T   11M  1.2T   1% /mnt
    ```
