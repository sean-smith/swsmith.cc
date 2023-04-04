---
title: Visualize Job Metrics with ElasticSearch
description:
date: 2022-11-08
tldr: Using Slurm and ElasticSearch you can setup custom dashboards for AWS ParallelCluster
draft: true
og_image: 
tags: [aws parallelcluster, opensearch, slurm, aws]
---

In this blogpost we describe a way to visualize job statistics from ElasticSearch and Kibana. This is based on the [ElasticSearch](https://slurm.schedmd.com/elasticsearch.html) plugin in the Slurm documentation and uses the AWS Managed Elastic Search (now called OpenSearch).

![]()

## Setup ElasticSearch

First we'll setup ElasticSearch + Kibana in the [AWS Opensearch Console](https://console.aws.amazon.com/esv3/home?#opensearch/dashboard).

    1. Click "Create domain"
    1. Set a name like "hpc-cluster"
    1. Select ElasticSearch+Kibana (`7.10` or newer)

## Connect to Slurm Cluster

1. Modify Slurm Config file on the cluster:

    ```bash
    sudo su -
    cat <<EOF >> /opt/slurm/etc/slurm_parallelcluster.conf
    JobCompType=jobcomp/elasticsearch
    JobCompLoc=https://search-hpc-klwje5w2d5zdtlu5qiomsvo46u.us-east-2.es.amazonaws.com
    DebugFlags=Elasticsearch
    EOF
    ```

2. Restart Slurm for the changes to take effect:

    ```bash
    sudo systemctl restart slurmctld
    ```

2. Next we're going to test that the cluster can indeed call the ElasticSearch endpoint:

    ```bash
    curl -XGET https://search-hpc-klwje5w2d5zdtlu5qiomsvo46u.us-east-2.es.amazonaws.com/_cat/indices/slurm?v
    ```

3. View job data in the AWS console

Next navigate to the 