---
title: Connect to AWS ParallelCluster with EC2 Instance Connect
description:
date: 2022-02-11
tldr: SSH/SCP into cluster without a keypair
draft: false
tags: [ec2, AWS ParallelCluster, hpc, aws]
---

# Connect to AWS ParallelCluster with EC2 Instance Connect

EC2 Instance connect allows you to SSH into an EC2 instance without a keypair. You can also perform basic file transfer i.e. SFTP and SCP with it.

**Advantages:**
* doesn't require an SSH keypair
* connects to private IP addresses (you still need network connectivity)

You can read more about it [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html#ec2-instance-connect-connecting-ec2-cli).

1. First install the `ec2instanceconnectcli` helper:

```bash
pip install ec2instanceconnectcli
```

2. Connect to the instance with the mssh command:

```bash
export AWS_DEFAULT_REGION='us-east-2'
mssh $(pcluster describe-cluster --cluster-name hpc6a | jq -r '.headNode.instanceId')
```

The above command can be shortened using a bash alias:

```bash
# usage: pssh [cluster-name]
pssh() {
    mssh $(pcluster describe-cluster --cluster-name ${1} | jq -r '.headNode.instanceId')
}
```

And then simply run as:

```bash
pssh hpc6a
```

## Transfer Files

You can transfer a file, for example `README.md` to the cluster via:

```bash
tar -cf - README.md | mssh i-0117826db1caefe88 --region us-east-2 tar -xvf -
```

This can be set as an alias:

```bash
# usage: pscp [cluster-name] [filepath]
pscp() {
    tar -cf - ${2} | mssh $(pcluster describe-cluster --cluster-name ${1} | jq -r '.headNode.instanceId') tar -xvf -
}
```

and run like:

```bash
pscp hpc6a README.md
```