---
title: Spack 👾
description:
date: 2022-12-07
tldr: Spack allows you to easily install scientific software on AWS ParallelCluster
draft: false
og_image: /img/spack/build-cache.png
tags: [aws parallelcluster, spack, aws]
---

{{< rawhtml >}}
<p align="center">
    <img src='/img/spack/spack.svg' alt='Spack Logo' style='border: 0px;' />
</p>
{{< /rawhtml >}}

## Install Spack

[Spack](https://spack.io/) is a package manager for supercomputers, Linux, and macOS. It makes installing scientific software easy. Spack isn’t tied to a particular language; you can build a software stack in Python or R, link to libraries written in C, C++, or Fortran, and easily swap compilers or target specific microarchitectures. 

First, on the head node - which we [connected to via SSM or DCV](https://weather.hpcworkshops.com/02-cluster/02-connect-cluster.html) we'll run:

```bash
export SPACK_ROOT=/shared/spack
git clone -b v0.19.0 -c feature.manyFiles=true https://github.com/spack/spack $SPACK_ROOT
echo "export SPACK_ROOT=/shared/spack" >> $HOME/.bashrc
echo "source \$SPACK_ROOT/share/spack/setup-env.sh" >> $HOME/.bashrc
source $HOME/.bashrc
```

This script assumes you have a `/shared` filesystem that's accessible to all the compute nodes. I reccomend configuring this with either [EFS](https://docs.aws.amazon.com/parallelcluster/latest/ug/SharedStorage-v3.html#SharedStorage-v3-EfsSettings) or [FSx Lustre](/posts/fsx-persistent-2-pcluster.html) so you can persist installed packages across multiple cluster. This makes doing version upgrades much easier.

This script is also written with a single-user environment in mind. If you have multiple users, each of them will need to add `export SPACK_ROOT=/shared/spack && source \$SPACK_ROOT/share/spack/setup-env.sh` to their `~/.bashrc` file.

## Spack Build Cache

{{< rawhtml >}}
<p align="center">
    <img src='/img/spack/build-cache.png' alt='Spack just got 20x faster!' style='float: left; border: 0px;' />
</p>
{{< /rawhtml >}}

In Spack `v0.18.0`, we introduced the concept of a [public build cache](https://aws.amazon.com/blogs/hpc/introducing-the-spack-rolling-binary-cache/). This allows users to install packages from pre-built binaries, dramatically lowering build time, up to 20x faster for certain packages.

You can also browse the contents of this caches at [cache.spack.io](https://cache.spack.io/).

To get started, add the binary mirror:

```bash
spack mirror add binary_mirror https://binaries.spack.io/develop
spack buildcache keys --install --trust
```

Then you're able to install packages from the binary cache. For example the package WRF can be installed like so:

```bash
spack install wrf
```

When you get a cache hit you'll see `Extracting [package] from binary cache` like so:

![Spack Cache Hit](/img/spack/cache-hit.png)

To check with packages you have installed, run:

```bash
spack find
```

![Spack Find](/img/spack/spack-find.png)

## So how much faster is this?

For WRF, this improves the installation time from 40 minutes to 10 minutes. A 4x speedup.