---
title: Copy AMI cross-account
description:
date: 2021-12-15
tldr: Copy an AMI from one account to another, or from one partition to another (i.e. commercial to GovCloud)
draft: false
tags: [ec2, ami, hpc, aws]
---

# Copy AMI cross-account

This method works to copy any AMI from one account to another (without sharing or making it a public ami), or across different partitions, i.e. Commercial to GovCloud.

1.	In Commercial transfer AMI from ec2 to s3
```bash
aws ec2 create-store-image-task \
    --image-id ami-1234567890abcdef0 \
    --bucket myamibucket
```
2.	Wait for the transfer to complete, you can monitor it’s progress:
```bash
aws ec2 describe-store-image-tasks
```
3.	Copy the AMI to an S3 bucket in Govcloud
```bash
aws s3 cp s3://myamibucket/ami-1234567890abcdef0.bin .
# switch partitions
aws s3 cp ami-1234567890abcdef0.bin s3://myamibucket-govcloud/
```
4.	In Govcloud move the AMI from S3 to EC2
```bash
aws ec2 create-restore-image-task \
    --object-key ami-1234567890abcdef0.bin \
    --bucket myamibucket-govcloud \
    --name "New AMI Name"
```