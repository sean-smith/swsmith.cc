---
title: Mount Home Directory in AWS ParallelCluster
description: 
date: 2022-08-30
tldr: Setup a persistent home directory with AWS ParallelCluster
draft: false
tags: [aws parallelcluster, FSx Lustre, aws]
---

![Architecture Diagram](/img/external-home-pcluster/architecture.png)

External filesystems can be mounted and used as home directories in AWS ParallelCluster. This has several advantages over the default, which is an EBS volume on the head node **/home** shared via NFSv4 to the compute nodes.

* Home directories can be persisted after cluster deletion, saving data and allowing users to reproduce the same environment
* Home directories can be mounted on multiple clusters, allowing users to have the same filesystem between different clusters
* Reduce dependency on HeadNode, this allows you to size down the HeadNode since it's no longer serving critical traffic i.e. ~/.ssh/ directory
* Use a filesystem such as EFS that can dynamically expand

See [#2441](https://github.com/aws/aws-parallelcluster/issues/2441).

## Setup

1. In this guide, I'll assume you already have [AWS ParallelCluster Manager](https://pcluster.cloud) setup, if you don't follow the instructions on [hpcworkshops.com](https://www.hpcworkshops.com/03-deploy-pcm.html) to get started.
1. Setup a cluster with an external filesystem mount `/shared`, **Note** this can't interfere with the default home directory, **/home**, which is [required](https://github.com/aws/aws-parallelcluster/issues/2344) for parallelcluster.

    ```yaml
    HeadNode:
    InstanceType: t2.micro
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
    Scheduling:
    Scheduler: slurm
    SlurmQueues:
        - Name: queue0
        ComputeResources:
            - Name: queue0-t2-micro
            MinCount: 0
            MaxCount: 4
            InstanceType: t2.micro
        Networking:
            SubnetIds:
            - subnet-123456789
        ComputeSettings:
            LocalStorage:
            RootVolume:
                VolumeType: gp3
    Region: us-east-2
    Image:
    Os: alinux2
    SharedStorage:
    - Name: Efs0
        StorageType: Efs
        MountDir: /shared
        EfsSettings:
        ThroughputMode: bursting
    ```

1. After the cluster is created, connect to the cluster with SSM:

    ![Connect via SSM](/img/external-home-pcluster/ssm-connect.png)

    Then run the following commands to switch `ec2-user` to `/shared/ec2-user`:

    ```bash
    exit # go back to ssm-user
    sudo su # switch to root
    usermod -d /shared/ec2-user -m ec2-user
    ```

## Test

Now that we've switched the home directory, we can log out and connect again via SSM and test that it worked:

![Test Home Directory](/img/external-home-pcluster/home-dir.png)

You'll see the new home directory is `/shared/ec2-user`, which contains the contents of `/home/ec2-user`.

## Multi-User

If you're using a [multi-user environment](parallelcluster-multi-user.html), make sure to specify the home directory upon user creation:

```bash
useradd -m -d /shared/$USER $USER
```

Since `/shared/ec2-user` is already mounted to all the compute nodes, you simply need to create the user on the compute node and point it at the right home directory:

```bash
useradd -d /shared/$USERNAME -u $USERID $USERNAME
```

See [Multi-User Setup](parallelcluster-multi-user.html) for more details.