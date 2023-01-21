---
title: Slurm Login Node with AWS ParallelCluster 🖥
description:
date: 2023-01-20
tldr: Create a seperate Slurm login node with AWS ParallelCluster
draft: false
og_image: /img/slurm-login/architecture.png
tags: [ec2, aws parallelcluster, hpc, aws, slurm]
---

**Update:** This has been written up on the ParallelCluster Wiki: [ParallelCluster: Launching a Login Node](https://github.com/aws/aws-parallelcluster/wiki/ParallelCluster:-Launching-a-Login-Node)

![Architecture Diagram](/img/slurm-login/architecture.png)

Some reasons why you may want to use a Login Node:

* Separation of scheduler `slurmctld` process from users. This helps prevent a case where a user consumes all the system resources and Slurm can no longer function.
* Ability to set different IAM permissions for Login versus Head Node.

I've divided the setup into two parts:

1. [Create a Login Node manually](#setup)
2. [Automate Login Node creation with packer](#packer-)

I highly advise starting the manual approach before moving to the more automated packer setup.

## Setup

1. Launch a new EC2 Instance based on the AWS ParallelCluster AMI, an easy way to do this is to go to the [EC2 Console](https://console.aws.amazon.com/ec2/v2/home), select the head node and click Actions > Image and Templates > "Launch more like this":

    ![Slurm Login Node](/img/slurm-login/ec2-clone.png)

2. Now edit the Security Group of the old HeadNode to allow ingress traffic from the Login Node. Add a route for all traffic with the source `[cluster_name]-HeadNodeSecurityGroup`.

    | Type        | Source                               | Description               |
    |-------------|--------------------------------------|---------------------------|
    | All Traffic | `[cluster-name]-HeadNodeSecurityGroup` | Allow traffic to HeadNode |

3. SSH into this instance and Mount NFS from the HeadNode **private ip** (where `172.31.19.195` is the HeadNode ip). Note this must be the private ip, if you use the public ip this will time out.

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

5. Add `/opt/slurm/bin` to your `PATH`:

    ```bash
    sudo su
    cat > /etc/profile.d/slurm.sh << EOF
    PATH=\$PATH:/opt/slurm/bin
    MANPATH=\$MANPATH:/opt/slurm/share/man
    EOF
    exit
    source /etc/profile.d/slurm.sh
    ```

6. Now you can run Slurm commands such as `sinfo`:

    ```bash
    $ sinfo
    PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
    hpc6a*       up   infinite     64  idle~ hpc6a-dy-hpc6a-hpc6a48xlarge-[1-64]
    c6i          up   infinite      6  idle~ c6i-dy-c6i-c6i32xlarge-[1-6]
    hpc6id       up   infinite     64  idle~ hpc6id-dy-hpc6id-hpc6id32xlarge-[1-64]
    ```

Now we can submit jobs and see the partitions!

## Packer 📦

I've also put together a script to automate these steps with packer.

1. First edit the Security Group of the HeadNode to allow ingress traffic from the Login Node. Add a route for all traffic with the source `[cluster_name]-HeadNodeSecurityGroup`. This is essentially a circular route, since both are going to share the same Security Group traffic can flow between them.

    | Type        | Source                               | Description               |
    |-------------|--------------------------------------|---------------------------|
    | All Traffic | `[cluster-name]-HeadNodeSecurityGroup` | Allow traffic to HeadNode |

2. First install [packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli), on mac / linux you can use `brew`:

    ```bash
    brew install packer
    ```

3. Download the files [configure.sh](https://swsmith.cc/scripts/login-node/configure.sh), [packer.json](https://swsmith.cc/scripts/login-node/packer.json) and [launch.sh](https://swsmith.cc/scripts/login-node/launch.sh):

    ```bash
    wget https://swsmith.cc/scripts/login-node/configure.sh
    wget https://swsmith.cc/scripts/login-node/packer.json
    wget https://swsmith.cc/scripts/login-node/launch.sh
    ```

4. Run the bash script `configure.sh` and input your **cluster's name** when prompted. This will generate a file `variables.json` with all the relevant cluster information:

    ```bash
    bash configure.sh
    ```

    ![Packer Script](/img/slurm-login/login-node-script.png)

5. Run Packer:

    ```bash
    packer build -color=true -var-file variables.json packer.json
    ```

6. That'll produce an AMI that we can launch using the `launch.sh` script:

    ```bash
    bash launch.sh
    ```

    Now you'll see a new node under the [Cluster Name] > Instances tab in ParallelCluster:

    ![ParallelCluster Manager Login Node](/img/slurm-login/pcm-login-node.png)

    You can ssh in using the **Public IP** address.