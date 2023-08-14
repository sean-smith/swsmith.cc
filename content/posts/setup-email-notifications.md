---
title: Email Notifications with Slurm ✉️
description:
date: 2023-08-13
tldr: Receive an email when your Slurm job completes.
draft: false
og_image: 
tags: [aws parallelcluster, slurm, aws]
---

Slurm has an option to send emails when your job changes status. This is useful to get notifications when your job completes. For example in my sbatch script I could add:

```bash
#SBATCH --mail-user=sean@swsmith.cc
```

After the job completes, you'll get an email:

![Email Notification](/img/slurm-email/email.png)

You can include useful information such as stdout, stderr, runtime ect. For a full list of options, see [Customizing Emails](https://github.com/neilmunday/slurm-mail#customising-e-mails).

In the following section we'll setup Amazon SES, a fully managed email server, and then configure Slurm to send emails using that SES server.

## Setup

1. Setup a SMTP server in [Amazon Simple Email Service (SES)](https://aws.amazon.com/ses/).

2. Install and configure the excellent [Slurm Mail](https://github.com/neilmunday/slurm-mail) plugin by [@neilmunday](https://github.com/neilmunday):

    ```bash
    git clone https://github.com/neilmunday/slurm-mail
    cd slurm-mail/
    pip install pathlib
    sudo python3 setup.py install
    sudo cp etc/logrotate.d/slurm-mail /etc/logrotate.d/
    sudo cp etc/cron.d/slurm-mail /etc/cron.d/
    sudo install -d -m 700 -o slurm -g slurm /var/log/slurm-mail
    ```

    **OR**

    ```
    wget https://github.com/neilmunday/slurm-mail/releases/download/v4.5/slurm-mail-4.5-1.el7.noarch.rpm
    sudo yum localinstall ./slurm-mail-4.5-1.el7.noarch.rpm
    ```

3. Next edit the file `/etc/slurm-mail/slurm-mail.conf`:

    ```bash
    $ sudo vim /etc/slurm-mail/slurm-mail.conf
    sacctExe = /opt/slurm/bin/sacct
    scontrolExe = /opt/slurm/bin/scontrol
    smtpServer = email-smtp.us-east-2.amazonaws.com
    smtpPort = 25
    smtpUseTls = yes
    smtpUseSsl = no
    smtpUserName = AKLA37FRA2PGDZ5NPGER
    smtpPassword = BIt2/r5iWwnCXjD+B8uW4wDTLV84yw8vSDfcFOBYkkqt
    ```

    Change the following parameters:

    | **Parameter** | **Value**                                    | **Description**                                                                                 |
    |---------------|----------------------------------------------|-------------------------------------------------------------------------------------------------|
    | sacctExe      | `/opt/slurm/bin/sacct`                       | use `which sacct` to get the full path. In AWS ParallelCluster use `/opt/slurm/bin/sacct`       |
    | scontrolExe   | `/opt/slurm/bin/scontrol`                    | use `which scontrol` to get the full path. In AWS ParallelCluster use `/opt/slurm/bin/scontrol` |
    | smtpServer    | `email-smtp.us-east-2.amazonaws.com`         | Mail server endpoint changes by region.                                                         |
    | smtpPort      | `587`                                        | Port 587 is what worked for me, if you need to use another port see SES Console.                           |
    | smtpUseTls    | yes                                          | Must enforce TLS otherwise SES will reject it.                                                  |
    | smtpUserName  | AKLA37FRA2PGDZ5NPGMR                         | Get this value from the SES Console.                                                            |
    | smtpPassword  | BIt2/r5iWwnCXjD+B8uW4wDTLV84yw8vSDdcFOBYkkqt | Get this value from the SES Console.                                                            |

4. Configure Slurm and restart the controller.

    ```bash
    sudo su
    echo "MailProg=/usr/bin/slurm-spool-mail" >> /opt/slurm/etc/slurm.conf
    systemctl restart slurmctld
    ```

## Test

Create a test job with the following flags and submit it:

```bash
#!/bin/bash
#SBATCH --mail-user=sean@swsmith.cc
#SBATCH --mail-type=ALL

echo "hello world!"
```

## Troubleshooting

If the email doesn't arrive, check the `/var/log/slurmctld.log` file to see if there's any error messages. For example if the default version of python is 2.7, you'll see the following error message in your `slurmctld.log` log:

```
[2023-08-13T18:22:06.263] _job_complete: JobId=14 WEXITSTATUS 0
[2023-08-13T18:22:06.263] _job_complete: JobId=14 done
[2023-08-13T18:22:06.447] slurmscriptd: error: _run_script: JobId=0 MailProg exit status 1:0
[2023-08-13T18:22:06.447] error: MailProg returned error, it's output was 'Traceback (most recent call last):
  File "/usr/bin/slurm-spool-mail", line 11, in <module>
    load_entry_point('slurmmail==4.5', 'console_scripts', 'slurm-spool-mail')()
  File "/usr/lib/python2.7/site-packages/pkg_resources/__init__.py", line 489, in load_entry_point
    return get_distribution(dist).load_entry_point(group, name)
  File "/usr/lib/python2.7/site-packages/pkg_resources/__init__.py", line 2852, in load_entry_point
    return ep.load()
  File "/usr/lib/python2.7/site-packages/pkg_resources/__init__.py", line 2443, in load
    return self.resolve()
  File "/usr/lib/python2.7/site-packages/pkg_resources/__init__.py", line 2449, in resolve
    module = __import__(self.module_name, fromlist=['__name__'], level=0)
  File "/usr/lib/python2.7/site-packages/slurmmail-4.5-py2.7.egg/slurmmail/cli.py", line 78
    self.array_max_notifications: int
                                ^
SyntaxError: invalid syntax
```

You can also check the logfiles `/var/log/slurm-mail/slurm-send-mail.log` and `/var/log/slurm-mail/slurm-spool-mail.log`.
