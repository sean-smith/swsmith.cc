---
title: HPC7g instances in AWS ParallelCluster 👽
description:
date: 2023-07-10
tldr: The latest generation ARM instance, hpc7g.16xlarge, allows cost-effective HPC simulations with AWS ParallelCluster.
draft: false
og_image: /img/hpc7g/hpc7g.jpeg
tags: [ec2, AWS ParallelCluster, hpc, aws]
---
{{< rawhtml >}}
<p align="center">
    <img src='/img/hpc7g/hpc7g.jpeg' alt='HPC7g instances' style='border: 0px;' />
</p>
{{< /rawhtml >}}

HPC7g instances are the first ARM based HPC instances in AWS. These instances combine excellent per-core pricing, deep capacity pools and 200 GB EFA networking in order to create the perfect HPC instance for large-scale cost-effective simulations. There's three different sizes:

| Instance Size  | Cores | Memory (GiB) | EFA Network Bandwidth | Price (On-Demand in us-east-1) |
|----------------|-------|--------------|-----------------------|--------------------------------|
| hpc7g.4xlarge  | 16    | 128          | 200 GBps              | 1.683                          |
| hpc7g.8xlarge  | 32    | 128          | 200 GBps              | 1.683                          |
| hpc7g.16xlarge | 64    | 128          | 200 GBps              | 1.683                          |

The first thing you'll notice is the t-shirt sizes (i.e. 4xlarge or 8xlarge) don't differ in terms of memory or price, they only differ by the number of cores. Think of this as similar to restricting cores in order to get better memory bandwidth or higher total memory per-core.

In the next section we'll show how to setup these instances with AWS ParallelCluster.

## Setup

To deploy `hpc7g` instances we'll need to create a ARM-specific cluster due to a restriction in AWS ParallelCluster that each cluster needs to share the same architecture i.e. `arm64` or `x86_64`.

The next important caveat is that the HPC7g instances **can only be deployed in a private subnet in a single-AZ**, at launch that's only N. Virginia (us-east-1), `use1-az6` Availability Zone.

1. Create a VPC and Subnet in N. Virginia. For simplicity I've provided a template that creates a private subnet in each Availability Zone. You'll need to use the **private subnet** created in `use1-az6` to get capacity. 

    [Quick Create Link 🚀](https://us-east-1.console.aws.amazon.com/cloudformation/home?#/stacks/create/review?stackName=VPC-Large-Scale&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/VPC-Large-Scale.yaml)

2. Download the following example template: [hpc7g.yaml](/templates/hpc7g.yaml). You'll need to substitute your SSH keyname, the subnet id's for both a public subnet (to connect) and a private subnet (for compute nodes), and anything else specific to your account. 

    The template creates the following resources:

    | **Field**    | **Value**        | **Description**                                                                                                                                                   |
    |--------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
    | Head Node    | `c7g.xlarge`     | This instance is responsible for running slurm scheduler and allowing users to login. This is the smallest possible size slurmctld can use (4 cores and 8 GB RAM), it also matches the same [neoversev1](https://en.wikichip.org/wiki/arm_holdings/microarchitectures/neoverse_v1) core-architecture that the `hpc7g.16xlarge` instances has so if you compile code and it does [micro-architecture detection](https://www.osti.gov/servlets/purl/1712554) it'll have the proper flags set. |
    | Compute Node | `hpc7g.16xlarge` | These are the compute nodes, make sure they're in the subnet created in `use1-az6`.                                                                               |
    | Filesystem   | FSx Lustre       | We recommend using FSx Lustre as the shared filesystem.                                                                                                           |

    Once the template is modified, you can create the cluster like so:

    ```bash
    pcluster create-cluster -n arm64 -c hpc7g.yaml
    ```

## Install Arm Performance Libraries

Once the cluster is `CREATE_COMPLETE` we can install [Arm Performance Libraries](https://developer.arm.com/downloads/-/arm-performance-libraries) and a version of gcc that supports neoversev1 cores using [Spack](https://spack.io).

1. First install Spack on the FSx Lustre filesystem following instructions [here](https://swsmith.cc/posts/spack.html#install-spack)

2. we'll first install `gcc` 9.3.0 which has support for the Neoversev1 core:

    ```
    spack install gcc@9.3.0
    spack load gcc@9.3.0
    spack compiler find
    spack unload gcc@9.3.0
    ```

2. Next we'll install [armpl](https://developer.arm.com/downloads/-/arm-performance-libraries) a set of performance libraries including `BLAS`, `LAPACK`, `FFT`, ect.

    ```
    spack install armpl-gcc
    ```

3. Check that it picked up on the appropriate [SVE](https://developer.arm.com/Architectures/Scalable%20Vector%20Extensions) instruction set.

## Restricting Cores

If we look back at the t-shirt sizes we'll see that they're already restricted in terms of cores.

| Instance Size  | Cores | Memory (GiB) | EFA Network Bandwidth | Price (On-Demand in us-east-1) |
|----------------|-------|--------------|-----------------------|--------------------------------|
| hpc7g.4xlarge  | 16    | 128          | 200 GBps              | 1.683                          |
| hpc7g.8xlarge  | 32    | 128          | 200 GBps              | 1.683                          |
| hpc7g.16xlarge | 64    | 128          | 200 GBps              | 1.683                          |

To submit jobs that use a specific instance type, specify the [constraint](slurm-constraint.html) flag and the instance name:

```bash
salloc --constraint "hpc7g.4xlarge"
# wait for the instance to come up
```

Once the instance is running, you can ssh in and see that it does indeed have fewer cores but equivalent memory.

```bash
ssh hpc7g-dy-hpc7g-4xlarge-1
$ lscpu
Architecture:        aarch64
CPU op-mode(s):      32-bit, 64-bit
Byte Order:          Little Endian
CPU(s):              16
On-line CPU(s) list: 0-15
Thread(s) per core:  1
Core(s) per socket:  16
Socket(s):           1
NUMA node(s):        1
Vendor ID:           ARM
Model:               1
Stepping:            r1p1
BogoMIPS:            2100.00
L1d cache:           64K
L1i cache:           64K
L2 cache:            1024K
L3 cache:            32768K
NUMA node0 CPU(s):   0-15
Flags:               fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm jscvt fcma lrcpc dcpop sha3sm3 sm4 asimddp sha512 sve asimdfhm dit uscat ilrcpc flagm ssbs paca pacg dcpodp svei8mm svebf16 i8mm bf16 dgh rng
```