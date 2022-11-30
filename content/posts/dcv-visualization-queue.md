---
title: DCV Visualization Queue 🖥
description:
date: 2022-11-29
tldr: Launch Graphic Desktops with AWS ParallelCluster. This allows you to run applications such as StarCCM+, shown below, without moving data.
draft: false
og_image: /img/dcv-visualization-queue/starccm.png
tags: [dcv, aws parallelcluster, hpc, aws, slurm, starccm+]
---

![StarCCM+ Visualization](/img/dcv-visualization-queue/starccm.png)

# DCV Visualization Queue

When DCV is enabled, the default behaviour of AWS ParallelCluster is to run a single DCV session on the head node, this is a quick and easy way to visualize the results of your simulations or run a desktop application such as StarCCM+.

A common ask is to run DCV sessions on a compute queue instead of the head node. This has several advantages, namely:
1. Run multiple sessions on the same instance (possibly with different users per-session)
2. Run a smaller head node and only spin up more-expensive DCV instances when needed. We set a 12 hr timer below that automatically kills sessions after we leave.

## Setup

1. Create a security group that allows you to connect to the compute nodes on port `8443`. We'll use this below in the [AdditionalSecurityGroups](https://docs.aws.amazon.com/parallelcluster/latest/ug/Scheduling-v3.html#yaml-Scheduling-SlurmQueues-Networking-AdditionalSecurityGroups) section for that queue.

* Go to [EC2 Security Group Create](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#CreateSecurityGroup:) 
* **Name:** DCV
* Add an Ingress rule, `Custom TCP`, `Port 8443`, `0.0.0.0/0`

![Security Group](/img/dcv-visualization-queue/security-group.png)

2. Create a cluster with a queue `dcv` with instance type `g4dn.xlarge`.

The `g4dn.xlarge` is ideal for our remote desktop use case, it has 1 Nvidia T4, 4	vcpus, and 16 GB memory. Given the number of vcpus, we can start up to 4 sessions on it.

```yaml
Region: us-east-1
Image:
  Os: alinux2
HeadNode:
  InstanceType: t2.micro
  Networking:
    SubnetId: subnet-123456789
  Ssh:
    KeyName: blah
  Iam:
    AdditionalIamPolicies:
      - Policy: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
Scheduling:
  Scheduler: slurm
  SlurmQueues:
    - Name: dcv
      ComputeResources:
        - Name: dcv-g4dnxlarge
          InstanceType: g4dn.xlarge
          MinCount: 0
          MaxCount: 4
      Networking:
        SubnetIds:
          - subnet-123456789
        AdditionalSecurityGroups:
          - sg-031b9cd973e8f62b0 # security group you created above
      Iam:
        AdditionalIamPolicies:
          - Policy: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
        S3Access:
          - BucketName: dcv-license.us-east-2 # needed for license access
```

3. Create a file called `desktop.sbatch` with the following contents:

```bash
#!/bin/bash
#SBATCH -p dcv
#SBATCH -t 12:00:00
#SBATCH -J desktop
#SBATCH -o "%x-%j.out"

# magic command to disable lock screen
dbus-launch gsettings set org.gnome.desktop.session idle-delay 0 > /dev/null
# Set a password
password=$(openssl rand -base64 32)
echo $password | sudo passwd $USER --stdin > /dev/null
# start DCV server and create session
sudo systemctl start dcvserver
dcv create-session $SLURM_JOBID


ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
printf "\e[32mClick the following URL to connect:\e[0m"
printf "\n=> \e[34mhttps://$ip:8443?username=$USER&password=$password\e[0m\n"

while true; do
   sleep 1
done;
```

4. Submit a job:

```bash
sbatch desktop.sbatch # note the job id
```

5. Once the job starts running, check the file `cat desktop-[job-id].out` for connection details:

![DCV URL](/img/dcv-visualization-queue/dcv-url.png)

## No-Ingress DCV

An alternative to the above approach where we opened up the Security Group to allow traffic from port `8443` is to create a Port Forwarding Session with AWS SSM. This allows us to lock down the Security Group and have no ingress.

1. Install [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

2. Submit a job using the following submit script:

```bash
#!/bin/bash
#SBATCH -p desktop
#SBATCH -t 12:00:00
#SBATCH -J desktop
#SBATCH -o "%x-%j.out"

# magic command to disable lock screen
dbus-launch gsettings set org.gnome.desktop.session idle-delay 0 > /dev/null
# Set a password
password=$(openssl rand -base64 32)
echo $password | sudo passwd $USER --stdin > /dev/null
# start DCV server and create session
sudo systemctl start dcvserver
dcv create-session $SLURM_JOBID

instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
printf "\e[32mFor a no-ingress cluster, you'll need to run the following command (on your local machine):\e[0m"
printf "\n=> \e[37m\taws ssm start-session --target $instance_id --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"8443\"],\"localPortNumber\":[\"8443\"]}'\e[0m\n"

printf "\n\n\e[32mThen click the following URL to connect:\e[0m"
printf "\n=> \e[34mhttps://localhost:8443?username=$USER&password=$password\e[0m\n"

while true; do
   sleep 1
done;
```

3. Run the output port forwarding command locally:

![Start SSM Session](/img/dcv-visualization-queue/ssm-start-session.png)

4. Connect to the URL!

## DCV Client

DCV provides a native client for MacOS, Windows and Linux. The client provides a better experience than the web client as it's allowed to use more of the hardware without the browser limiting it.

![DCV Client](/img/dcv-visualization-queue/dcv-client.png)

1. Download the client [here](https://download.nice-dcv.com/).
1. Next create a file a file `desktop.sbatch` with the following content:
2. Change the line `bucket='your-bucket'` to point to a S3 bucket you own.
3. Add permissions to your cluster to access this bucket.

```bash
#!/bin/bash
#SBATCH -p dcv
#SBATCH -t 12:00:00
#SBATCH -J desktop
#SBATCH -o "%x-%j.out"

# magic command to disable lock screen
dbus-launch gsettings set org.gnome.desktop.session idle-delay 0 > /dev/null
# Set a password
password=$(openssl rand -base64 32)
echo $password | sudo passwd $USER --stdin > /dev/null
# start DCV server and create session
sudo systemctl start dcvserver
dcv create-session $SLURM_JOBID

# params
ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
port=8443
bucket='your-bucket'

cat <<EOT > connect-$SLURM_JOB_ID.dcv
[version]
format=1.0

[connect]
host=$ip
port=$port
user=$USER
password=$password
sessionid=$SLURM_JOB_ID
EOT

aws s3 cp connect-$SLURM_JOB_ID.dcv s3://$bucket/
url=$(aws s3 presign s3://$bucket/connect-$SLURM_JOB_ID.dcv)
echo "$url"

printf "Connect using the DCV Client with the following file:\n"
printf "\e[34m=> %s \e[0m\n" "$url"

while true; do
   sleep 1
done;
```

4. Once this runs you'll see output like:

![Connect to DCV Client](/img/dcv-visualization-queue/dcv-thin-client-connect.png)

5. Copy and paste the long url into the browser and you'll download a session file. Double click on the session file to connect via the client.

## Multiple Sessions Per-Instance

By default Slurm will schedule each session on 1 vcpu. This means that our `g4dn.xlarge` instance type can fit 4 sessions:

![Multi-Session](/img/dcv-visualization-queue/multi-session.png)