---
title: Distributed training from scratch on Nvidia H100's
description:
date: 2024-01-31
tldr: Do distributed training the hard way.
draft: false
tags: [nvidia, H100, nccl, slurm, aws]
---

Similar to [Linux From Scratch](https://www.linuxfromscratch.org/) this blogpost details how to setup distributed training on AWS from scratch i.e. not using an orchestrator like ParallelCluster, EKS or SageMaker HyperPods. I wouldn't suggest this approach as it involves a lot of unnecessary hair pulling, however I still wanted to document it so the reasons to use the higher level orchestrators are clear.

Specifically we'll focus on the Nvidia H100 based-instance, `p5.48xlarge`. This instance has some peculiarities such as 32 network interfaces that make it different enough to be the "harder" instance. After going through this process with the p5, other instances such as p4d.24xlarge (A100) will be easier. 

| Instance Type | vCPUs | H100 GPU | GPU  Memory | Network Bandwidth | GPUDirect RDMA | GPU Peer to Peer  | Instance Storage (TB) |
|---------------|-------|----------|-------------|-------------------|---------------|-------------------|:-----------------------:|
|  p5.48xlarge  |  192  | 8        | 640 GB HBM3 |  3200 Gbps EFAv2  | Read/Write    | 900 GB/s NVSwitch |   8 x 3.84 NVMe SSD   |

## Setup

Ok let's talk about the building blocks of a cluster, what do we actually need? 

You might think we just need a few `p5.48xlarge` EC2 instances, which is correct but it's only a starting point. We also need a *shared filesystem* to connect all the instances, we need to make sure that those instances are launched in the same network spine, i.e. using a *Placement Group*, and we need to make sure the networking supports *inter-instance communication*, i.e. our torchrun process can communicate between all the nodes easily using a shared SSH key.

1. Launch instances
2. Setup EFA Networking
3. Mount Parallel Filesystem i.e. FSx Lustre
4. Launch distributed training

## Instance Launch

Launching the instance involves choosing an OS i.e. Amazon Machine Image (AMI). The AMI we'll use is the Deep Learning AMI, this saves a ton of time as it already has CUDA, NCCL, EFA and AWS OFI NCCL installed. I know I said this was from scratch but I do believe it's worth using this image as it saves a ton of time.

We'll need to setup the networking primitives i.e. VPC, Subnets and Security Group. We'll need to create a keypair and 

1. Get the latest [Deep Learning AMI, Ubuntu 20.04](https://aws.amazon.com/releasenotes/aws-deep-learning-base-gpu-ami-ubuntu-20-04/) in your desired region:

```bash
$ ami_id=$(aws ec2 describe-images --region us-east-1 --owners amazon --filters 'Name=name,Values=Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 20.04) ????????' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
$ echo -e "Deep Learning AMI: $ami_id"
```

2. Create a [EFA compatible](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html#efa-start-security) security group:

```bash
aws ec2 create-security-group --group-name P5Group --description "EFA security group"

# Allow SSH access
aws ec2 authorize-security-group-ingress --group-id $efa_sg --protocol tcp --port 22 --cidr 0.0.0.0/0

# allow internet traffic out (optional)
aws ec2 authorize-security-group-egress --group-id $efa_sg --protocol tcp --port -1 --cidr 0.0.0.0/0

# Setup special EFA rules, this allows all inbound and outbound traffic to itself
aws ec2 authorize-security-group-ingress --group-id $efa_sg --protocol tcp --port -1 --reference-group-id $efa_sg
aws ec2 authorize-security-group-ingress --group-id $efa_sg --protocol -1 --port -1 --reference-group-id $efa_sg
```

3. Create VPC and Subnets. We need a *Private Subnet* for the instances. **If you launch p5's in a public subnet they will not work properly.** Click the following button to launch the VPC stack.

{{< rawhtml >}}
<p align="center">
    <a href="https://console.aws.amazon.com/cloudformation/home?#/stacks/quickcreate?templateURL=https%3A%2F%2Fawsome-distributed-training.s3.amazonaws.com%2Ftemplates%2F1.vpc-multi-az.yaml&stackName=ML-VPC"><button>Launch VPC Stack <i data-feather="cloud"></i></button></a>
</p>
{{< /rawhtml >}}

4. Create a [Placement Group](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html). 

```bash
$ efa_sg=$(aws ec2 create-placement-group --group-name efa-sg --strategy cluster)
$ echo -e "Security Group Id: $efa_sg"
```

5. Launch EC2 instances

```bash
$ aws --region $REGION ec2 run-instances \
 --instance-type p5.48xlarge \
 --count 8 \
 --placement-group $efa_pg \
 --image-id $ami_id \
 --network-interfaces "NetworkCardIndex=0,DeviceIndex=0,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=1,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=2,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=3,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=4,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=5,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=6,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=7,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=8,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=9,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=10,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=11,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=12,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=13,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=14,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=15,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=16,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=17,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=18,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=19,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=20,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=21,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=22,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=23,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=24,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=25,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=26,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=27,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=28,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=29,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=30,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa" \
                      "NetworkCardIndex=31,DeviceIndex=1,Groups=$efa_sg,SubnetId=$private_subnet,InterfaceType=efa"
```

## Parallel Filesystem

1. Create a Filesystem

```bash

```

## Connect to Cluster

We launched the p5 instances in a private subnet so we can't directly SSH to them. Luckily we can use SSM to connect to them. 

1. 

```bash
instance_id=$()

aws ssm start-session \
    --target $instance_id
```