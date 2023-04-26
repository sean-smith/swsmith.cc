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

In the following guide we'll setup a license server that can be used with FlexLM (or any other linux-based licensing client). Once you have the licensing setup you can setup license tracking in Slurm following the blogpost [Setup Licensing with AWS ParallelCluster and Slurm 🪪](/posts/slurm-license-accounting.html).

## Instance Type

FlexLM has pretty minor compute requirements, just 2 cores and 4 GB of memory, so it can be easily run on a small (cheap) instance like the `t3.medium` however if you want to run 1,000's of jobs the license server can quickly become the bottleneck. For workloads like these, I recommend using a `c6in.4xlarge`. This should sufficient for 1,000's of jobs all pinging the license server at the same time.

## Maintaining the same MAC Address

Many license servers require a unique, immutable, identifier for the license server. This is typically done with a mac address of the network card, a small uuid that looks like `02:73:ae:2a:dc:81`. In the AWS world the network interface (virtual network card) can change if the instance is rebooted or terminated and re-launched. To avoid this, we've attached an Elastic Network Interface (ENI) that's created externally to the instance. This allows us to terminate and re-launch without changing the mac address and requiring a new license. You can read more about it [here](https://docs.aws.amazon.com/whitepapers/latest/run-semiconductor-workflows-on-aws/license-server-setup.html#improving-license-server-reliability).

In addition, most licensing clients look for a fixed ip address when connecting to the server. To keep this from getting changed in reboots by `dhclient`, we've attached an elastic ip (eip) address. This is attached to the ENI, so even if the instance terminates we can easily bring up another instance and attach it to the same ENI and keep the same ip address.

![EC2 Instance with Attached ENI](/img/flexlm/ec2-eni-eip.png)

## Setup

To setup FlexLM on AWS we're going to launch a CloudFormation stack. This will create an EC2 Instance, Elastic Network Interface (ENI), Elastic IP Address (EIP) and a Security Group. On the EC2 instance, it enables [termination protection](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ec2-instance.html#cfn-ec2-instance-disableapitermination) which protects the license server from being inadvertently terminated.

1. First launch an instance using the following Cloudformation stack [flexlm.yaml](/templates/flexlm.yaml). Change the region in the upper right from `us-east-1` to your desired region. Make sure to launch the stack in the same VPC as your cluster so you can later connect to two.

    [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/launch-stack.svg)](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?stackName=FlexLM&templateURL=https://s3.amazonaws.com/swsmith.cc/static/flexlm.yaml)


2. Next navigate to the security group created by the stack:

    ![FlexLM Stack Output](/img/flexlm/cfn-stack-ouput.png)

3. Setup ingress rules to connect the instance to the cluster. For AWS ParallelCluster it'll need access to the **HeadNode Security Group** and **Compute Node Security Group**.

    ![FlexLM Security Group](/img/flexlm/security-group.png)

4. Next you can grab the mac address of the eni by running `ifconfig`. Take the address associated with the `eth0` device, next to `ether`:

    ![ifconfig](/img/flexlm/ifconfig.png)

5. Run the following commands to install the FlexLM License server

    ```bash
    # start the server
    lmgrd -c path/to/license.lic

    # check status
    lmutil lmstat -a
    ```

6. Next we'll verify connection to the license server from the cluster. Login to the Headnode of your cluster and run:

    ```bash
    lmstat -a -s 27000@ip
    ```