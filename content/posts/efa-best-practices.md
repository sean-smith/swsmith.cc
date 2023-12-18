---
title: EFA Best Practices 👾
description:
date: 2023-12-12
tldr: Verify EFA is working like a racecar.
draft: false
og_image: /img/efa/racecar.jpeg
tags: [aws, efa, hpc, ml]
---

{{< rawhtml >}}
<p align="center">
    <img src='/img/efa/racecar.jpeg' alt='EFA' style='border: 0px;' width='500px' />
</p>
{{< /rawhtml >}}

[Elastic Fabric Adaptor (EFA)](https://aws.amazon.com/hpc/efa/) is is like a race car, it enables super-fast, os-bypass, high speed networking when working properly but quickly breaks down (aka falls back to TCP) when it isn't configured properly. The following guide is some best practices when working with the EFA drawn on my 6 years of experience working with it. 

## First some basics:

> What is EFA and how is it different than Infiniband?

EFA is a *network protocol* and *network device* available on select AWS instance types including `p5.96xlarge`, `p4d.48xlarge`, `hpc7a.96xlarge` ect. It provides OS-bypass (aka skip the kernel) communication, RDMA Read and Write (on p5) and significantly lower latency over TCP. It's built with scale in mind and scales up petabit size (actually a whole lot bigger), up to 20,000 H100's in an [Ultracluster](https://aws.amazon.com/ec2/ultraclusters/).

So how fast is it? It provides up to 3,200 Gbps on the p5 instances, with speeds varying as shown below:

| Instance Type  | EFA Networking     |
|----------------|--------------------|
| p5.48xlarge    | 3,200 Gbps (EFAv2) |
| trn1.32xlarge  | 1,600 Gbps (EFAv2) |
| p4d.24xlarge   | 400 Gbps           |
| hpc7a.96xlarge | 300 Gbps           |

It's different than infiniband in that it uses a custom protocol, [Scalable Reliable Datagrams (SRD)](https://aws.amazon.com/blogs/hpc/in-the-search-for-performance-theres-more-than-one-way-to-build-a-network/). SRD makes EFA much more fault tolerant than infiniband since it can handle link failures and automatically routes around them. Unlike InfiniBand (IB), with custom network fabric and routers, EFA runs over standard ethernet fabric making it simpler to deploy at scale. In many ways EFA is better suited for AWS size data centers than IB.

## How do I enable it?

To enable EFA you just select *Enable EFA* when you're launching an instance in EC2. This option is also available in [AWS ParallelCluster](https://docs.aws.amazon.com/parallelcluster/latest/ug/efa-v3.html), [EKS](https://docs.aws.amazon.com/eks/latest/userguide/node-efa.html), and [SageMaker HyperPod](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpos-resiliency.html) as an option. For example in ParallelCluster that looks like:

```yaml
Efa:
    Enabled: true
```

Additionally you need to launch your instances in what's called a *Placement Group*, this ensures the instances are co-located on the same network spine. To do this make sure all your instances are in the same AZ and then depending on the orchestrator you'll have an option. For example the [ParallelCluster flag](https://docs.aws.amazon.com/parallelcluster/latest/ug/Scheduling-v3.html#yaml-Scheduling-SlurmQueues-Networking-PlacementGroup) looks like:

```yaml
PlacementGroup:
    Enabled: true
```

## What flags does it need?

Minimally it needs:

```bash
export FI_PROVIDER=efa
export NCCL_DEBUG=info # (optional) check to see it's using EFA in NCCL
```

See [EFA Cheatsheet](https://github.com/aws/aws-ofi-nccl/blob/master/doc/efa-env-var.md) for the latest.

## Does it work in containers?

Yes, to enable it in containers you'll need to install the EFA libraries but not the kernel image like so by specifying the `--no-kmod` flag so it doesn't attempt (and fail) to install the kernel modules.

```Dockerfile
ARG EFA_INSTALLER_VERSION=1.28.0

## Install EFA installer
RUN cd $HOME \
    && curl -O https://efa-installer.amazonaws.com/aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz \
    && tar -xf $HOME/aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz \
    && cd aws-efa-installer \
    && ./efa_installer.sh -y --skip-kmod --no-verify
```

See [awsome-distributed-training/3.test_cases/1.megatron-lm](https://github.com/aws-samples/awsome-distributed-training/blob/main/3.test_cases/1.megatron-lm/0.distributed-training.Dockerfile#L62C1-L67C53) for a complete example.

## What version is best?

I've outlined the minimum versions of each of the required packages below. Note these versions are specific to running [NCCL](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start-nccl.html), a communication library optimized for communicating between Nvidia GPU's, it'll be different when using OpenMPI or IntelMPI.

| Library       | Version       | A100 Min Version (P4) | H100 Min Version (P5) |
|---------------|---------------|-----------------------|:---------------------:|
|  EFA          |  `1.26.1`     |                       |     `1.26.1`          |
|  NCCL         |  `2.18.5`     |     `2.15.1`          |     `2.18.5`          |
|  NCCL OFI     |  `v1.7.3-aws` |     `1.6.0`           |     `v1.7.3-aws`      |
|  CUDA Driver  |  `535.54.03`  |      `450.80.02`      |     `535.54.03`       |
|  CUDA Version |  `12.2`       |      `11.4`           |     `11.8`            |

To easily grab these versions you can run the following script:

```bash
#!/bin/bash

# EFA Version
cat /opt/amazon/efa_installed_packages | grep "EFA installer version:"

# NCCL Version
sudo apt install mlocate
locate nccl| grep "libnccl.so" | tail -n1 | sed -r 's/^.*\.so\.//'

# libfabric Version
fi_info --version | grep "libfabric:"

# NCCL OFI Version
strings /opt/aws-ofi-nccl/lib/libnccl-net.so | grep Initializing

# CUDA Driver
nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1

# CUDA Version
nvcc --version | grep "release"
```

## How do I see how it's working?

To see that it's working you can monitor the transmitted (tx) and received (rx) packet counts. These live in the following locations:

**alinux2**
```bash
cat /sys/class/infiniband/rdmap0s6/ports/1/hw_counters/tx_pkts
cat /sys/class/infiniband/rdmap0s6/ports/1/hw_counters/rx_pkts
```
  
**centos**
```bash
cat /sys/class/infiniband/efa_0/hw_counters/tx_pkts
cat /sys/class/infiniband/efa_0/hw_counters/rx_pkts
```

**Ubuntu**
```bash
cat /sys/class/infiniband/<device>/ports/*/hw_counters/
# i.e.
$ cat /sys/class/infiniband/rdmap96s0/ports/1/hw_counters/rx_pkts
0
$ cat /sys/class/infiniband/rdmap96s0/ports/1/hw_counters/tx_pkts
0
```

## What is second gen EFA (EFAv2)?

Second Generation EFA (EFAv2) is the best kept secret of EFA. [Announced with the trn1 instance](https://aws.amazon.com/blogs/hpc/second-generation-efa-improving-hpc-and-ml-application-performance-in-the-cloud/) in 2022, it brings 50% communication time improvement over EFAv1. It's enabled by default on all the latest instance types including `p5.48xlarge` and `trn1.32xlarge`.