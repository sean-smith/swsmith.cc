---
title: Dynamic Filesystems with AWS ParallelCluster
description:
date: 2022-05-20
tldr: Mount Filesystems per-job using Slurm job dependencies
draft: false
tags: [fsx lustre, AWS ParallelCluster, hpc, slurm, aws]
---

You can dynamically create a filesystem per-job, this is useful for jobs that require a fast filesystem but don't want to pay to have the filesystem running 24/7. It's also useful to create a filesystem **per-job** to make sure that job has the fastest possible throughput.

In order to accomplish this without wasting time waiting for the filesystem to create (~10 mins), we've seperated this into three seperate jobs:

1. Create filesystem, only needs a single EC2 instance to run, can be run on head node. Takes 8-15 minutes.
2. Start job, this first mounts the filesystem before executing the job.
3. Delete filesystem

Jobs mount the filesystem under:

```bash
/fsx/$PROJECT_NAME
```

This allows mounting multiple filesystems on the same cluster, one for each job or project.

### 0. Create a Cluster

First we'll create a cluster with the `arn:aws:iam::aws:policy/AmazonFSxFullAccess` IAM policy. 

To do so include the IAM policy under the **HeadNode** > **Advanced options** > **IAM Policies**:

# ParallelClusterManager

![fsx_policy](https://user-images.githubusercontent.com/5545980/168903747-7047017c-bd4e-4a26-a7cc-b0618770db85.png)

# CLI

```yaml
  Iam:
    AdditionalIamPolicies:
      - Policy: arn:aws:iam::aws:policy/AmazonFSxFullAccess
```

You'll need to do the same for the **ComputeNodes** section.

### 1. `create-filesystem.sbatch` script

First create a script responsible for provisioning and waiting for the filesystem to get created:

```bash
#!/bin/bash
#SBATCH -n 1
#SBATCH --time=00:30:00 # fail if filesystem takes more than 30 mins to create

PROJECT_NAME=$1

# get subnet
INTERFACE=$(curl --silent http://169.254.169.254/latest/meta-data/network/interfaces/macs/)
SUBNET_ID=$(curl --silent http://169.254.169.254/latest/meta-data/network/interfaces/macs/${INTERFACE}/subnet-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${AZ::-1}

# create filesystem
filesystem_id=$(aws fsx --region $REGION create-file-system --file-system-type LUSTRE --storage-capacity 1200 --subnet-ids $SUBNET_ID --lustre-configuration DeploymentType=SCRATCH_2 --query "FileSystem.FileSystemId" --output text)
  
# wait for it to complete
status=$(aws fsx --region $REGION describe-file-systems --file-system-ids $filesystem_id --query "FileSystems[0].Lifecycle" --output text)
while [ status != "AVAILABLE" ]
do
  status=$(aws fsx --region $REGION describe-file-systems --file-system-ids $filesystem_id --query "FileSystems[0].Lifecycle" --output text)
  echo "$filesystem_id is $status..."
  sleep 2
done

# log filesystem dns name to a file
mkdir -p /opt/parallelcluster/$PROJECT_NAME
echo "filesystem_id=$(filesystem_id)" > /opt/parallelcluster/$PROJECT_NAME
```

### 2. `submit.sbatch` script
Next create a slurm submission script to mount and execute your job:

```bash
#!/bin/bash

PROJECT_NAME=$1
source /opt/parallelcluster/$PROJECT_NAME

# get filesystem information
filesystem_dns=$(aws fsx --region $REGION describe-file-systems --file-system-ids $filesystem_id --query "FileSystems[0].DNSName" --output text)
filesystem_mountname=$(aws fsx --region $REGION describe-file-systems --file-system-ids $filesystem_id --query "FileSystems[0].MountName" --output text)

# create mount dir
mkdir -p /fsx/$PROJECT_NAME

# mount filesystem
sudo mount -t lustre -o noatime,flock $filesystem_dns@tcp:/$filesystem_mountname /fsx/$PROJECT_NAME

# Run your job
# ...
```

### 3. `delete-filesystem.sbatch` script

```bash
#!/bin/bash
#SBATCH -n 1

PROJECT_NAME=$1
source /opt/parallelcluster/$PROJECT_NAME

# get region
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${AZ::-1}

# delete filesystem
aws fsx --region $REGION delete-file-system --file-system-ids $filesystem_id

# remove project config
rm /opt/parallelcluster/$PROJECT_NAME
```

## Submit

```bash
PROJECT_NAME=test
$ sbatch create-filesystem.sbatch $PROJECT_NAME
Submitted job with id 1
$ sbatch -p od -d afterok:1 submit.sbatch $PROJECT_NAME
Submitted job with id 2
$ sbatch -p od -d after:2 delete-filesystem.sbatch $PROJECT_NAME
Submitted job with id 3
```