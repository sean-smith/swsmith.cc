---
title: LS-Dyna setup with AWS ParallelCluster
description:
date: 2021-04-15
tldr: Setup LS-Dyna with AWS ParallelCluster
draft: false
tags: [EFS, aws parallelcluster, FSx lustre, Ansys]
---


# LS-Dyna setup with AWS ParallelCluster

## Step 1: Setup No-Tears-Cluster

1. Click to launch a stack in your region:

| Region       | Launch                                                                                                                                                                                                                                                                                                              | 
|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| North Virginia (us-east-1)   | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-east-1.svg)](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=AWS-HPC-Quickstart&templateURL=https://notearshpc-quickstart.s3.amazonaws.com/0.2.3/cfn.yaml)       |
| Oregon (us-west-2)    | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-west-2.svg)](https://us-west-2.console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/create/review?stackName=AWS-HPC-Quickstart&templateURL=https://notearshpc-quickstart.s3.amazonaws.com/0.2.3/cfn.yaml)       |
| Ireland (eu-west-1)    | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/eu-west-1.svg)](https://eu-west-1.console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/create/review?stackName=AWS-HPC-Quickstart&templateURL=https://notearshpc-quickstart.s3.amazonaws.com/0.2.3/cfn.yaml)       |
| Frankfurt (eu-central-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/eu-central-1.svg)](https://eu-central-1.console.aws.amazon.com/cloudformation/home?region=eu-central-1#/stacks/create/review?stackName=AWS-HPC-Quickstart&templateURL=https://notearshpc-quickstart.s3.amazonaws.com/0.2.3/cfn.yaml) |

> **Note**: if your region isn't listed above, just click on one of the links and change the region in the Cloudformation console

2. Once the stack is create complete, you'll see a link to the Cloud9 workstation in the **Outputs** tab. Click on that.

![image](https://user-images.githubusercontent.com/5545980/114600409-27404080-9c49-11eb-896b-e937a5d7c487.png)

3. You'll be greeted by the following tab. Type `pl` (short for `pcluster list --color`) to list the cluster, then ssh into the created `hpc-cluster` by typing `pcluster ssh hpc-cluster`

```
$ pl # list clusters
$ pcluster ssh hpc-cluster
```

![image](https://user-images.githubusercontent.com/5545980/114601113-fc0a2100-9c49-11eb-88f2-860582be21cf.png)

## Step 2: Install LS-Dyna

1. Now we're going to install LS-Dyna in the `/fsx` directory. Please ask Ansys/LSTC for the credentials to the FTP site. 

The version we've chosen is `ls-dyna_mpp_s_R12_0_0_x64_centos65_ifort180_avx512_openmpi4.0.0`, which I've broken down the naming scheme below:

|                 | Value        | Description                                                                      |
|-----------------|--------------|----------------------------------------------------------------------------------|
| Version         | 12.0.0       | Latest LS-Dyna version                                                           |
| Precision       | s            | Single precision, substitute 'd' for double                                      |
| MPI/Hybrid      | MPP          | MPP is the MPI version, hybrid (HYB) is OpenMP/MPI                               |
| Platform        | x86_64       | Only x86 platforms currently supported                                           |
| OS              | centos65     | Works with Centos 7 & 8, Amazon Linux 1 & 2                                      |
| Fortran version | ifort180     | Fortran version, doesn't need to be installed.                                   |
| Feature         | avx512       | Intel's Advanced Vector Instructions (AVX), only works on Intel-based instances. |
| MPI Version     | openmpi4.0.0 | Versions compatible with EFA include Open MPI 4.X.X or Intel MPI 2018.X          |

```bash
cd /fsx
USERNAME=#ask ansys/lstc for this
PASSWORD=#ask ansys/lstc for this
wget https://ftp.lstc.com/user/mpp-dyna/R12.0.0/x86-64/ifort_180_avx512/MPP/ls-dyna_mpp_s_R12_0_0_x64_centos65_ifort180_avx512_openmpi4.0.0.gz_extractor.sh --user $USERNAME --password $PASSWORD
wget https://ftp.lstc.com/user/mpp-dyna/R12.0.0/x86-64/ifort_180_avx512/MPP/ls-dyna_mpp_s_R12_0_0_x64_centos65_ifort180_avx512_openmpi4.0.0_sharelib.gz_extractor.sh --user $USERNAME --password $PASSWORD
```

2. Run the extractor scripts and agree to the license:

```bash
$ bash ls-dyna_mpp_s_R12_0_0_x64_centos65_ifort180_avx512_openmpi4.0.0.gz_extractor.sh
# pops up with a license agreement, type 'q' to go to the bottom, then type 'y' to agree and then 'n' to install in /fsx
$ bash ls-dyna_mpp_s_R12_0_0_x64_centos65_ifort180_avx512_openmpi4.0.0_sharelib.gz_extractor.sh
# pops up with a license agreement, type 'q' to go to the bottom, then type 'y' to agree and then 'n' to install in /fsx
$ chmod +x ls-dyna_mpp_s_R12_0_0_x64_centos65_ifort180_avx512_openmpi4.0.0*
```

3. You should now see two binaries:

![image](https://user-images.githubusercontent.com/5545980/114938657-3b747100-9df4-11eb-812a-eee1c5bb8c92.png)

## Step 3: Setup LSTC License Server

Next we're going to setup the LSTC license server on the head node, this allows the compute nodes to reach the license server and checkout licenses. If you'd like to use this license for more than one cluster, I reccomend you do this on a [seperate instance](https://gist.github.com/sean-smith/9392519e358421569275f378f926e806).

> See https://ftp.lstc.com/user/license/License-Manager/LSTC_LicenseManager-InstallationGuide.pdf for detailed setup instructions

1. SSH into the headnode from Cloud9, (you may already be here) by typing `pcluster ssh hpc-cluster` in Cloud9.

2. Next we’re going to download and run the LSTC license server:

```bash
$ mkdir -p ~/lstc_server && cd ~/lstc_server 
$ wget https://ftp.lstc.com/user/license/Job-License-Manager/LSTC_LicenseManager_111345_xeon64_redhat50.
tgz --user $USERNAME --password $PASSWORD
$ tar -xzf LSTC_LicenseManager_111345_xeon64_redhat50.tgz
```

3. Now we’re going to generate the server info to send to Ansys/LSTC. Edit the top 4 lines, as well as the IP ranges:

```bash
[ec2-user@ip-10-0-0-30 lstc]$ ./lstc_server info
Getting server information ...

The hostid and other server information has been written to LSTC_SERVER_INFO.
Please contact LSTC with this information to obtain a valid network license
[ec2-user@ip-10-0-0-30 lstc]$ vim LSTC_SERVER_INFO
[Insert Company Name]
    EMAIL: email@example.com
      FAX: WHO-HAS-A-FAX
TELEPHONE: XXX-XXX-XXXX
...
ALLOW_RANGE:  10.000.000.000 10.000.255.255
```

4. Email LSTC the `LSTC_SERVER_INFO` file, they’ll get back to you with a `server_data` file. Put this in the same directory then start the server:

```bash
# from cloud9, upload the server_data file
$ scp server_data ec2-user@10.0.0.30:~/lstc
$ pcluster ssh hpc-cluster
[ec2-user@ip-10-0-0-30 ~]$ cd lstc
[ec2-user@ip-10-0-0-30 lstc]$ ./lstc_server -l logfile.log
```

5. Once the server is started, you can check the log to make sure it’s running:

```bash
[ec2-user@ip-10-0-0-30 lstc]$ less logfile.log
LSTC License server version XXXXXX started...
Using configuration file 'server_data'
```

6. You can check the license by running:

```bash
[ec2-user@ip-10-0-0-30 lstc]$ ./lstc_qrun -s localhost -r
Using user specified server 0@localhost

LICENSE INFORMATION

PROGRAM          EXPIRATION CPUS  USED   FREE    MAX | QUEUE
---------------- ----------      ----- ------ ------ | -----
MPPDYNA          04/05/2021        384    216    600 |     0
MPPDYNA_971      04/05/2021          0    216    600 |     0
MPPDYNA_970      04/05/2021          0    216    600 |     0
MPPDYNA_960      04/05/2021          0    216    600 |     0
LS-DYNA          04/05/2021          0    216    600 |     0
LS-DYNA_971      04/05/2021          0    216    600 |     0
LS-DYNA_970      04/05/2021          0    216    600 |     0
LS-DYNA_960      04/05/2021          0    216    600 |     0
                   LICENSE GROUP   384    216    600 |     0
```

## Step 4: Setup Slurm

1. Create a file, we'll call it `submit.sh` that'll be used for submitting jobs to Slurm. 

```bash
#!/bin/bash
#SBATCH -p [queue]
#SBATCH -n [cores]

####### LICENSE ##########
export LSTC_LICENSE="network"
export LSTC_LICENSE_SERVER="31010@10.0.0.30"
####### LICENSE ##########

####### USER PARAMS #######
BINARY=/fsx/ls-dyna_mpp_s_R12_0_0_x64_centos65_ifort180_avx512_openmpi4.0.0
INPUT_FILE=/fsx/BendTest/Header_Pole.key
MEMORY=2G
MEMORY2=400M
NCORES=${SLURM_NTASKS}
####### USER PARAMS #######

module load openmpi
mpirun -np ${NCORES} ${BINARY} I=${INPUT_FILE} MEMORY=${MEMORY} MEMORY2=${MEMORY2} NCPU=${NCORES} >> output.log 2>&1
```

We've set `MEMORY = 2G` and `MEMORY2=400M` respectively. You can read more about LS-Dyna memory settings [here](https://www.d3view.com/a-few-words-on-memory-settings-in-ls-dyna/).

# Appendix

## AWS ParallelCluster Config file
```ini
[global]
cluster_template = hpc
update_check = true
sanity_check = true

[aws]
aws_region_name = us-west-1

[aliases]
ssh = ssh {CFN_USER}@{MASTER_IP} {ARGS}

[cluster hpc]
key_name = LS-Dyna-bzwCqolL
base_os = alinux2
scheduler = slurm
master_instance_type = c5.2xlarge
vpc_settings = public-private
queue_settings = efa
dcv_settings = dcv
post_install = s3://notearshpc-quickstart-us-west-1/0.2.3/asset/0bf043376b1a502cbf216e33391b5234489d19e72758e7794f57043e1e830e84.sh
post_install_args = "/shared/spack-v0.16.0 v0.16.0 https://notearshpc-quickstart.s3.amazonaws.com/0.2.3/spack /opt/slurm/log sacct.log"
tags = {"QuickStart" : "NoTearsCluster"}
s3_read_resource = arn:aws:s3:::*
s3_read_write_resource = arn:aws:s3:::ls-dyna-datarepositoryb58c03be-13k8hy90wc4l1/*
master_root_volume_size = 50
cw_log_settings = cw-logs
additional_iam_policies=arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
fsx_settings=fsx-mount

[queue efa]
compute_resource_settings = efa-large
compute_type = ondemand
enable_efa = true
enable_efa_gdr = false
disable_hyperthreading = true
placement_group = DYNAMIC

[compute_resource efa-large]
instance_type = c5n.18xlarge
min_count = 2
max_count = 16
initial_count = 2

[fsx fsx-mount]
shared_dir = /fsx
storage_capacity = 2400

[dcv dcv]
enable = master
port = 8443
access_from = 0.0.0.0/0

[cw_log cw-logs]
enable = false

[vpc public-private]
vpc_id = vpc-05a7970b206b37430
master_subnet_id = subnet-0803aaaa738dde053
```

#### LS-DYNA Slurm Submit Script

```bash

```