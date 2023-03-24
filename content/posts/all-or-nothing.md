---
title: Enable All-or-Nothing Scaling with AWS ParallelCluster 🖥
description:
date: 2022-06-21
tldr: Launch N instances or none at all
draft: false
tags: [aws parallelcluster, mpi, slurm, aws]
---

Update: This has been turned into an official AWS Blogpost: [Minimize HPC compute costs with all-or-nothing instance launching
](https://aws.amazon.com/blogs/hpc/minimize-hpc-compute-costs-with-all-or-nothing-instance-launching/)

# Enable All-or-Nothing Scaling with AWS ParallelCluster

[All or nothing scaling](https://github.com/aws/aws-parallelcluster/wiki/Configuring-all_or_nothing_batch-launches) is useful when you need to run MPI jobs that can't start until all `N` instances have joined the cluster.

The way Slurm launches instances is in a best-effort fashion, i.e. if you request `10` instances but it can only get `9`, it'll provision `9` then keep trying to get the last instance. This incurs cost for jobs that need all 10 instances before starting.

For example, if you submit a job like:

```bash
sbatch -N 10 ...
```

It can't start until all `10` instances join the cluster. 

However if you were to run `10` jobs that each require a single instance, like so:

```bash
sbatch -N 1 --exclusive --array=0-9 ...
```

Each job would get kicked off as capacity gets added, with jobs finishing and potentially returning capacity for later jobs.

# Setup

The simplest way to set this up is the run the following command on the `HeadNode`:

```bash
sudo su -
echo "all_or_nothing_batch = True" >> /etc/parallelcluster/slurm_plugin/parallelcluster_slurm_resume.conf
```

If you'd like to automate this process you can create a [CustomAction](https://docs.aws.amazon.com/parallelcluster/latest/ug/custom-bootstrap-actions-v3.html) to run this on each new cluster.

1. Create a file called `all-or-nothing.sh` with the following content

```
#!/bin/bash

echo "all_or_nothing_batch = True" >> /etc/parallelcluster/slurm_plugin/parallelcluster_slurm_resume.conf
```

2. Upload to S3

```
aws s3 cp all-or-nothing.sh s3://bucket
```

3. Modify config to specify the `all-or-nothing.sh` script in the `HeadNode` > `CustomActions` section. 

**Note:** I used the [multi-runner.sh](/scripts/multi-runner.sh) script here, this allows you to specify multiple scripts, each as an arg, however you can just specify it under `Script` if you so desire.

```yaml
HeadNode:
  InstanceType: c5a.xlarge
  Ssh:
    KeyName: keypair
  Networking:
    SubnetId: subnet-12345678
  Iam:
    AdditionalIamPolicies:
      - Policy: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      - Policy: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
  Dcv:
    Enabled: true
  CustomActions:
    OnNodeConfigured:
      Script: >-
        https://swsmith.cc/scripts/multi-runner.sh
      Args:
        - s3://bucket/all-or-nothing.sh
Scheduling:
  Scheduler: slurm
  SlurmQueues:
    - Name: queue1
      ComputeResources:
        - Name: queue1-c6i32xlarge
          MinCount: 0
          MaxCount: 200
          InstanceType: c6i.32xlarge
          Efa:
            Enabled: true
            GdrSupport: true
      Networking:
        SubnetIds:
          - subnet-12345678
        PlacementGroup:
          Enabled: true
Region: us-east-2
Image:
  Os: alinux2
```

# Testing

### Before

Before setting `all_or_nothing_batch = True`, I purposely chose and instance type with low capacity and submitted a large job:

```bash
$ sbatch -N 200 job.sh
```

This went into pending and then by monitoring `sinfo` I was able to see that it got `106` instances, not `200`:

```
$ watch sinfo

Every 2.0s: sinfo                                                                                                                                                  Tue Jun 21 23:20:26 2022

PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
queue0       up   infinite     94  idle% queue1-dy-queue1-c6i32xlarge-[107-200]
queue0       up   infinite    106  idle# queue1-dy-queue1-c6i32xlarge-[1-106]
```

### After

Next I set `all_or_nothing_batch = True` and tried the same thing again (after waiting for all `106` allocated nodes to get terminated):

```bash
$ sbatch -N 200 job.sh
```

I see that the instances go into `idle!` state after they fail to launch:

```bash
$ watch sinfo


PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
compute*     up   infinite     64  idle~ compute-dy-hpc6a-[1-64]
queue1       up   infinite    200  idle! queue1-dy-queue1-c6i32xlarge-[1-200]
```

If I look in `/var/log/parallelcluster/slurm_resume.log`, I can confirm `0` instances were launched:

```
2022-06-21 23:37:55,845 - [slurm_plugin.instance_manager:_launch_ec2_instances] - ERROR - Failed RunInstances request: b816b2b4-fe15-4037-a116-678bfa187a44
2022-06-21 23:37:55,845 - [slurm_plugin.instance_manager:add_instances_for_nodes] - ERROR - Encountered exception when launching instances for nodes (x200) [ ... ]: An error occurred (InsufficientInstanceCapacity) when calling the RunInstances operation (reached max retries: 1): We currently do not have sufficient c6i.32xlarge capacity in the Availability Zone you requested (us-east-2b). Oursystem will be working on provisioning additional capacity. You can currently get c6i.32xlarge capacity by not specifying an Availability Zone in your request or choosing us-east-2a, us-east-2c.
2022-06-21 23:37:55,846 - [slurm_plugin.resume:_resume] - INFO - Successfully launched nodes (x0) []
```

Now I can change my instance job size or use another Availability Zone to accomodate this job.

## --no-requeue flag

If you add in the `--no-requeue` flag and the job doesn't get capacity, it'll automatically drop off the queue, i.e.

```bash
$ sbatch -p queue1 -N 4 --exclusive --no-requeue submit.sh
$ watch squeue
Every 2.0s: squeue                                                                                                                 Fri Mar 24 15:21:23 2023

             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
                 2    queue1 submit.s ec2-user PD       0:00      4 (Nodes required for job are DOWN, DRAINED or reserved for jobs in higher priority parti
tions)
```

After about 5 minutes, the job will drop off the queue. If you want the job to continue pending add in the `--requeue` flag (this is the default).
