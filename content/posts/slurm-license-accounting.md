---
title: Setup Licensing with AWS ParallelCluster and Slurm 🪪
description:
date: 2021-12-03
tldr: Check licenses in Slurm before starting compute instances.
draft: false
tags: [ec2, aws parallelcluster, hpc, aws, slurm]
---


# Setup Licensing with AWS ParallelCluster and Slurm

Slurm has the ability to track licenses, for example if you have 100 LS-Dyna licenses available, you can have jobs that would exceed that amount stay in pending until some of the licenses free up. Slurm has two ways of doing this:

* Local Licenses - Local licenses are local to the cluster in the `slurm.conf`. Use this if you have only one cluster.
* Remote Licenses - this isn't actually checking the license server, all this means is it's tracked in the slurmd database instead of locally on the cluster.

In this guide we'll assume you have [AWS ParallelCluster](https://www.hpcworkshops.com/05-create-cluster.html) setup and running with [Slurm accounting](https://pcluster.cloud/02-tutorials/02-slurm-accounting.html) enabled.

## Static License Checking

First we're going to add a static amount of licenses to Slurm, this will let us increment and decrement the counter when jobs are submitted. This approach is enough if you only have a single cluster using these licenses, however when you have multiple clusters or other users consuming licenses not via Slurm you'll need to also implement license checking in part 2.

1. First add the licenses to `/opt/slurm/etc/slurm.conf`:

```bash
cat <<EOF > /opt/slurm/etc/slurm.conf
# Licenses
Licenses=lsdyna:100
EOF
```

2. Restart `slurmctld`

```bash
systemctl restart slurmctld
```

3. Now check `scontrol` to see new licenses:

```bash
$ scontrol show lic
LicenseName=lsdyna
    Total=100 Used=0 Free=100 Remote=no
```

## Dynamic License Updates

1. First grab the cluster name by running:

```bash
sacctmgr show clusters format=cluster,controlhost
```

2. Next add the license using the cluster name from before:

```bash
sacctmgr add resource name=lsdyna type=license count=100 server=flex_host servertype=flexlm cluster=parallelcluster
```

3. Now we're going to write a script `/shared/scripts/license-update.py` that'll query the license server and fetch the current number of available licenses and then dynamically update the license server.:

```python
#!/usr/bin/env python

import subprocess
import time
import sys
import os

# Hard code the total number of licenses available to on-prem and AWS
total_lic = 100

print('Total licenses: %s' % total_lic)

# Query LSTC to get license count
out = os.popen('/fsx/sw/LSTC_LicenseManager/lstc_qrun -s 10.0.0.10').read()
print(out)
out_lines = out.split('\n')
n_lic = 0
for lines in out_lines:
    try:
        if lines[:10].strip(' ') != 'centos':
            n_lic += int(lines[72:76])
            print(lines[:10].strip(' '))
    except:
        pass
print('Licenses in use: %s' % n_lic)

avail = total_lic - n_lic
print(avail)

# Update slurm resource with new value
# Be sure to change server
os.system('/opt/slurm/bin/sacctmgr -i modify resource name=lstc server=parallelcluster set count=' + str(int(avail)))
```

4. Create a [crontab](https://crontab.guru/#*_*_*_*_*) to run this script every minute:

```bash
crontab -e
* * * * * /shared/scripts/license-update.py
```

## Using License Constraints

1. In your `sbatch` file add the following line, the number should be equal to the number of cores requested by the job:

```bash
#SBATCH -L lsdyna:100
```

2. Then submit the job, if there's insufficient licenses available, the job will go into `PD` (pending) state until licenses free up.

```bash
sbatch submit.sh
```
