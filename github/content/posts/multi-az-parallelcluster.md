---
title: Multi-AZ AWS ParallelCluster
description:
date: 2022-11-02
tldr: Setup Slurm Queues in different Availibility Zones to unlock additional capacity.
draft: false
og_image: /img/multi-az/architecture.png
tags: [aws parallelcluster, slurm, aws]
---

![Multi-AZ Architecture](/img/multi-az/architecture.png)

Today we launched a new version of AWS ParalleCluster, [version 3.3.0](https://aws.amazon.com/about-aws/whats-new/2022/11/aws-parallelcluster-3-3-multiple-instance-type-allocation-top-features/). This version has a feature hidden in the [release log](https://github.com/aws/aws-parallelcluster/blob/develop/CHANGELOG.md#330):

* Allow for suppressing the `SingleSubnetValidator` for Queues.

With this feature, we can setup a **single AZ-per queue** essentially allowing us to choose which Availibility Zone is associated with each queue. This is useful for capacity constrained instances, such as GPU and HPC instances which may exist in different availibility zones.

This is a beta launch and has some caveats:

* Clusters that create an FSx Lustre filesystem will throw an error about Multi-Subnets. The solution here is to [create a filesystem then create the cluster](fsx-persistent-2-pcluster.html) and attach it.
* Traffic between different Availibility Zones will incur a small charge of $.01/GB, this is documented [here](https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer_within_the_same_AWS_Region).

## Setup

1. Install AWS ParallelCluster 3.3.0 on the CLI (this isn't availaible yet in [pcluster manager](https://pcluster.cloud/) 😢)

    ```bash
    pip3 install aws-parallelcluster==3.3.0
    ```

2. Setup a cluster config with a unique subnet per-queue. Here's an example configuration you can start with. It has the `hpc6a.48xlarge` which os only supported in `us-east-1b` and the `c6i.32xlarge` which is supported in all AZ's but can be capacity constrained at certain times.

    ```yaml
    HeadNode:
    InstanceType: c5.xlarge
    Ssh:
        KeyName: keypair
    Networking:
        SubnetId: subnet-123456789
    LocalStorage:
        RootVolume:
        VolumeType: gp3
    Iam:
        AdditionalIamPolicies:
        - Policy: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
    Dcv:
        Enabled: true
    Scheduling:
    Scheduler: slurm
    SlurmQueues:
        - Name: queue0
        ComputeResources:
            - Name: queue0-hpc6a48xlarge
            MinCount: 0
            MaxCount: 64
            InstanceType: hpc6a.48xlarge
            Efa:
                Enabled: true
                GdrSupport: true
        Networking:
            SubnetIds:
            - subnet-846f1aff
            PlacementGroup:
            Enabled: true
        ComputeSettings:
            LocalStorage:
            RootVolume:
                VolumeType: gp3
        - Name: queue1
        ComputeResources:
            - Name: queue1-c6i32xlarge
            MinCount: 0
            MaxCount: 6
            InstanceType: c6i.32xlarge
            Efa:
                Enabled: true
                GdrSupport: true
            DisableSimultaneousMultithreading: true
        ComputeSettings:
            LocalStorage:
            RootVolume:
                VolumeType: gp3
        Networking:
            SubnetIds:
            - subnet-8b15a7c6
            PlacementGroup:
            Enabled: true
    SlurmSettings:
        QueueUpdateStrategy: DRAIN
        EnableMemoryBasedScheduling: true
    Region: us-east-2
    Image:
    Os: alinux2
    ```

3. Create the cluster (has be on the CLI) with the flag `--suppress-validators type:SingleSubnetValidator`, i.e.

    ```bash
    pcluster create-cluster -n multi-az -c config-multi-az.yaml --suppress-validators type:SingleSubnetValidator
    ```
