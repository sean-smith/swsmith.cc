---
title: AWS ParallelCluster Slurm Constraints
description:
date: 2022-09-23
tldr: Create a Slurm queue with multiple instance types and select the instance type at job submission using Slurm constraints
draft: false
tags: [aws parallelcluster, mpi, slurm, aws]
---

In previous posts we discussed adding multiple instances to same Slurm queue and enabling [Fast Failover](fast-failover.html), this is great when you're flexible on the specific instance type used to run your job, but what if you want to choose the instance type at job submission time?

In this blogpost we look at how to use the Slurm [`--constraint`](https://slurm.schedmd.com/sbatch.html#OPT_constraint) flag to pick the specific instance type at runtime.

## Setup

To setup, refer to the [Fast Failover Setup](fast-failover.html#setup) section. We'll assume you have a cluster setup with a queue and multiple compute resources in it.

You should see something like the following when you run `sinfo`:

```bash
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
queue0*     up   infinite    300  idle~ queue0-dy-queue0-c6i32xlarge-[1-100],queue0-dy-queue0-m6i32xlarge-[1-100],queue0-dy-queue0-r6i32xlarge-[1-100]
```

## Job Submission

Now when we submit a job, we can select the instance type by simply specifying it with the `--constraint` flag:

```bash
salloc --constraint "m6i.32xlarge"
```

This can also be done in an **sbatch** script like so:

```sbatch
#!/bin/bash
#SBATCH --constraint m6i.32xlarge

# rest of job script ...
```

Now when the job is submitted you'll see that instance type gets spun up.

```bash
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
queue0*     up   infinite      1   mix~ queue0-dy-queue0-r6i32xlarge-1
queue0*     up   infinite    299  idle~ queue0-dy-queue0-c6i32xlarge-[1-100],queue0-dy-queue0-m6i32xlarge-[1-100],queue0-dy-queue0-r6i32xlarge-[2-100]
$ squeue
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
9   queue0 interact ec2-user CF       0:09      1 queue0-dy-queue0-r6i32xlarge-1
```

What happens when that instance type can't be launched? I did an experiment to find out:

```sinfo
$ salloc: error: Node failure on queue0-dy-queue0-m6i32xlarge-1
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
queue0*     up   infinite      1  down# queue0-dy-queue0-m6i32xlarge-1
queue0*     up   infinite    200  idle~ queue0-dy-queue0-c6i32xlarge-[1-100],queue0-dy-queue0-r6i32xlarge-[1-100]
queue0*     up   infinite     99  down~ queue0-dy-queue0-m6i32xlarge-[2-100]
```

It'll set that node to `down#` and the rest of the compute resource will go into `down~` for 10 minutes if it detects one of the following responses from the EC2 API:

* `InsufficientInstanceCapacity`
* `InsufficientHostCapacity`
* `InsufficientReservedInstanceCapacity`
* `MaxSpotInstanceCountExceeded`
* `SpotMaxPriceTooLow`
* `Unsupported`

You can read more about it in [Slurm cluster fast insufficient capacity fail-over
docs](https://docs.aws.amazon.com/parallelcluster/latest/ug/slurm-short-capacity-fail-mode-v3.html).
