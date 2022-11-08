---
title: Setup Licensing with AWS ParallelCluster and Slurm
description:
date: 2021-12-03
tldr: Check licenses in Slurm before starting compute instances.
draft: false
tags: [ec2, aws parallelcluster, hpc, aws, slurm]
---


# Setup Licensing with AWS ParallelCluster and Slurm

In this guide we'll assume you have a slurm cluster up and running with [Slurm accounting](https://aws.amazon.com/blogs/compute/enabling-job-accounting-for-hpc-with-aws-parallelcluster-and-amazon-rds/) setup already.

## Static License Checking

First we're going to add a static amount of licenses to Slurm, this will let us increment and decrement the counter when jobs are submitted. This approach is enough if you only have a single cluster using these licenses, however when you have multiple clusters or other users consuming licenses not via slurm you'll need to also implement the dynamic checking in part 2. 

1. First add the licenses to `/opt/slurm/etc/slurm.conf`:

```
cat <<EOF > /opt/slurm/etc/slurm.conf
# Licenses
Licenses=lsdyna:100
EOF
```

2. Restart slurmctld and check scontrol to see new licenses:

```
systemctl restart slurmctld
scontrol show lic
```

## Dynamic License Updates

Now we're going to dynamically check the license server and update Slurm accordingly.

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
os.system('/opt/slurm/bin/sacctmgr -i modify resource name=lstc server=10.0.0.10 set count=' + str(int(avail)))
```

## Using License Constraints

1. In your `sbatch` file add the following line, the number should be equal to the number of cores requested by the job:

```bash
#SBATCH -L lsdyna:100
```