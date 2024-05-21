---
title: Megatron-LM Distributed Training
description: 
date: 2023-09-13
tldr: Train Megatron-LM on H100's in AWS
draft: false
og_image: 
tags: [aws parallelcluster, pytorch, aws]
---

Megatron-LM is a framework for building LLM models. In this example we'll build a Slurm based cluster and run Megatron-LM. This is an example of doing distributed training using Slurm and the Nvidia H100 GPU's.

## Cluster Creation

To create the Slurm cluster we'll use AWS ParallelCluster. We're going to use a template to create the networking resources and then create the cluster with those networking resources. 

1. Download the [gpu-cluster.yaml](/static/templates/p5.yaml) template

2. Run the `pcluster create-cluster` command.

```bash
pcluster create-cluster -N p5 -c p5.yaml
```

## Data pre-processing

| Instance Type | vCPUs | H100 GPU | GPU  Memory | Network Bandwidth | GPUDirectRDMA | GPU Peer to Peer  | Instance Storage (TB) | EBS Bandwidth (Gbps) |
|---------------|-------|----------|-------------|-------------------|---------------|-------------------|-----------------------|:--------------------:|
|  p5.48xlarge  |  192  | 8        | 640 GB HBM3 |  3200 Gbps EFAv2  | Read/Write    | 900 GB/s NVSwitch |   8 x 3.84 NVMe SSD   | 80 GB                |

| Instance Type | vCPUs | H100 GPU | GPU  Memory | Network Bandwidth | GPUDirectRDMA | GPU Peer to Peer  | Instance Storage (TB) | EBS Bandwidth (Gbps) |
|---------------|-------|----------|-------------|-------------------|---------------|-------------------|-----------------------|:--------------------:|
|  p5.48xlarge  |  192  | 8        | 640 GB HBM3 |  3200 Gbps EFAv2  | Read/Write    | 900 GB/s NVSwitch |   8 x 3.84 NVMe SSD   | 80 GB                |