---
title: Intel Select Solution Cluster Setup
description:
date: 2020-11-04
tldr: Setup Intel Select Solution with AWS ParallelCluster
draft: false
tags: [ec2, AWS ParallelCluster, hpc, aws]
---

![Intel Select Solution](https://user-images.githubusercontent.com/5545980/98165831-68af1180-1e9b-11eb-8550-55b0df8284eb.png)

# Intel Select Solution Cluster Setup

AWS ParallelCluster is available as an [Intel Select Solution](https://www.intel.com/content/www/us/en/architecture-and-technology/intel-select-solutions-overview.html) for simulation and modeling. Configurations are verified to meet the standards set by the [Intel HPC Platform Specification](https://www.intel.com/content/www/us/en/high-performance-computing/hpc-platform-specification.html), use specific Intel instance types, and are configured to use the Elastic Fabric Adapter (EFA) networking interface. AWS ParallelCluster is the first cloud solution to meet the requirements for the Intel Select Solutions program. Supported instance types include `c5n.18xlarge`, `m5n.24xlarge`, and `r5n.24xlarge`. See [AWS docs](https://docs.aws.amazon.com/parallelcluster/latest/ug/intel-select-solutions.html) for more info.

1. Create a cluster using the following config, the keypair, VPC, subnet and region are automatically picked off your Cloud9 instance.

> If you're not using Cloud9, subsitute the variables `${VPC_ID}`, `${SUBNET_ID}`, `${REGION}` and make a keypair (or use your own called `intel-cluster`

```ini
aws ec2 create-key-pair --key-name intel-cluster --query KeyMaterial --output text > ~/.ssh/intel-cluster
chmod 600 ~/.ssh/intel-cluster

IFACE=$(curl --silent http://169.254.169.254/latest/meta-data/network/interfaces/macs/)
SUBNET_ID=$(curl --silent http://169.254.169.254/latest/meta-data/network/interfaces/macs/${IFACE}/subnet-id)
VPC_ID=$(curl --silent http://169.254.169.254/latest/meta-data/network/interfaces/macs/${IFACE}/vpc-id)
REGION=$(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')

cat > intel-select-solution.ini << EOF
[aws]
aws_region_name = ${REGION}

[aliases]
ssh = ssh {CFN_USER}@{MASTER_IP} {ARGS}

[global]
cluster_template = intel_example
update_check = true
sanity_check = true

[cluster intel_example]
key_name = intel-cluster
base_os = centos7
vpc_settings = ${REGION}
scheduler = slurm
master_instance_type = c5n.9xlarge
compute_root_volume_size = 80
master_root_volume_size = 200
enable_intel_hpc_platform_spec = true
s3_read_write_resource = *
dcv_settings = custom-dcv
queue_settings = c5n, m5n, r5n

[queue c5n]
compute_resource_settings = c5n
disable_hyperthreading = false
placement_group = DYNAMIC
enable_efa = true

[compute_resource c5n]
instance_type = c5n.18xlarge
min_count = 0
max_count = 8

[queue m5n]
compute_resource_settings = m5n
disable_hyperthreading = false
placement_group = DYNAMIC
enable_efa = true

[compute_resource m5n]
instance_type = m5n.24xlarge
min_count = 0
max_count = 8

[queue r5n]
compute_resource_settings = r5n
disable_hyperthreading = false
placement_group = DYNAMIC
enable_efa = true

[compute_resource r5n]
instance_type = r5n.24xlarge
min_count = 0
max_count = 8

[dcv custom-dcv]
enable = master
port = 8443
access_from = 0.0.0.0/0

[fsx myfsx]
shared_dir = /lustre
storage_capacity = 1200
deployment_type = SCRATCH_2

[vpc ${REGION}]
vpc_id = ${VPC_ID}
master_subnet_id = ${SUBNET_ID}
compute_subnet_id = ${SUBNET_ID}
```

2. Install the software on that instance:

```bash
sudo su

# install cluster checker
rpm --import \
https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB
yum-config-manager --add-repo \
https://yum.repos.intel.com/clck/2019/setup/intel-clck-2019.repo
yum-config-manager --add-repo \
https://yum.repos.intel.com/clck-ext/2019/setup/intel-clck-ext-2019.repo
yum -y install intel-clck-2019.8-*  

# install psxe runtime
rpm --import \
https://yum.repos.intel.com/2019/setup/RPM-GPG-KEY-intel-psxe-runtime-2019
yum -y install https://yum.repos.intel.com/\
2019/setup/intel-psxe-runtime-2019-reposetup-1-0.noarch.rpm

yum -y install intel-psxe-runtime

# install intel python
yum-config-manager --add-repo \
https://yum.repos.intel.com/intelpython/setup/intelpython.repo
yum -y install intelpython2 intelpython3
exit
```

Next update the `/etc/intel-hpc-platform-release` file in order to test the network:
```bash
sed -i "s/^\(INTEL_.*\)$/\1:high-performance-fabric-2018.0/" /etc/intel-hpc-platform-release
```

Update `~/.bashrc` to source the correct files:

```bash
cat << EOF >> ~/.bashrc
source /opt/intel/clck/2019.8/bin/clckvars.sh
source /opt/intel/psxe_runtime/linux/bin/psxevars.sh 
source /opt/intel/psxe_runtime_2019/linux/mkl/bin/mklvars.sh intel64

export PATH=/opt/intel/intelpython2/bin:/opt/intel/intelpython3/bin:$PATH 
EOF
```

Source it:

```bash
source ~/.bashrc
```

```bash
export CLCK_SHARED_TEMP_DIR=/home/centos/clck
```

## Slurm Setup

First run `sinfo` to see the partitions we created with the cluster:
```bash
sinfo
```

Next we're going to allocate some nodes to run cluster checker on:

```bash
salloc -p m5n -N 4
```

Create a nodefile:
```bash
cat >> ~/nodefile << EOF
$(hostname) # role: head
compute-dy-m5n24xlarge-1 # role: compute
compute-dy-m5n24xlarge-2 # role: compute
compute-dy-m5n24xlarge-3 # role: compute
compute-dy-m5n24xlarge-4 # role: compute 
EOF
```

Check to make sure it has the correct contents:

```bash
$ cat nodefile 
ip-172-31-30-113 # role: head
compute-dy-m5n24xlarge-1 # role: compute
compute-dy-m5n24xlarge-2 # role: compute
compute-dy-m5n24xlarge-3 # role: compute
compute-dy-m5n24xlarge-4 # role: compute 
```

## Run it

```bash
clck -f nodefile -F select_solutions_sim_mod_user_base_2018.0 --db clck_select_solutions_sim_mod_user_base.db -o clck_select_solutions_sim_mod_user_base.log
```
