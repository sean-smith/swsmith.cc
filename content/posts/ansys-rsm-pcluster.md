---
title: Ansys Remote Solve Manager SOCA
description:
date: 2020-12-09
tldr: Use Ansys Remote Solve Manager (RSM) with SOCA
draft: false
tags: [Ansys, SOCA, EFS, aws]
---

# Ansys Remote Solve Manager SOCA

[Remote Solve Manager](https://www.hpc.iastate.edu/guides/using-ansys-rsm) is an Ansys software which enable PBS job submission from Ansys WorkBench interface.

## First install

First set your Ansys Root, we'll use this throughout the doc to edit files:

```bash
export ANSYS_ROOT=/apps/ansys_inc/v202
ll $ANSYS_ROOT # make sure it exists
```

> **Note** Ansys switched from Python 2 to 3 between releases 19.2 and 20.2, the following scripts only work in Python 3. To make this work for versions < 19.2 you'll need to ensure compatibility with Python 2.

RSM is installed by default under `/apps/ansys_inc/v202/RSM/`. 

First launch, start the RSM daemon from the scheduler instance:
```bash
$ANSYS_ROOT/RSM/Config/tools/linux/rsmlauncher start
```

### Configuration

Open the Graphical RSM setup interface, run the following command from a DCV node:

```bash
$ANSYS_ROOT/RSM/Config/tools/linux/rsmclusterconfig
```

TBD

## Customization

By default, RSM does not calculate the number of nodes required, as it does not expect the HPC cluster to be dynamic. To enable this feature, I had to update the XML and create a new wrapper which will calculate the number of nodes based on the CPU ask.
Edit the file: `$ANSYS_ROOT/RSM/Config/xml/hpc_commands_PBS.xml`:

I added the following code between `</precommands>` section

```xml
<command name="calculatenodes">
       <properties>
              <property name="MustRemainLocal">true</property>
       </properties>
       <application>
              <pythonapp>/apps/ansys_inc/v192/RSM/Config/scripts/calculate_nodes.py</pythonapp> 
       </application>
       <arguments>
              <arg>%RSM_HPC_CORES%</arg> 
       </arguments>
       <outputs> 
              <variableName>RSM_NUMBER_NODES_REQUIRED</variableName>
       </outputs>
</command>
```

Next edit the `<arg>` section and change the arg that has the condition `<env name="RSM_HPC_DISTRIBUTED">TRUE</env> ` to this:

```bash
<arg>
       <value>-l select=%RSM_NUMBER_NODES_REQUIRED%</value> 
       <condition>
              <env name="RSM_HPC_DISTRIBUTED">TRUE</env> 
       </condition>
</arg>
```

## Python Script Setup

First we're going to install `pyyaml` using the version of python bundled with Ansys:

```
./runpython -m pip install pyyaml
```

Then create a python file `/apps/ansys_inc/v202/RSM/Config/scripts/calculate_nodes.py` with the following contents:

> The file `/apps/ansys_inc/v202/RSM/Config/scripts/calculate_nodes.py` has some ANSYS libraries dependencies so it **HAS TO BE UNDER THIS PATH**. If we install a new version, then we need to make sure to copy the file to the new version directory

```python
'''
This custom script calculate the number of nodes to provision for Ansys
By default WorkBench assume we use a tradition/on prem cluster with a fixed amount of CPU
This function get the number of processes required, then calculate the number of nodes required based on the
instance type
'''
import os
import sys
import generalUtilities
from applicationConfiguration import IsRunningIronPython
import yaml
import re

def main(args, environment):
    cpus = int(args[0]) # CPU as String sent by ANSYS Workbench
    with open("/apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml", 'r') as stream:
        try:
            queue_type = yaml.safe_load(stream)
            for queues in queue_type:
                queue_json = queue_type.get(queues)
                for queue in queue_json:
                    q = queue_json.get(queue)
                    if 'normal' in q.get('queues'):
                        ec2_instance_type = q.get('instance_type')
        except yaml.YAMLError as exc:
            print(exc)
            return 1

    cpus_count_pattern = re.search(r'[.](\d+)', ec2_instance_type)
    if cpus_count_pattern:
        cpu_count_per_ec2 = int(cpus_count_pattern.group(1)) * 2
    else:
        cpu_count_per_ec2 = 2

    ec2_instance_needed = -(-cpus // cpu_count_per_ec2) # round up without having to import math
    if ec2_instance_needed < 1:
        ec2_instance_needed = 1

    # RSM_NUMBER_NODES_REQUIRED is then used on the hpc_commands_PBS.xml
    generalUtilities.defineRsmVariable("RSM_NUMBER_NODES_REQUIRED", str(ec2_instance_needed)+":ncpus="+str (cpu_count_per_ec2))
    print("!DEFINE RSM_NUMBER_NODES_REQUIRED"+str(ec2_instance_needed)+":ncpus="+str (cpu_count_per_ec2))
    return 0

try:
    if IsRunningIronPython:
        exitCode = main(ipyArgv, ipyEnviron)
        sys.exit(exitCode)
    else:
        if __name__ == '__main__':
            exitCode = main(sys.argv[1:], os.environ)
            sys.exit(exitCode)
except generalUtilities.NonZeroExitCodeException as e:
    generalUtilities.customPrint("RSM_HPC_ERROR=" + e.message, True)
    sys.exit(e.exitCode)
```

Now let's test it:

```bash
./runpython calculate_nodes.py 72
```

## Test RSM

To submit a simple test we're going to use the `rsmclusterconfig` tool:

```bash
$ANSYS_ROOT/RSM/Config/tools/linux/rsmclusterconfig
```

On the Queues screen click the `test` button. You after a few minutes logs will appear and you'll be able to verify if the test succeeded.