---
title: Slurm REST API 📡
description:
date: 2023-03-08
tldr: Submit jobs via the Slurm API in AWS ParallelCluster
draft: false
og_image: /img/slurm-rest-api/architecture.png
tags: [ec2, aws parallelcluster, hpc, aws, slurm]
---

![Slurm Rest API](/img/slurm-rest-api/architecture.png)

The Slurm REST API can be used to programmatically submit and monitor jobs on the cluster.

### Step 1 - Setup Slurm Accounting

First setup [Slurm Accounting](https://pcluster.cloud/02-tutorials/02-slurm-accounting.html) following the instructions.

### Step 2 - Create a Security Group to allow inbound API Requests

By default, your cluster will not be able to accept incoming HTTPS requests to the REST API. You will need to [create a security group](https://console.aws.amazon.com/ec2/v2/home?#CreateSecurityGroup:) to allow traffic from outside the cluster to call the API.

1. Under **Security group name**, enter `Slurm REST API` (or another name of your choosing)
2. Ensure **VPC** matches the cluster's VPC
3. Add an inbound rule and select `HTTPS` under `Type`, then change the `Destination` to the CIDR range you want to have access. In this example we use `Anywhere-IPv4` but you should restrict this down in practice.
4. Click **Create security group**

    ![Security Group](/img/slurm-rest-api/security-group.png)

### Step 3 - Add Additional IAM Permissions

Please follow the instructions under [g. Setup IAM Permissions 🔑](https://pcluster.cloud/02-tutorials/07-setup-iam.html). This step is only required if you're using ParallelCluster UI to setup your cluster.

### Step 4 - Configure your cluster

1. In your cluster configuration, return to the HeadNode section and add **Slurm REST API** Security Group you created above.

    ![Security Group](/img/slurm-rest-api/add-security-group.jpeg)

2. Under `Advanced options` >  click `Add Script` and paste in:

    ```bash
    https://swsmith.cc/scripts/rest-api.sh
    ```

    ![Security Group](/img/slurm-rest-api/post-install.jpeg)

3. Under **Additional IAM permissions**, add the policy:

    ```bash
    arn:aws:iam::aws:policy/SecretsManagerReadWrite
    ```

    ![Cluster Setup](/img/slurm-rest-api/iam-policy.jpeg)

4. Setup the rest of the options following the [accounting tutorial](https://pcluster.cloud/02-tutorials/02-slurm-accounting.html).

5. Create your cluster.

## Call the API

To call the API, we'll use the python [requests](https://requests.readthedocs.io/en/latest/) library.

Set the `headnode_ip`, `cluster_name` and `region` then you can use the following code to call the API:

```python
#!/usr/bin/python3
import boto3
import requests

headnode_ip = '18.220.163.221'
cluster_name = 'rest-api'
region = 'us-east-2'

client = boto3.client('secretsmanager', region_name=region)
jwt_token = client.get_secret_value(SecretId=f"slurm_token_{cluster_name}")

headers = {'X-SLURM-USER-NAME': 'ec2-user', 'X-SLURM-USER-TOKEN': jwt_token.get('SecretString')}

r = requests.get(f"https://{headnode_ip}/slurm/v0.0.36/diag", headers=headers, verify=False)

print(r.text)
```

You'll get a response back like:

```json
{
    "meta": {
    "plugin": {
        "type": "openapi\/v0.0.36",
        "name": "REST v0.0.36"
    },
    "Slurm": {
       "version": {
            "major": 22,
            "micro": 8,
            "minor": 5
       },
       "release": "22.05.8"
    }
...
```

Congrats! You just called the Slurm API on the HeadNode. For other API endpoints see [Slurm REST API Reference](https://slurm.schedmd.com/rest_api.html).