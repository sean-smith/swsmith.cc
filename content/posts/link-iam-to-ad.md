---
title: Link Active Directory to IAM Identity Center 👨‍👨‍👦
description:
date: 2023-08-03
tldr: manage cluster users through IAM
draft: false
og_image: 
tags: [grafana, slurm, aws]
---

In this blogpost we'll describe how to manager POSIX user identities through IAM identity center by setting up propagation to Active Directory. This can be used to create user identities on your HPC cluster without going through the pain of creating them in Active Directory (which requires windows). 

This also allows you to link the IAM user with their POSIX user and give users a 1-click login onto these instances using [SSM RunAsUser](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-preferences-run-as.html) support.

## Setup

1. Setup a Microsoft Managed AD using the following quick create link:

    [Quickcreate: Active Directory Setup 🚀](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=pcluster-ad&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/ad-integration.yaml)

2. Setup [IAM Identity Center](https://console.aws.amazon.com/singlesignon/home?) following [instructions](https://docs.aws.amazon.com/singlesignon/latest/userguide/get-started-enable-identity-center.html?icmpid=docs_sso_console) in the console. **Note:** this must be setup in the same region as your Active Directory but can only be setup in a single region per-account. If you already have it setup in another region, just enable [VPC peering](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html) to bridge the connection between regions.

2. In IAM Identity Center go to **Settings** > **Identity source** > **change identity source** > 

    ![Choose Identity Source](/img/link-iam-to-ad/choose-identity-source.png)

3. On the next page select the directory you setup in **Step 1**

    ![Select AD](/static/img/link-iam-to-ad/select-ad.png)

4. Accept the scary message and proceed:

    ![Accept Error Message](/img/link-iam-to-ad/accept.png)