---
title: Email Notifications with AWS ParallelCluster ✉️
description:
date: 2022-12-07
tldr: Receive an email when your slurm job completes
draft: true
og_image: 
tags: [aws parallelcluster, slurm, aws]
---

Slurm has an option to send emails when your job changes status. This is useful to get notifications when your job completes. For example in my sbatch script I could add:

```bash
#SBATCH --mail-user=user@email.com
```

After the job completes, you'll get an email:

## Setup

1. Setup a SMTP server in [Amazon Simple Email Service (SES)]()



2. Install and configure exim

```bash
sudo yum install -y exim
sudo vim /etc/exim/exim.conf # edit file following https://docs.aws.amazon.com/ses/latest/dg/send-email-exim.html
sudo systemctl restart exim
```

3. Test

```bash
exim -v seanwssmith@gmail.com
From: recipient@example.com
Subject: test

Hi this is Sean!

Ctrl-D
```

4. Configure Slurm

```bash
cat << EOF >> /opt/slurm/etc/slurm.conf
#
# EMAIL NOTIFICATIONS
#
MailProg=/usr/bin/mail
MailDomain=example.com
MailType=USER
EOF
```