---
title: Mount Additional EFS/FSx Lustre Filesystems in AWS ParallelCluster
description:
date: 2021-09-22
tldr: Mount multiple filesystems on the same AWS ParallelCluster cluster.
draft: false
tags: [EFS, aws parallelcluster, FSx lustre, aws]
---

# Mount Additional EFS Filesystems in AWS ParallelCluster

In AWS ParallelCluster 3.0 only one EFS filesystem can be mounted at a time. This guide allows you to attach multiple by making use of the [Custom Bootstrap Actions](https://docs.aws.amazon.com/parallelcluster/latest/ug/custom-bootstrap-actions-v3.html) feature to create a `OnNodeConfigured` script that mounts the Filesystem. 

To create the mount script we'll match the options that parallelcluster uses when it launches a filesystem. See [efs_mount.rb](https://github.com/aws/aws-parallelcluster-cookbook/blob/develop/recipes/efs_mount.rb#L40) for more info.

1. First create a script `efs.sh` that contains the following:

```bash
#!/bin/bash
# Takes three arguments:
# 1. Filesystem id, i.e. fs-78ddf7cb
# 2. Region, i.e. us-east-1
# 3. Mount Point, i.e. /apps
echo "The script has $# arguments"
for arg in "$@"
do
    echo "arg: ${arg}"
done

# create directory if it doesn't exist
mkdir -p ${3}

# mount via nfsv4
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${1}.efs.${2}.amazonaws.com:/ ${3}

# change permissions
# chmod ec2-user:ec2-user ${3}
```

2. Next upload your script to S3:
```
aws s3 cp efs.sh s3://yourbucket.sh
```
5. Next update your clusters `config.yml` to include the following section in both the `HeadNode` and `SlurmQueues` sections. The IAM section gives your cluster read-only access to that bucket.
```yaml
 CustomActions:
    OnNodeConfigured:
      Script: s3://<bucket-name>/efs.sh
      Args:
        - "fs-78ddf7cb"
        - "us-east-1"
        - "/apps"
 Iam:
    S3Access:
      - BucketName: <bucket_name>
        EnableWriteAccess: false
```
6. Update your cluster or create a new one!