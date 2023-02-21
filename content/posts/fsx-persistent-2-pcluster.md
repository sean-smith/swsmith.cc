---
title: Setup FSx Lustre PERSISTENT_2 with AWS ParallelCluster
description:
date: 2022-02-19
tldr: fast filesystem for hpc clusters
draft: false
og_image: /img/fsx-lustre/architecture.png
tags: [fsx lustre, AWS ParallelCluster, hpc, s3, aws]
---
![FSx Lustre + ParallelCluster Architecture](/img/fsx-lustre/architecture.png)

## Overview 

AWS ParallelCluster only supports `PERSISTENT_1`, `SCRATCH_1` and `SCRATCH_2` as filesystems created by the cluster, however to launch filesystems with [PERSISTENT_2](https://docs.aws.amazon.com/fsx/latest/LustreGuide/using-fsx-lustre.html#persistent-2-lustre) (announced at re:Invent 2021), you can create the filesystem outside of pcluster and then mount in the config.

Why use `PERSISTENT_2`?

* 40% cheaper for the same throughput. See [AWS FSx Lustre Pricing](https://aws.amazon.com/fsx/lustre/pricing/)
* Link [multiple S3 Buckets](https://aws.amazon.com/about-aws/whats-new/2021/11/amazon-fsx-lustre-s3-buckets/) with the same Filesystem
* Link and de-link buckets after filesystem creation 

## Setup

From the AWS ParallelCluster [docs](https://docs.aws.amazon.com/parallelcluster/latest/ug/fsx-section.html) we learn:

> If using an existing file system, it must be associated to a security group that allows inbound TCP traffic to port 988.

So we'll need to:

1. Create the Security Group
2. Create the filesystem & associate the security group
3. Create a cluster that mounts the filesystem

## 1. Create Security Group

1. Create a new Security Group by going to [Security Groups](https://console.aws.amazon.com/ec2/v2/home?#SecurityGroups:) > **Create Security Group**: 

* **Name** `FSx Lustre`
* **Description** `Allow FSx Lustre to mount to ParallelCluster`
* **VPC** `Same as pcluster vpc`

![image](/img/fsx-lustre/create-sg.png)

2. Create a new **Inbound Rule**

* Custom TCP
* Port `988` 
* Same CIDR as the VPC `172.31.0.0/16`

![Inbound Rule](/img/fsx-lustre/inbound-rule.png)

3. Leave **Outbound Rules** as the default:

![Outbound Rule](/img/fsx-lustre/outbound-rule.png)

# 2. Create FSx Filesystem

1. Go to the [FSx Lustre Console](https://console.aws.amazon.com/fsx/home) and click **Create Filesystem**.
2. On the next screen, select **FSx Lustre**:

![Select FSx Lustre](/img/fsx-lustre/fsx-lustre.png)

3. On the next page, you'll see an option for Persistent. This the new `PERSISTENT_2` type, it's simply called Persistent on the AWS console, `PERSISTENT_2` in the API to maintain backwards compatibility. 

![Persistent_2](/img/fsx-lustre/throughput-options.png)

4. Make sure to enabled [LZ4 Compression](https://docs.aws.amazon.com/fsx/latest/LustreGuide/data-compression.html), this both decreases filesystem size and improves performance.

![Data Compression](/img/fsx-lustre/data-compression.png)

5. Make sure to check the box under **Data Repository Import/Export**, this enables future linking to S3.

![DRA Import](/img/fsx-lustre/dra-import.png)

6. Create the filesystem in the same subnet as AWS ParallelCluster.

![Subnet/SG Setup](/img/fsx-lustre/subnet-sg.png)

# 3. Attach Filesystem to AWS ParallelCluster

1. After the filesystem has finished creating, grab the filesystem ID from the FSx console:

![image](/img/fsx-lustre/fsx-id.png)

2. Update the config file to include that filesystem id:

```yaml
SharedStorage:
  - Name: FsxLustre
    StorageType: FsxLustre
    MountDir: /shared
    FsxLustreSettings:
      FileSystemId: fs-12345678910 # <- fs id from the fsx console
```

3. If you're using [pcluster-manager](https://github.com/aws-samples/pcluster-manager), simply check the box next to **Use Existing Filesystem** and select the filesystem you just created:

![ParallelCluster UI](/img/fsx-lustre/pcluster-ui.png)

# 4. Link Filesystem to S3

Once the filesystem has been created, you can now link it to an S3 Bucket. This allows you to sync data back and forth between the filesystem and S3. It also allows you to delete the filesystem and preserve it's content on S3. 

1. Navigate to the [FSx Console](https://console.aws.amazon.com/fsx/home) > Filesystem > **Data repositories** > Click **Create data repository association**.

![Create DRA](/img/fsx-lustre/create-dra.png)

2. Link to an S3 bucket in the same region:

| Field      | Description |
| ----------- | ----------- |
| Filesystem Path      | Path of the FSx Filesystem to sync back to S3 i.e. `/shared`       |
| Data Repository Path   | Path on S3 to store synced content  i.e. `s3://spack-swsmith/shared`     |

![Link S3 Bucket](/img/fsx-lustre/link-dra.png)

3. Now you can select your import & export settings:

![Import and Export](/img/fsx-lustre/import-export.png)

