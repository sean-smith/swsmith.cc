---
title: Setup FSx Lustre PERSISTENT_2 with AWS ParallelCluster
description:
date: 2022-02-19
tldr: fast filesystem for hpc clusters
draft: false
tags: [fsx lustre, AWS ParallelCluster, hpc, s3, aws]
---

# Setup FSx Lustre PERSISTENT_2 with AWS ParallelCluster

AWS ParallelCluster only supports `PERSISTENT_1`, `SCRATCH_1` and `SCRATCH_2` as filesystems created by the cluster, however to launch filesystems with [PERSISTENT_2](https://docs.aws.amazon.com/fsx/latest/LustreGuide/using-fsx-lustre.html#persistent-2-lustre) (announced at re:Invent 2021), you can create the filesystem outside of pcluster and then mount in the config.

Why use `PERSISTENT_2`?

* 40% cheaper for the same throughput. See [AWS FSx Lustre Pricing](https://aws.amazon.com/fsx/lustre/pricing/)
* Link [multiple S3 Buckets](https://aws.amazon.com/about-aws/whats-new/2021/11/amazon-fsx-lustre-s3-buckets/) with the same Filesystem
* Link and de-link buckets after filesystem creation 

## Steps

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

![image](https://user-images.githubusercontent.com/5545980/151906824-d82e94c3-556f-4308-96d0-50c5ce4d900b.png)

2. Create a new **Inbound Rule**

* Custom TCP
* Port `988` 
* Same CIDR as the VPC `172.31.0.0/16`

![image](https://user-images.githubusercontent.com/5545980/151906849-ebc39085-a21b-47de-8d48-788ee9690ed0.png)

3. Leave **Outbound Rules** as the default:

![image](https://user-images.githubusercontent.com/5545980/151907435-2720da9c-a536-46b4-a8c1-4151e4e13098.png)


# 2. Create FSx Filesystem

1. Go to the [FSx Lustre Console](https://console.aws.amazon.com/fsx/home) and click **Create Filesystem**.
2. On the next screen, select **FSx Lustre**:

![image](https://user-images.githubusercontent.com/5545980/151897695-4dc29278-a9f4-446c-ad13-1a7b95463fb0.png)

3. On the next page, you'll see an option for Persistent. This the new `PERSISTENT_2` type, it's simply called Persistent on the AWS console, `PERSISTENT_2` in the API to maintain backwards compatibility. 

![image](https://user-images.githubusercontent.com/5545980/151899715-0718fc65-95d9-4378-ac74-345625fb06ab.png)

4. Make sure to enabled [LZ4 Compression](https://docs.aws.amazon.com/fsx/latest/LustreGuide/data-compression.html), this both decreases filesystem size and improves performance.

![image](https://user-images.githubusercontent.com/5545980/151899284-d39a42be-28b8-44f4-8ba8-a8f9a57ddd8b.png)

5. Make sure to check the box under **Data Repository Import/Export**, this enables future linking to S3.

![image](https://user-images.githubusercontent.com/5545980/151897852-01da3aba-bdd3-4200-ba94-6f91b22de94c.png)

6. Create the filesystem in the same subnet as AWS ParallelCluster.

![image](https://user-images.githubusercontent.com/5545980/151897874-6c5efd5b-cdcb-4da8-9d45-296fa50f4744.png)

# 3. Attach Filesystem to AWS ParallelCluster

1. After the filesystem has finished creating, grab the filesystem ID from the FSx console:

![image](https://user-images.githubusercontent.com/5545980/151900380-af659899-71dc-44aa-9710-94dca4ec2aef.png)

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

![image](https://user-images.githubusercontent.com/5545980/151900585-e80b9a61-4e87-4a65-9d3a-56ac4af690fe.png)

# 4. Link Filesystem to S3

Once the filesystem has been created, you can now link it to an S3 Bucket. This allows you to sync data back and forth between the filesystem and S3. It also allows you to delete the filesystem and preserve it's content on S3. 

1. Navigate to the [FSx Console](https://console.aws.amazon.com/fsx/home) > Filesystem > **Data repositories** > Click **Create data repository association**.

![image](https://user-images.githubusercontent.com/5545980/154818591-b3e37a01-4177-4f73-a716-a8e04cd29cc2.png)

2. Link to an S3 bucket in the same region:

| Field      | Description |
| ----------- | ----------- |
| Filesystem Path      | Path of the FSx Filesystem to sync back to S3 i.e. `/shared`       |
| Data Repository Path   | Path on S3 to store synced content  i.e. `s3://spack-swsmith/shared`     |

![image](https://user-images.githubusercontent.com/5545980/154818875-a3f7f946-2b83-4bb1-82ae-45c3257b4540.png)

3. Now you can select your import & export settings:

![image](https://user-images.githubusercontent.com/5545980/154818899-93ce108f-a539-4eeb-a538-8856b9a34ca3.png)

