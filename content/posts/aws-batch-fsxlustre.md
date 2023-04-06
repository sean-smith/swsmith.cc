---
title: Mount FSx Lustre on AWS Batch
description:
date: 2022-04-30
tldr: Mount FSx Lustre on AWS Batch
draft: false
tags: [fsx, AWS Batch, hpc, s3, aws]
---

# Mount FSx Lustre on AWS Batch

This guide describes how to mount FSx Lustre filesystem. I give an example cloudformation stack to create the AWS Batch resources.

I loosely follow [this guide](https://aws.amazon.com/premiumsupport/knowledge-center/batch-fsx-lustre-file-system-mount/).

For the parameters, it's important that the **Subnet**, **Security Group**, **FSx ID** and **Fsx Mount Name** follow the guidelines below:

| Parameter      | Description |
| ----------- | ----------- |
| Subnet ID      | I suggest launching the batch job in the same subnet as the   |
| Security Group      | Must allow [mounting the filesystem](https://docs.aws.amazon.com/fsx/latest/LustreGuide/limit-access-security-groups.html) port 988. An easy trick is to allow all traffic for the subnet CIDR range i.e. `10.0.0.0/16`  |
| FSx ID   | This is the filesystem ID from the FSx Console. Typically looks like: `fs-01784f008854263c0`         |
| FSxMountName | grab this from the FSx Console > Attach. It typically looks like `egn2zbmv` |


```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: >
 Setup for AWS Batch + FSx Lustre. Contact seaam@amazon.com for details.

Parameters:
  Environment:
    Type: String
    Description: Environment name for AWS Batch
    Default: 'FSxLustreBatch'
  SubnetIDs:
    Type: List<AWS::EC2::Subnet::Id>
    Description: Subnets for AWS Batch Compute Environment
  SecurityGroupIds:
    Type: List<AWS::EC2::SecurityGroup::Id>
    Description: Security Group for AWS Batch Compute Environment
  FSxID:
    Type: String
    Description: FSx ID of the Lustre filesystem.
  FSxMountName:
    Type: String
    Description: FSx Lustre Mount Name.

##########################
## Batch Infrastructure ##
##########################
Resources:
  # Configure IAM roles for Batch
  ECSTaskServiceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: 2012-10-17
        Statement:
          -
            Effect: Allow
            Principal:
              Service:
                - ec2.amazonaws.com
            Action:
              - sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role
  ECSTaskInstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Path: /
      Roles:
        - !Ref ECSTaskServiceRole
      InstanceProfileName: !Join [ "", [ "ECSTaskInstanceProfileIAM-", !Ref Environment ] ]

  # Launch template
  LaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties: 
      LaunchTemplateData: 
        UserData:
          Fn::Base64: !Sub |
            MIME-Version: 1.0
            Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

            --==MYBOUNDARY==
            Content-Type: text/cloud-config; charset="us-ascii"

            runcmd:
            - amazon-linux-extras install -y lustre2.10
            - mkdir -p /fsx
            - mount -t lustre -o noatime,flock ${FSxID}.fsx.${AWS::Region}.amazonaws.com@tcp:/${FSxMountName} /fsx
            --==MYBOUNDARY==--

  # Build the AWS Batch CEs
  BatchComputeEnv:
    Type: AWS::Batch::ComputeEnvironment
    Properties:
      Type: MANAGED
      ComputeResources:
        AllocationStrategy: SPOT_CAPACITY_OPTIMIZED
        MaxvCpus: 600
        SecurityGroupIds: !Ref SecurityGroupIds
        Subnets: !Ref SubnetIDs
        Type: SPOT
        MinvCpus: 0
        InstanceRole: !Ref ECSTaskInstanceProfile
        InstanceTypes:
          - optimal
        LaunchTemplate:
          LaunchTemplateId: !Ref LaunchTemplate
          Version: $Latest
        DesiredvCpus: 0
      State: ENABLED

  Queue:
    Type: AWS::Batch::JobQueue
    Properties:
      ComputeEnvironmentOrder:
        - ComputeEnvironment: !Ref BatchComputeEnv
          Order: 1
      Priority: 1
      State: "ENABLED"

  JobDefinition:
    Type: AWS::Batch::JobDefinition
    Properties:
      ContainerProperties:
          Command:
            - ls /fsx
          Image: busybox
          Memory: 1024
          MountPoints: 
            -  ContainerPath: /fsx
               SourceVolume: FSx
          Vcpus: 1
          Volumes: 
            -   Host: 
                  SourcePath: /fsx
                Name: FSx
      JobDefinitionName: FSxSample
      Type: container



#############
## Outputs ##
#############
Outputs:
  ComputeEnvironment:
    Value: !Ref BatchComputeEnv
  JobQueue:
    Value: !Ref Queue
  LaunchTemplate:
    Value: !Ref LaunchTemplate
  JobDefinition:
    Value: !Ref JobDefinition
```

To test this I submitted a sample job. I was able to see that it mounted the filesystem by looking in the logs and seeing the ouput of my `ls /fsx` command:

![FSx Lustre Logs](/img/batch-lustre/logs.png)