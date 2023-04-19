---
title: Setup FlexLM License Server 🪪
description:
date: 2023-04-19
tldr: Setup FlexLM license server for HPC Workloads
draft: false
og_image: 
tags: [flexlm, aws, hpc]
---

![FlexLM Architecture Diagram](/img/flexlm/architecture.png)

[FlexLM](https://www.openlm.com/what-is-flexlm-what-is-flexnet/) is the most popular license server for HPC workloads. It's the license server for applications like Siemens StarCCM+, Ansys Fluent, Abaqus, ect. 

Once you have the licensing setup you can setup license tracking in Slurm following the blogpost [Setup Licensing with AWS ParallelCluster and Slurm 🪪](/posts/slurm-license-accounting.html).

## Setup

To setup FlexLM on AWS we're going to launch a small instance, install the license software and enable [termination protection](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ec2-instance.html#cfn-ec2-instance-disableapitermination) to protect the license server from being inadvertently terminated.

1. First launch an instance using the following Cloudformation stack [flexlm.yaml](/templates/flexlm.yaml). Change the region in the upper right from `us-east-1` to your desired region. Make sure to launch the stack in the same VPC as your cluster so you can later connect to two.

    [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/launch-stack.svg)](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?stackName=FlexLM&templateURL=https://s3.amazonaws.com/swsmith.cc/static/flexlm.yaml)


2. Next navigate to the security group created by the stack:

    ![FlexLM Stack Output](/img/flexlm/cfn-stack-ouput.png)

3. Setup ingress rules to connect the instance to the cluster. For AWS ParallelCluster it'll need access to the **HeadNode Security Group** and **Compute Node Security Group**.

    ![FlexLM Security Group](/img/flexlm/security-group.png)

3. Run the following commands to install the FlexLM License server

    ```bash
    # start the server
    lmgrd -c path/to/license.lic

    # check status
    lmutil lmstat -a
    ```

4. Next we'll verify connection to the license server from the cluster. Login to the Headnode of your cluster and run:

    ```bash
    lmstat -a -s 27000@ip
    ```