---
title: Cost Explorer with AWS ParallelCluster 📊
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

![Activate Tags](/img/cost-explorer/cost-allocation-tags.png)

**Update:** [as of June 8th 2022](https://aws.amazon.com/about-aws/whats-new/2022/06/aws-cost-allocation-tag-api/), you can activate these tags programmatically from the AWS API, CLI or SDK.

### Wait 24 hours 📆 🥱

2. Then go to [Cost Explorer](https://console.aws.amazon.com/cost-management/home?#/custom?) > Click on **Tags** on the right side and select `parallelcluster:cluster-name` and the cluster you wish to display the cost of. If you don't see the tag, it's most likely since it hasn't been 24 hours since you activated it 🥱.

![Cost Explorer Dashboard](/img/cost-explorer/dashboard.png)

You can group by **Instance Type** to breakdown cost by instance type, you can group by **Service** to break down costs between EC2, EBS, ect.

# Custom Tags

You can also track resources based on custom tags, such as **user**, **job id**, **project**, ect... Please keep in mind the following caveats:

1. Jobs must use up a full instance, i.e. multiple jobs cannot run on the same instance at the same time. We accomplish this in the script below with the `--exclusive` flag.
2. Jobs that span more than one instance need to apply the tag to each instance. Slurm only executes the sbatch script on the first instance in the reservation. To do this you can wrap the `aws create-tags` command in `mpirun`.

## Setup

1. Step 1 is to add permissions to create those tags. Create an IAM role called `pclustertagging` with the following content:

    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:DeleteTags",
                    "ec2:DescribeTags",
                    "ec2:CreateTags"
                ],
                "Resource": "*"
            }
        ]
    }
    ```

2. Next attach it to the head node and compute nodes in the cluster using the [AdditionalIamPolicies](https://docs.aws.amazon.com/parallelcluster/latest/ug/Scheduling-v3.html#yaml-Scheduling-SlurmQueues-Iam-AdditionalIamPolicies) parameter.

    ```yaml
    Iam:
        AdditionalIamPolicies:
            - Policy: arn:aws:iam::822857487308:policy/pclustertagging
    ```

3. In your job submission script, add the tag **before** your submit command:

    ```bash
    #!/bin/bash
    #SBATCH -N 1
    #SBATCH --exclusive

    # get instance id and tag instance with job id
    instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | )
    aws --region ${region} ec2 create-tags --resources ${instance_id} --tags Key=parallelcluster:job-id,Value=${SLURM_JOB_ID}

    # rest of job submission
    # ...
    ```

    In the following table I list environment variables that can be used for the tag:

    |         | **Environment Variable** | **Description**                                                          |
    |---------|---------------------------|--------------------------------------------------------------------------|
    | User    | `$USER`                   | User submitting the job.                                                 |
    | Job ID  | `$SLURM_JOB_ID`           | Job ID assigned by Slurm.                                                |
    | Project | `$SLURM_JOB_NAME`         | Job name can be used to track project / application, i.e. `cfd` or `fea` |

4. Now when the job is launched you can run a similar query on cost explorer but get data from these tags. In the following example I added a tag `parallelcluter:project` and then used that to see aggregate project costs across all my clusters.

    ![Custom Tag](/img/cost-explorer/custom-tag.png)