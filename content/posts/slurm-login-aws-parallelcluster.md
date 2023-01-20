---
title: Slurm Login Node with AWS ParallelCluster 🖥
description:
date: 2022-11-10
tldr: Create a seperate Slurm login node with AWS ParallelCluster
draft: false
og_image: /img/slurm-login/architecture.png
tags: [ec2, aws parallelcluster, hpc, aws, slurm]
---

**Update:** This has been written up on the ParallelCluster Wiki: [ParallelCluster: Launching a Login Node](https://github.com/aws/aws-parallelcluster/wiki/ParallelCluster:-Launching-a-Login-Node)

![Architecture Diagram](/img/slurm-login/architecture.png)

To seperate the Slurm Scheduler instance from the login node, you can launch a seperate instance and connect it to the cluster. This ensures seperating between what the users might do on the login node and the vital scheduler process.

## Setup

1. Launch a new EC2 Instance based on the AWS ParallelCluster AMI, an easy way to do this is to go to the [EC2 Console](https://console.aws.amazon.com/ec2/v2/home), select the head node and click Actions > Image and Templates > "Launch more like this":

    ![Slurm Login Node](/img/slurm-login/ec2-clone.png)

2. Now edit the Security Group of the old HeadNode to allow traffic from the Login Node. Add a route for all traffic with the source `[cluster_name]-HeadNodeSecurityGroup`.

    | Type        | Source                               | Description               |
    |-------------|--------------------------------------|---------------------------|
    | All Traffic | `[cluster-name]-HeadNodeSecurityGroup` | Allow traffic to HeadNode |

3. SSH into this instance and Mount NFS from the HeadNode (where `172.31.19.195` is the HeadNode ip).

    ```bash
    mkdir -p /opt/slurm
    sudo mount -t nfs 172.31.19.195:/opt/slurm /opt/slurm
    sudo mount -t nfs 172.31.19.195:/home /home
    ```

4. Setup [Munge Key](https://slurm.schedmd.com/quickstart_admin.html#communication) to authenticate with the head node:

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

```bash
sudo systemctl enable slurmd.service
sudo systemctl start slurmd.service
```

Now we can submit jobs and see the partitions!

## Packer 📦

1. First install [packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli), on mac / linux you can use `brew`:

    ```bash
    brew install packer
    ```

2. Download the files [pc-login-node.json](https://swsmith.cc/scripts/pc-login-node.json) and [login-node.sh](https://swsmith.cc/scripts/login-node.sh):

    ```bash
    wget https://swsmith.cc/scripts/login-node.sh
    wget https://swsmith.cc/scripts/pc-login-node.json
    ```

3. Run the bach script `login-node.sh` and input your **cluster's name** when prompted. This will generate a file `variables.json` with all the relevant cluster information:

    ```bash
    bash login-node.sh 
    ```

4. Run Packer:

    ```bash
    packer build -color=true -var-file variables.json pc-login-node.json
    ```

5. That'll produce an AMI that we can launch in the same AZ as the HeadNode:

    ```bash
    bash launch-loginnode.sh 
    ```
