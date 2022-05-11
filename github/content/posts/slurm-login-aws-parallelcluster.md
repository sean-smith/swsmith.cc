---
title: Slurm Login Node with AWS ParallelCluster
description:
date: 2021-12-07
tldr: Create a seperate Slurm login node with AWS ParallelCluster
draft: false
tags: [ec2, aws parallelcluster, hpc, aws, slurm]
---

# Slurm Login Node with AWS ParallelCluster

To seperate the Slurm Scheduler instance from the login node, you can launch a seperate instance and connect it to the cluster. This ensures seperating between what the users might do on the login node and the vital scheduler process. 

1. Launch a new EC2 Instance based on the AWS ParallelCluster AMI, an easy way to do this is to go to the [EC2 Console](https://console.aws.amazon.com/ec2/v2/home), select the head node and click Actions > Image and Templates > "Launch more like this":

![image](https://user-images.githubusercontent.com/5545980/145072364-c225aa4d-e697-4dce-8312-8b110eaba0c4.png)

2. Now edit the Security Group to allow mounting NFS

3. SSH into this instance and Mount NFS

```bash
mkdir -p /opt/slurm
sudo mount -t nfs 172.31.19.195:/opt/slurm /opt/slurm
sudo mount -t nfs 172.31.19.195:/home /home
```

4. Setup [Munge Key](https://slurm.schedmd.com/quickstart_admin.html#communication) to authenticate with the head node.

```bash
sudo su
# Copy munge key from shared dir
cp /home/ec2-user/.munge/.munge.key /etc/munge/munge.key
# Set ownership on the key
chown munge:munge /etc/munge/munge.key
# Enforce correct permission on the key
chmod 0600 /etc/munge/munge.key
systemctl enable munge
systemctl start munge
```

5. Add `SLURM_HOME` and `SLURM_HOME/bin` to your path:

```bash
echo "export SLURM_HOME='/opt/slurm'" >> ~/.bashrc
echo "export PATH=\$SLURM_HOME/bin:\$PATH" >> ~/.bashrc
```

6. Start the Slurm service by creating a systemd file:

```bash
cat <<EOF > /etc/systemd/system/slurmd.service
[Unit]
Description=Slurm node daemon
After=munge.service network.target remote-fs.target
ConditionPathExists=/opt/slurm/etc/slurm.conf

[Service]
Type=simple
EnvironmentFile=-/etc/sysconfig/slurmd
ExecStart=/opt/slurm/sbin/slurmd -D $SLURMD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
LimitNOFILE=131072
LimitMEMLOCK=infinity
LimitSTACK=infinity
Delegate=yes

[Install]
WantedBy=multi-user.target
EOF
```

Now start the service:

```
sudo systemctl enable slurmd.service
sudo systemctl start slurmd.service
```

Now we can submit jobs and see the partitions!
