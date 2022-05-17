---
title: Slurm Failover from Spot to On-Demand
description:
date: 2022-04-28
tldr: Launch jobs on AWS ParallelCluster Spot then failover to On-Demand if Spot instance gets reclaimed.
draft: false
tags: [AWS ParallelCluster, Slurm, Spot, On-Demand, aws]
---

# Slurm Failover from Spot to On-Demand

In AWS ParallelCluster you can setup a cluster with two queues, one for Spot pricing and one for On-demand. When a job fails, due to a spot reclaimation, you can automatically requeue that job to OnDemand.

To set that up, first create a cluster with a Spot and OnDemand queue:

```yaml
- Name: od
    ComputeResources:
      - Name: c6i-od-c6i32xlarge
        MinCount: 0
        MaxCount: 4
        InstanceType: c6i.32xlarge
        Efa:
          Enabled: true
          GdrSupport: true
        DisableSimultaneousMultithreading: true
    Networking:
      SubnetIds:
        - subnet-846f1aff
      PlacementGroup:
        Enabled: true
  - Name: spot
    ComputeResources:
      - Name: c6i-spot-c6i32xlarge
        MaxCount: 4
        InstanceType: c6i.32xlarge
    Networking:
      SubnetIds:
        - subnet-846f1aff
    CapacityType: SPOT
```

Next submit your job like so:

```bash
$ sbatch -p spot --norequeue submit.sbatch
Submitted job with id 1
$ sbatch -p od -d afternotok:1 submit.sbatch
Submitted job with id 2
```

* `--norequeue` tells slurm to not requeue in the same queue as the first job.
* `afternotok:1` tells slurm to only run the second job if the first one (job id 1) fails.