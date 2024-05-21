---
title: Auto-Resume from failed GPU in AWS ParallelCluster
description:
date: 2024-01-08
tldr: Monitor for failed GPU's, automatically replace them, and then resume from the last checkpoint.
draft: false
tags: [aws parallelcluster, opensearch, slurm, aws]
---

![DCGM Monitoring](/img/autoresume/autoresume.png)

A common adage in the cloud is to think of servers like cattle not pets. Pets need to be tended too, special care is taken to their nurture and they have specific names i.e. apollo or gemini. Cattle are numbered and replaceable, i.e. node01, node02, ect.

This analogy tends to fall apart when we think of clusters of the latest GPU instances, like p5.48xlarge, needed to train foundational models, typically these clusters are static and nodes are co-located on specific part of the network i.e. in a [Placement Group](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html). These instances are typically deployed as static clusters within a capacity reservation.

In this blogpost we'll show that it doesn't have to be this way. You can think of GPU instances as cattle (even those launched in a specific Placement Group) and replace them when you see problems, you can even configure your code to automatically resume from the last checkpoint after a failure.

# The How

> Ok that sounds great but how do we do this?

AWS ParallelCluster supports [GPU Health Checks](https://aws.amazon.com/blogs/hpc/introducing-gpu-health-checks-in-aws-parallelcluster-3-6/), using [Nvidia DCGM](https://developer.nvidia.com/dcgm) these can be enabled with the following [HealthCheck](https://docs.aws.amazon.com/parallelcluster/latest/ug/Scheduling-v3.html#yaml-Scheduling-SlurmQueues-ComputeResources-HealthChecks) parameter:

```yaml
...
HealthChecks:
    Gpu:
        Enabled: true
```

When a job is scheduled, it'll run the DCGM health check as a prolog script, prior to job invocation, this takes about 3 minutes. If a node fails, it'll automatically set it to down and then terminate it and request a new one from ec2.

```bash
#!/bin/bash
#SBATCH --requeue
#SBATCH -N 32
```

In this guide we'll show how [health checks + checkpointing]() can be combined to do fault tolerant pre-training and fine-tuning.

## Setup

1. Create a cluster with the following template [autoresume.yaml](/static/templates/)

2. 