---
title: Visualize Cluster Statistics with Grafana 📊
description:
date: 2023-08-02
tldr: Using Slurm Prometheus Exporter and Grafana you can setup custom dashboards to monitor your Slurm cluster
draft: true
og_image: /img/grafana/grafana.png
tags: [grafana, slurm, aws]
---

![Grafana Screenshot](/img/grafana/grafana.png)

Grafana is an open source tool that allows us to create dashboards and monitor the cluster. In the following guide we'll show you how to setup prometheus Slurm exporter and Grafana to monitor a cluster. This will help you answer questions like:

* how many jobs are running
* instance utilization
* number of instances running

## Setup a Security Group to access Grafana

To access the Grafana portal you'll need to either create a security group or have users setup [SSM Port Forwarding](https://aws.amazon.com/blogs/aws/new-port-forwarding-using-aws-system-manager-sessions-manager/) and run a command locally.

**Option 1: Security Group**

1. First [create a security group](https://console.aws.amazon.com/ec2/home?#CreateSecurityGroup:) that allows you to access port `3000` from the HeadNode. For test purposes I used `0.0.0.0/0` but I highly recommend you restrict this CIDR range to your corporate network or use port forwarding.

  ![Security Group Setup](/img/grafana/security-group.png)

**Option 2: SSM Port Forwarding**

1. To use Port Forwarding the HeadNode will need to have the `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore` policy added to the instance profile. Then you can do:

  ```bash
  INSTANCE=i-1234567890
  REGION=us-east-1
  aws ssm start-session --target $INSTANCE_ID \
      --document-name AWS-StartPortForwardingSession \
      --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}' \
      --region $REGION
  ```

2. Then connect to `http://localhost:3000` instead of the HeadNode's ip address when you setup Grafana below.

## Setup Prometheus

1. Install Prometheus from the [latest version](https://prometheus.io/download/) on Github.

```bash
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.46.0/prometheus-2.46.0.linux-amd64.tar.gz
tar -xvf prometheus-*.linux-amd64.tar.gz
cd prometheus-*.linux-amd64
sudo mv prometheus promtool /usr/local/bin/
sudo mv consoles/ console_libraries/ /etc/prometheus/
sudo mv prometheus.yml /etc/prometheus/prometheus.yml
```

2. Check to see `prometheus` and `promtool` are running:

```
$ prometheus --version
prometheus, version 2.46.0 (branch: HEAD, revision: cbb69e51423565ec40f46e74f4ff2dbb3b7fb4f0)
  build user:       root@42454fc0f41e
  build date:       20230725-12:31:24
  go version:       go1.20.6
  platform:         linux/amd64
  tags:             netgo,builtinassets,stringlabels
$ promtool --version
promtool, version 2.46.0 (branch: HEAD, revision: cbb69e51423565ec40f46e74f4ff2dbb3b7fb4f0)
  build user:       root@42454fc0f41e
  build date:       20230725-12:31:24
  go version:       go1.20.6
  platform:         linux/amd64
  tags:             netgo,builtinassets,stringlabels
```

3. Add the `prometheus` user to the HeadNode and start the

```
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus
sudo chmod -R 775 /etc/prometheus/ /var/lib/prometheus/
```

3. Start the prometheus service:

```
sudo vim /etc/systemd/system/prometheus.service
sudo systemctl start prometheus
sudo systemctl enable prometheus
```

## Setup Slurm Prometheus Exporter

1. Install [go](https://go.dev/) following instructions for your specific OS, instructions for `Ubuntu 20.04` are below:

  ```bash
  curl -OL https://golang.org/dl/go1.16.7.linux-amd64.tar.gz
  sudo tar -C /usr/local -xvf go1.16.7.linux-amd64.tar.gz
  echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
  ```

2. Install [Slurm Prometheus Exporter](https://github.com/vpenso/prometheus-slurm-exporter)

  ```bash
  git clone https://github.com/vpenso/prometheus-slurm-exporter.git
  cd prometheus-slurm-exporter/
  make
  sudo su
  cp bin/prometheus-slurm-exporter /usr/bin/
  mv lib/systemd/prometheus-slurm-exporter.service /etc/systemd/system
  ```

3. Start prometheus exporter service

  ```bash
  sudo systemctl start prometheus-slurm-exporter.service

  # check on the status
  systemctl status prometheus-slurm-exporter.service
  ```

You'll see it running:

  ```
  ● prometheus-slurm-exporter.service - Prometheus SLURM Exporter
    Loaded: loaded (/etc/systemd/system/prometheus-slurm-exporter.service; disabled; vendor preset: disabled)
    Active: active (running) since Wed 2023-04-12 05:18:41 UTC; 8s ago
  Main PID: 1450 (prometheus-slur)
    CGroup: /system.slice/prometheus-slurm-exporter.service
            └─1450 /usr/bin/prometheus-slurm-exporter

  Apr 12 05:18:41 ip-172-31-44-81 systemd[1]: Started Prometheus SLURM Exporter.
  Apr 12 05:18:41 ip-172-31-44-81 prometheus-slurm-exporter[1450]: time="2023-04-12T05:18:41Z" level=info msg="Starting S...:59"
  Apr 12 05:18:41 ip-172-31-44-81 prometheus-slurm-exporter[1450]: time="2023-04-12T05:18:41Z" level=info msg="GPUs Accou...:60"
  Hint: Some lines were ellipsized, use -l to show in full.
  ```

## Install Grafana:

```ini
sudo cat <<EOF > print.sh
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
```

```bash
sudo yum install grafana
```

```bash
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl status grafana-server
```

Now you can login! Switch `3.134.78.130` for the public ip of the HeadNode or use `localhost` if using SSM Port Forwarding.

http://3.134.78.130:3000/login

```
username: admin
password: admin
```

This will prompt you to change your password to a more reasonable password.

Next we'll import the following dashboard:
https://grafana.com/grafana/dashboards/4323-slurm-dashboard/



## Import default Slurm Dashboard

1. In Grafana go to dashboards > Import > Enter `4232` for the dashboard id and select Prometheus as the datasource:

![]()

## Docker Prometheus + Slurm Exporter

1. Install Docker using the following [postinstall.sh](https://github.com/aws-samples/aws-parallelcluster-post-install-scripts/blob/main/docker/postinstall.sh)

```bash
wget https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/docker/postinstall.sh
sudo bash postinstall.sh
```

1. Clone the [prometheus-slurm-exporter](https://github.com/dholt/prometheus-slurm-exporter.git) repo from Github and build the container image: 

```bash
git clone https://github.com/dholt/prometheus-slurm-exporter.git
cd prometheus-slurm-exporter/
docker build -t prometheus-slurm-exporter prometheus
```

3. Test to see if the docker container runs locally:

```bash
docker run -d -v /usr/bin/sdiag:/usr/bin/sdiag -v /usr/bin/sinfo:/usr/bin/sinfo -v /usr/bin/squeue:/usr/bin/squeue -v /etc/slurm:/etc/slurm:ro -v /usr/lib/slurm:/usr/lib/slurm:ro -v /etc/hosts:/etc/hosts:ro -v /var/run/munge:/var/run/munge:ro -p 8080:8080 --name prometheus-slurm-exporter prometheus-slurm-exporter
```

4. Create a `systemctl` file and enable the serviceL: 

```
sudo mv prometheus-slurm-exporter.service /etc/systemd/system
sudo systemctl start prometheus-slurm-exporter
sudo systemctl enable prometheus-slurm-exporter
```

5. Check on the status of `prometheus-slurm-exporter`

```
[ec2-user@ip-172-31-19-83 prometheus-slurm-exporter]$ sudo systemctl status prometheus-slurm-exporter
● prometheus-slurm-exporter.service - Prometheus Slurm Exporter
   Loaded: loaded (/etc/systemd/system/prometheus-slurm-exporter.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2023-07-28 20:38:52 UTC; 7s ago
  Process: 30657 ExecStartPre=/usr/bin/docker pull dholt/prometheus-slurm-exporter (code=exited, status=0/SUCCESS)
  Process: 30643 ExecStartPre=/usr/bin/docker rm prometheus-slurm-exporter (code=exited, status=0/SUCCESS)
  Process: 30587 ExecStartPre=/usr/bin/docker stop prometheus-slurm-exporter (code=exited, status=0/SUCCESS)
 Main PID: 30679 (docker)
    Tasks: 10
   Memory: 10.6M
   CGroup: /system.slice/prometheus-slurm-exporter.service
           └─30679 /usr/bin/docker run --rm -v /usr/bin/sdiag:/usr/bin/sdiag -v /usr/bin/sinfo:/usr/bin/sinfo -v /usr/bin/sq...
```

```
sudo docker-compose up -d
```