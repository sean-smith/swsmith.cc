---
title: Cost Explorer with AWS ParallelCluster
description:
date: 2022-02-11
tldr: Track cluster cost with AWS Cost Explorer
draft: false
tags: [ec2, AWS ParallelCluster, hpc, aws, cost explorer]
---

# Cost Explorer with AWS ParallelCluster

Budgets allow you to track cost at the per-cluster basis, they do this by tracking tags applied automatically to EC2 Instances launched with pcluster.

This gives users a view of exactly how much a cluster costs overtime, it tracks:

* EC2 Instances
* EBS Volumes
* ~FSx Lustre Volumes~
* ~EFS Volumes~

1. Activate the `parallelcluster:cluster-name` tag in the [Billing Dashboard > Cost Allocation Tags](https://console.aws.amazon.com/billing/home?#/tags)

![image](https://user-images.githubusercontent.com/5545980/154155545-cfa4554f-10ce-4abd-8784-fcf7d12277b8.png)

### Wait 24 hours 📆 🥱

2. Then go to [Cost Explorer](https://console.aws.amazon.com/cost-management/home?#/custom?) > Click on **Tags** on the right side and select `parallelcluster:cluster-name` and the cluster you wish to display the cost of. If you don't see the tag, it's most likely since it hasn't been 24 hours since you activated it 🥱.

![image](https://user-images.githubusercontent.com/5545980/154816048-229d6106-de8c-4cc0-a904-3c8d56654ae3.png)

You can group by **Instance Type** to breakdown cost by instance type, you can group by **Service** to break down costs between EC2, EBS, ect.
