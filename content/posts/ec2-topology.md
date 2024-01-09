---
title: AWS EC2 Topology Graph 📊
description:
date: 2024-01-08
tldr: See network layout of your EC2 Instances
draft: false
tags: [aws]
---

{{< rawhtml >}}
<a href='/scripts/temp/d3graph.html'>
<p align="center">
    <img src='/img/instance-topology.png' alt='Instance Topology Graph' style='border: 0px;' width='400px' />
</p></a>
{{< /rawhtml >}}

[Click for Demo!](/scripts/temp/d3graph.html)

# What is the EC2 Topology API?

[AWS Instance Topology](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/how-ec2-instance-topology-works.html) gives you details on the interconnect between ec2 instances. It's helpful to determine if all the nodes are co-located on the same spine and can even be used when trying to make scaling decision for large ML training runs or HPC jobs.

To call the API, you'll need at least aws cli version `2.13.36`. You can check the version with:

```bash
$ aws --version
aws-cli/2.15.8 Python/3.11.6 Darwin/22.6.0 exe/x86_64 prompt/off
```

Then you can run:

```bash
aws ec2 describe-instance-topology
```

This will return a JSON output similar to the following:

```json
{
    "Instances": [
        {
            "InstanceId": "i-1111111111example",
            "InstanceType": "p4d.24xlarge",
            "GroupName": "my-ml-cpg",
            "NetworkNodes": [
                "nn-1111111111example",
                "nn-2222222222example",
                "nn-3333333333example"
            ],
            "ZoneId": "usw2-az2",
            "AvailabilityZone": "us-west-2a"
        },
        {
            "InstanceId": "i-2222222222example",
            "InstanceType": "p4d.24xlarge",
            "NetworkNodes": [
                "nn-1111111111example",
                "nn-2222222222example",
                "nn-3333333333example"
            ],
            "ZoneId": "usw2-az2",
            "AvailabilityZone": "us-west-2a"
        },
...
```

This is great but hard to visualize, hence why we're adding D3 Graph to this output.

# What is D3 Graph?

D3 Graph is a python library that lets us create our graph in python and then converts the results into HTML + CSS.

1. Install dependencies (suggest doing in a virtualenv):

```bash
pip3 install d3graph
pip3 install scikit-learn
pip3 install seaborn
pip3 install boto3
```

2. Create a python script `instance-topology-graph.py`

```python
# Import library
from d3graph import d3graph, vec2adjmat
import boto3
from pprint import pprint

ec2 = boto3.client('ec2', region_name='us-west-2')

response = ec2.describe_instance_topology(Filters = [{'Name':'instance-type', 'Values':['p4de.24xlarge']}])

pprint(response.get('Instances'))

# Create example network
source = []
target = []
for instance in response.get('Instances'):
    instance_id = instance.get('InstanceId')
    for network_node in instance.get('NetworkNodes'):
        source += [instance_id]
        target += [network_node]

pprint(source)
pprint(target)

# Convert to adjacency matrix
adjmat = vec2adjmat(source, target)

# # Initialize
d3 = d3graph()
# Proces adjmat
d3.graph(adjmat)
# Plot
d3.show()

# Make changes in node properties
d3.set_node_properties(color=adjmat.columns.values)
# Plot
d3.show(filepath='temp/')
```

3. Next run it, changing region and instance type for your use case:

```bash
python3 d3.py
```

Voila! a file `d3graph.html` will get created in a `temp/` directory. You can now open that file to see your instance topology.