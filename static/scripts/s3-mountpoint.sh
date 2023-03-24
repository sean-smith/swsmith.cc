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