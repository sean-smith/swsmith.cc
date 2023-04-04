---
title: Containers with AWS ParallelCluster
description: 
date: 2023-03-31
tldr: Run containers on AWS ParallelCluster
draft: false
og_image: 
tags: [aws parallelcluster, pyxis, aws, docker, singularity]
---

{{< rawhtml >}}
<p align="center">
    <img src='/img/containers-pcluster/NVIDIA-GPU-Docker.png' alt='Nvidia Container Runtime' style='border: 0px;' />
</p>
{{< /rawhtml >}}

## What are containers?

Containers are a great way to package software, they wrap the runtime of the software up with the application's code. This allows you to pull down optimized software containers and run them out of the box without all the complications of compiling them for a new system. In this blog we'll focus on the [nvidia container repository (ngc)](https://catalog.ngc.nvidia.com/containers) since they have optimized containers for applications like [gromacs](), [nemo megatron](), and [openfold]().

## Containers in HPC

> What are the issues with using docker containers in traditional HPC clusters?

Containers typically require a privileged runtime, i.e. the person invoking the container needs sudo access. This is a problem for HPC clusters which are typically multi-user environments with POSIX file permissions used to give access to certain files and directories based on users and groups.

To solve this Nvidia published [enroot](https://github.com/NVIDIA/enroot) - this uses the linux kernel feature [chroot(1)](https://en.wikipedia.org/wiki/Chroot) to create an isolated runtime environment for the container. Think of this like creating a mount point `/tmp/container` in which the container can only see it's local directory i.e. `container/`. This serves to separate the outside OS from the container's runtime. Here's an example of enroot in action:

```bash
# Import and start an Amazon Linux image from DockerHub
$ enroot import docker://amazonlinux:latest
$ enroot create amazonlinux.sqsh
$ enroot start amazonlinux
```

> So how do you schedule and run containers with Slurm?

Slurm provides a [container capability](https://slurm.schedmd.com/containers.html) for OCI containers that's pretty awful. It requires users to pull down their container images first and convert them to an OCI runtime. To solve this, Nvidia introduced [Pyxis](https://github.com/NVIDIA/pyxis) which is a plugin for Slurm that allows you to run containers using the native OCI runtime capabilities and only specifying the container uri, i.e. `amazonlinux/latest`. An example of this is like so:

```bash
#!/bin/bash
#SBATCH --container-image nvcr.io\#nvidia/pytorch:21.12-py3

python -c 'import torch ; print(torch.__version__)'
```

Pretty cool right?

## Containers on ParallelCluster

> So how do we set this all up with AWS ParallelCluster?



* Spank plugin
* OCI containers
* Pyxis
* Enroot
* Docker
* Singularity