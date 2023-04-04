---
title: Visualize Cluster Statistics with Grafana
description:
date: 2022-11-08
tldr: Using Slurm and ElasticSearch you can setup custom dashboards for AWS ParallelCluster
draft: true
og_image: 
tags: [aws parallelcluster, opensearch, slurm, aws]
---


1. Setup Prometheus on the Cluster

```bash
sudo systemctl start prometheus-slurm-exporter.service
```
