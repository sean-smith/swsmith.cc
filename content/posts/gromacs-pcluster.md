---
title: Setup Gromacs On AWS ParallelCluster 🧬
description:
date: 2022-08-16
tldr: Setup Gromacs with Spack on AWS ParallelCluster
draft: false
og_image: img/gromacs/logo.png
tags: [aws parallelcluster, gromacs, slurm, aws, spack]
---

![Gromacs](/img/gromacs/logo.png)

Gromacs is a popular open source Molecular Dynamics application. It supports GPU and CPU acceleration and supports multi-node processing using MPI. In the following guide we'll setup a MPI compatible version of Gromacs using [Spack](https://spack.io/) package manager.

## Setup

1. In this guide, I'll assume you already have [AWS ParallelCluster Manager](https://pcluster.cloud) setup, if you don't follow the instructions on [hpcworkshops.com](https://www.hpcworkshops.com/03-deploy-pcm.html) to get started.

1. Setup cluster with the following config [gromacs-config.yaml](/templates/gromacs-config.yaml). Some of the important options include:

| **Parameter**  | **Description**                                                                                                                                                            |
|----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Shared Storage | This sets up a 1.2 TB lustre drive and mounts it at /shared                                                                                                                |
| HeadNode       | This sets up a `c5a.2xlarge` instance as the head node. It has 8 hyper-threaded cpus and 16 gigs of memory. This is ideal for small computational tasks such as post-processing and installing software.                                                                |
| ComputeNodes   | This sets up a queue of `hpc6a.48xlarge` instances. These instances have 96 physical cores and 384 GB of memory. These instances are ideal for tightly coupled compute. **Note** these instances don't start running until we submit a job. |

1. Install Spack

    ```bash
    sudo su
    export SPACK_ROOT=/shared/spack
    mkdir -p $SPACK_ROOT
    git clone -c feature.manyFiles=true https://github.com/spack/spack $SPACK_ROOT
    cd $SPACK_ROOT
    exit
    echo "export SPACK_ROOT=/shared/spack" >> $HOME/.bashrc
    echo "source \$SPACK_ROOT/share/spack/setup-env.sh" >> $HOME/.bashrc
    source $HOME/.bashrc
    sudo chown -R $USER:$USER $SPACK_ROOT
    ```

1. Setup the [Spack Binary Cache](https://spack.io/spack-binary-packages/) to speedup the build

    ```bash
    spack mirror add binary_mirror  https://binaries.spack.io/releases/v0.18
    spack buildcache keys --install --trust
    ```

1. Next we’ll use Spack to install the [Intel Compilers (ICC)](https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html), which we'll use to compile gromacs.

    ```bash
    spack install intel-oneapi-compilers@2022.0.2
    ```

    This will take about `~4 mins` to complete. Once it’s complete, tell Spack about the new compiler by running:

    ```bash
    spack load intel-oneapi-compilers
    spack compiler find
    spack unload
    ```

    Now **intel** will show up as an option when we run `spack compilers`

    ```bash
    spack compilers
    ```

1. Now that we've installed the intel compiler, we can proceed to install Gromacs.

    ```bash
    spack install -j 8 gromacs +blas +lapack %intel ^intel-oneapi-mpi
    ```

1. This will take `~45 minutes`. After it completes, we can see the installed packages with:

    ```bash
    spack find
    ```

    ![Spack Find](/img/gromacs/spack-packages.png)

1. Now we can load in gromacs and test that it works. You should see the help message from `gromacs`.

    ```bash
    spack load gromacs
    gmx_mpi
    ```

## Dataset

1. Download sample data sets from the [Max Planck Institue in Göttingen](https://www.mpinat.mpg.de/grubmueller/bench)

    One of the datasets we download is the benchRIB Molecule, which looks like:

    ![BenchRIB Dataset](/img/gromacs/benchRIB.png)

    ```bash
    mkdir -p /shared/input/gromacs
    mkdir -p /shared/logs
    mkdir -p /shared/jobs

    cd /shared/input/gromacs
    wget https://www.mpinat.mpg.de/benchMEM
    wget https://www.mpinat.mpg.de/benchPEP.zip
    wget https://www.mpinat.mpg.de/benchPEP-h.zip
    wget https://www.mpinat.mpg.de/benchRIB.zip

    # unzip
    unzip bench*.zip
    ```

## Run

1. First, create a bash script `gromacs.sbatch` to submit jobs with:

    ```bash
    #!/bin/bash
    #SBATCH --job-name=gromacs-hpc6a-threadmpi-96x2
    #SBATCH --exclusive
    #SBATCH --output=/shared/logs/%x_%j.out
    #SBATCH --partition=hpc6a
    #SBATCH -N 2
    NTOMP=1

    mkdir -p /shared/jobs/${SLURM_JOBID}
    cd /shared/jobs/${SLURM_JOBID}

    spack load gromacs
    spack load intel-oneapi-mpi@2021.5.1%intel@2021.5.0 arch=linux-amzn2-zen2

    set -x
    time mpirun -np 192 gmx_mpi mdrun -ntomp ${NTOMP} -s /shared/input/gromacs/benchRIB.tpr -resethway
    ```

1. Submit the job:

    ```bash
    sbatch gromacs.sbatch
    ```

1. We can monitor the job state with `watch squeue`. Once it transitions into running we'll see:

    ```bash
    $ watch squeue
    ```

    From there you can ssh into one of the compute nodes and run `htop` to see resource consumption. If it's running properly, you'll see a htop output like:

    ![htop](/img/gromacs/htop.png)

## Post-Processing

1. Install `PyMol` on the HeadNode

    ```bash
    sudo amazon-linux-extras install epel
    sudo yum update -y 
    sudo yum groupinstall -y "Development Tools"
    sudo yum install -y python3-devel glew-devel glm-devel libpng-devel libxml2-devel freetype-devel freeglut-devel qt5-qtbase
    pip3 install --user virtualenv
    virtualenv ~/hpc-ve
    source ~/hpc-ve/bin/activate
    pip3 install aws-parallelcluster==3.* nodeenv PyQt5
    nodeenv -p -n lts

    git clone https://github.com/schrodinger/pymol-open-source.git
    cd pymol-open-source
    python setup.py install --prefix=~/hpc-ve/ --no-vmd-plugins

    which pymol
    ```

1. Then open up a DCV Session from Pcluster Manager:

    ![Open DCV Session](https://user-images.githubusercontent.com/5545980/179796745-e1325349-da48-40b6-9dff-906aa3118ab4.png)

1. On the DCV session, open a terminal window and run:

    ```batch
    source ~/hpc-ve/bin/activate
    pymol
    ```

1. Now, in the pymol console run:

    ```bash
    fetch 1bl8
    ```

1. Your output should look similar to the following:

    ![PyMol Output](https://user-images.githubusercontent.com/5545980/179797286-a70d890b-5af8-468e-b283-ffcbafb6ef2f.png)