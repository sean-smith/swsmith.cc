---
title: Slurm PAM Adopt 👨‍👨‍👦
description:
date: 2023-08-04
tldr: Slurm restrict user login to only nodes with running jobs
draft: false
og_image: 
tags: [slurm, aws, pam]
---

[Slurm PAM "adopt"](https://slurm.schedmd.com/pam_slurm_adopt.html) allows you to restrict users to login to **only to** compute nodes where they have running jobs. It "adopts" the process that the user is running on the node in order to login. If they don't have a job running they'll get permission denied.

There is some nuance to this, for example should users be allowed to ssh into a node they're only partially using? This behavior can be configured with [Options](#options) in the command.

In the next section we'll setup Slurm PAM Adopt:

## Setup

1. Either clone and configure or navigate to the folder with the Slurm source, this might be `/opt/slurm` or `/admin/slurm/22.05.5`, this is where we'll compile the pam adopt module. Make sure the version of slurm corresponds to the version installed on the system i.e. `squeue --version` should match the `SLURM_VERSION` environment variable. You can find the slurm version tags [here](https://github.com/SchedMD/slurm/tags).

    ```bash
    SLURM_VERSION=slurm-23-02-4-1
    git clone -b ${SLURM_VERSION} https://github.com/SchedMD/slurm.git
    cd slurm/
    ./configure --prefix=/opt/slurm --with-pmix=/opt/pmix --with-jwt=/opt/libjwt --enable-slurmrestd
    cd contribs/pam_slurm_adopt/
    make
    sudo make install
    ```

2. Next enable it in the `/etc/pam.d/system-auth` file:

    ```bash
    sudo su
    echo "-account required http://pam_slurm_adopt.so " >> /etc/pam.d/system-auth
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

7. Voila! now submit a job as one user, switch to another user and try to login to that node. You should see "Permission Denied".

## Options

There's a few configuration flags that can be set to configure the behavior of `pam_slurm_adopt`, such as:

| **flag**               | **value**           | **Description**                                                     |
|------------------------|---------------------|---------------------------------------------------------------------|
| action_no_jobs         | ignore\|deny        | ignore this check if no jobs are found                             |
| action_unknown         | newest\|allow\|deny | if the user has multiple jobs, allow them on the basis of newest, allow, or deny. |
| action_adopt_failure   | allow\|deny         | if the user fails the previous two check, let them in?              |
| action_generic_failure | ignore\|allow\|deny | catch all for any other failure. used for debugging.                |
| disable_x11            | 0\|1                | disable x11 sessions                                                |
| join_container         | true\|false         | job the container when a job is run with `job_container/tmpfs`      |

List these options after `pam_slurm_adopt.so` in `/etc/pam.d/system-auth` like so:

```bash
-account    required      pam_slurm_adopt.so    action_no_jobs=ignore   action_unknown=allow    action_adopt_failure=allow ...
```
