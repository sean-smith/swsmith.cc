---
title: FSx Lustre as a Cache for S3 🗃️
description:
date: 2023-02-28
tldr: Reduce filesystem costs with intelligent caching where data is pulled from S3 into FSx Lustre when needed and evicted when the filesystem reaches a threshold.
draft: false
og_image: /img/fsx-lustre/architecture.png
tags: [fsx lustre, AWS ParallelCluster, hpc, s3, aws]
---

![FSx Lustre + S3 + AWS ParallelCluster](/img/fsx-lustre/architecture.png)

## Overview

[FSx Lustre](https://aws.amazon.com/fsx/lustre/) is a powerful filesystem for workloads that require low-latency, parallel access, however this comes at a cost, sometimes 5 x greater than S3. To avoid paying to keep all your data in Lustre, you can setup a link between S3 and FSx Lustre. When data is requested it's pulled from S3 and "cached" in Lustre and when it's no longer needed it's evicted from Lustre and the only copy sits in S3. An example of how this saves money is as follows:

{{< rawhtml >}}
<p align="center">
    <img src='/img/fsx-lustre-cache/fsx-costs.png' alt='Cost Difference' style='border: 0px;' />
</p>
{{< /rawhtml >}}

In this example, a **cost savings of 60%** is achieved by reducing the size of FSx Lustre from 20 TB to 5 TB. In your case the size of the fast scratch could be even less. I suggest using a rough rule of thumb that 10% of total data needs to be in lustre. You can always increase this amount if you see lots of cache misses.

To achieve even greater cost savings you can combine this with Intelligent Tiering (IA) from S3. This moves data that's not frequently accessed to less expensive S3 storage tiers. The data can still be moved back from these storage tiers into Lustre when needed.

## Setup

1. Setup a cluster with a **FSx Lustre PERSISTENT_2** filesystem and link it to S3 following my [previous blogpost](fsx-persistent-2-pcluster.html).

2. Next update the HeadNode to allow the S3 access by adding the policy `arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess`:

    ParallelCluster UI:

    ![S3 Policy](/img/fsx-lustre-cache/S3Policy.png)

    or via the CLI:

    ```yaml
      Iam:
        AdditionalIamPolicies:
          - Policy: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
          ...
    ```

2. Next download the script [cache-eviction.sh](https://swsmith.cc/scripts/cache-eviction.sh) to remove files from lustre when the filesystem reaches a certain threshold:

    ```bash
    cd /opt/parallelcluster/shared
    wget https://swsmith.cc/scripts/cache-eviction.sh
    chmod +x cache-eviction.sh
    ```

3. Install `boto3` and run the script to validate it works:

    ```bash
    pip3 install boto3
    ./cache-eviction.sh -mountpath /shared -minage 30 -minsize 2000 -bucket spack-swsmith -mountpoint /shared
    ```

    | **Parameter** | **Description**                                     |
    |---------------|-----------------------------------------------------|
    | -mountpath    | Path to where the filesystem is mounted.            |
    | -mountpoint   | Path to where the Data Repository (DRA) is linked.  |
    | -minage       | Age in days of files to consider for eviction.      |
    | -minsize      | Age in Bytes of files to consider for eviction.     |
    | -bucket       | Bucket that's linked to the filesystem.             |

2. Next setup a [crontab](https://crontab.guru/) on the HeadNode to automatically evict filesystem content when you hit a certain threshold. This script runs every hour on the 00:05 and evicts files that haven't been accessed in the last 30 days (atime) and are > 2 MB in size. Feel free to customize the parameters to suit your needs.

    ```bash
    5 * * * * /opt/parallelcluster/shared/cache-eviction.sh -mountpath /shared -mountpoint /shared -minage 30 -minsize 2000 -bucket bucket
    ```

    As a reminder, there's three different timestamps associated with a file, in the script we use **atime**:

    | Time   | Description                                                                                |   |
    |--------|--------------------------------------------------------------------------------------------|---|
    | ctime  | The last time the file's inode was changed (e.g. permissions changed, file renamed, etc..) |   |
    | mtime  | Last time the file's CONTENTS were changed.                                                |   |
    | atime  | Last time the file was accessed.                                                           |   |

## Monitoring

The script creates a file `/tmp/FSx-Cache-Eviction-log-[date].txt`, you can tail that file to see if it's evicting data from the filesystem:

  ```
  tail -f /tmp/FSx-Cache-Eviction-log-[date].txt
  ```

In addition, you can monitor the size of your filesystem on the [AWS ParallelCluster Metrics Dashboard](https://docs.aws.amazon.com/parallelcluster/latest/ug/cloudwatch-dashboard-v3.html).

  ![FSx Metrics Dashboard](/img/fsx-lustre-cache/fsx-metrics.png)

## Testing

To test this we'll create a bunch of dummy data using [ior](https://github.com/hpc/ior), a filesystem testing tool. We'll then run the cache eviction script and use CloudWatch Metrics to observe the decrease in filesystem size.

1. Install `ior`:

    ```bash
    cd /shared
    wget https://github.com/hpc/ior/releases/download/3.3.0/ior-3.3.0.tar.gz
    tar -xzf ior-3.3.0.tar.gz
    cd ior-3.3.0/
    ./configure
    make
    make install
    ```

2. Run IOR to fill up the filesystem. In this example we write a total of `1.25TB` of data. You can adjust the `-s` flag based on your filesystem size.

    ```bash
    threads=$(($(nproc --all) * 4))
    mpirun --npernode ${threads} --oversubscribe ior -b 1m -c -k -o /shared/ior-data -s 81920 -t 1m -v -w -z
    ```

3. Check the filesystem size. You'll see we just filled up **90%** of the filesystem and now need to evict some files:

    ```bash
    $ df -h /shared
    172.31.21.102@tcp:/ybajnbmv  1.1T  1.0T  1.1T   90% /shared
    ```

4. Run the export script, you can change the `-minage` to `0` so it evicts the large file we just created with `ior`:

    ```bash
    /opt/parallelcluster/shared/cache-eviction.sh -mountpath /shared -mountpoint /shared -minage 0 -minsize 2000 -bucket bucket
    ```

5. Check the filesystem size after the log file `/tmp/FSx-Cache-Eviction-log-[date].txt` shows export complete.

    ```bash
    $ df -h /shared
    172.31.21.102@tcp:/ybajnbmv  1.1T  200GB  1.1T   20% /shared
    ```
