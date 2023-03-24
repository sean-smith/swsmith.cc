---
title: Setup S3 Mountpoint with AWS ParallelCluster 🗂
description:
date: 2023-03-24
tldr: Mount an S3 Bucket like a shared filesystem
draft: false
og_image: /img/s3-mountpoint/architecture.png
tags: [S3, AWS ParallelCluster, aws]
---

![S3 Mountpoint logo](/img/s3-mountpoint/architecture.png)

[S3 Mountpoint](https://aws.amazon.com/about-aws/whats-new/2023/03/mountpoint-amazon-s3/) is a new solution that provides a way to mount an S3 bucket as if it's a shared filesystem. This gives several advantages:

* Allows using applications that don't support S3 API's
* Easy interface for users to browse files in S3

So what are the downsides?

* **Read-only** in alpha
* Non-POSIX compliant. This means operations such as metadata changes, file-locking ect. are not supported.

## Setup

1. In this guide, I'll assume you already have [AWS ParallelCluster UI](https://pcluster.cloud) setup, if you don't follow the instructions on [pcluster.cloud](https://pcluster.cloud) to get started.

1. I've created a [post-install script](https://docs.aws.amazon.com/parallelcluster/latest/ug/custom-bootstrap-actions-v3.html) called [s3-mountpoint.sh](/scripts/s3-mountpoint.sh) that installs S3 mountpoint and mounts an S3 bucket. You call it like so:

```bash
#!/bin/bash

# Usage:
# ./s3-mountpoint.sh /shared mybucket

# Install S3 Mountpoint if it's not installed
if [ ! -x "$(which mount-s3)" ]; then
    sudo yum install -y fuse fuse-devel cmake3 clang-devel
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    git clone --recurse-submodules https://github.com/awslabs/mountpoint-s3.git
    cd mountpoint-s3/
    cargo build --release
    mv target/release/mount-s3 /usr/bin/
fi

# get network throughput from ec2 instance
instance_type=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region|awk -F\" '{print $4}')
network=$(aws ec2 --region ${region} describe-instance-types --instance-types ${instance_type} --query "InstanceTypes[].[NetworkInfo.NetworkPerformance]" --output text | grep -o '[0-9]\+')

# Mount S3 Bucket
mkdir -p ${1}
mount-s3 --throughput-target-gbps ${network} ${2} ${1}
```

1. Setup a cluster with that post-install script like:

```yaml
HeadNode:
  InstanceType: c5.xlarge
  Networking:
    SubnetId: subnet-12345
  Ssh:
    KeyName: keypair
  LocalStorage:
    RootVolume:
      VolumeType: gp3
  Iam:
    AdditionalIamPolicies:
      - Policy: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      - Policy: arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
    S3Access:
      - BucketName: mybucket
  CustomActions:
    OnNodeConfigured:
      Script: https://swsmith.cc/scripts/s3-mountpoint.sh
      Args:
        - /shared
        - mybucket
Scheduling:
  Scheduler: slurm
  SlurmQueues:
    - Name: queue0
      AllocationStrategy: lowest-price
      ComputeResources:
        - Name: queue0-compute-resource-0
          Instances:
            - InstanceType: c5n.large
          MinCount: 0
          MaxCount: 4
      Networking:
        SubnetIds:
          - subnet-8b15a7c6
      ComputeSettings:
        LocalStorage:
          RootVolume:
            VolumeType: gp3
      Iam:
        S3Access:
            - BucketName: mybucket
        AdditionalIamPolicies:
            - Policy: arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
      CustomActions:
        OnNodeConfigured:
          Script: https://swsmith.cc/scripts/s3-mountpoint.sh
          Args:
            - /shared
            - mybucket
  SlurmSettings: {}
Region: us-east-2
Image:
  Os: alinux2
```

## Test

1. Once the cluster goes into **CREATE_COMPLETE**, connect to the Head Node and list out the files:

```bash
ls -la /shared
....
```

## Debug

1. If the cluster goes into **CREATE_FAILED** fear not - the logs are all preserved and you can easily debug the source of the failure by looking at the `cfn-init` logfile:

![cfn-init log](/img/s3-mountpoint/cfn-init.png)
