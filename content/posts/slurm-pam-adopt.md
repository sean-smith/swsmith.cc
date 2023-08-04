---
title: Slurm PAM Adopt 👨‍👨‍👦
description:
date: 2023-08-04
tldr: Slurm restrict user login to only nodes with running jobs
draft: true
og_image: 
tags: [slurm, aws, pam]
---

[Slurm PAM adopt](https://slurm.schedmd.com/pam_slurm_adopt.html) allows you to restrict users to login to **only to** instances where they have running jobs. This allows you to prevent them from messing with other users jobs. 

Now there is some nuance to this, for example should they be allowed to ssh into a node they're only partially using? Luckily this is a configurable module so you can make these decisions yourself by setting one of the following options:

| **flag**               | **value**           | **Description**                                                     |
|------------------------|---------------------|---------------------------------------------------------------------|
| action_no_jobs         | ignore\|deny        | ignore this check if not jobs are found                             |
| action_unknown         | newest\|allow\|deny | if the user has multiple jobs, allow them on newest, allow or deny. |
| action_adopt_failure   | allow\|deny         | if the user fails the previous two check, let them in?              |
| action_generic_failure | ignore\|allow\|deny | catch all for any other failure. used for debugging.                |
| disable_x11            | 0\|1                | disable x11 sessions                                                |
| join_container         | true\|false         | job the container when a job is run with `job_container/tmpfs`      |


## Setup

1. Either clone and configure or navigate to the folder with the Slurm source, this is where we'll compile the pam adopt module:

```bash
git clone https://github.com/SchedMD/slurm.git
cd slurm/
./configure --prefix=/opt/slurm --with-pmix=/opt/pmix --with-jwt=/opt/libjwt --enable-slurmrestd
cd contribs/pam_slurm_adopt/
make
sudo make install
```

2. Next enable it in the `/etc/pam.d/system-auth` file:

```bash
sudo su
echo "-account    required      pam_slurm_adopt.so" >> vim /etc/pam.d/system-auth
```

3. Next enable the prolog flag in `slurm.conf`:

```bash
echo "PrologFlags=contain" >> /opt/slurm/etc/slurm.conf
```

4. Enable the task plugin for `task/cgroup`:

```bash
echo "TaskPlugin=task/cgroup" >> /opt/slurm/etc/slurm.conf
```

6. Verify that PAM is enabled:

```bash
cat /etc/ssh/sshd_config | grep "UsePAM"
UsePAM yes
```

7. Voila! now submit a job as one user, switch to another user and try to login to that node.