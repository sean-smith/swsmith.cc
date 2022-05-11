---
title: Ansys LSTC License Manager for LS-Dyna
description:
date: 2021-04-02
tldr: Setup Ansys LSTC License Manager for LS-Dyna
draft: false
tags: [LS-Dyna, aws parallelcluster, SOCA, Ansys]
---

# LSTC License Manager

Instructions on how to download and setup the LS-Dyna License server from Ansys. Make sure you have the login credentials to the FTP site, i.e. you can access: https://ftp.lstc.com/user/license/License-Manager/LSTC_LicenseManager-InstallationGuide.pdf. If you don't, [contact Ansys](https://www.ansys.com/contact-us).

> Note: In this guide I’m going to assume SOCA but the same principles apply for AWS ParallelCluster

1. Launch a t2.micro instance in the same VPC as the SOCA cluster
    1. Create it with it’s own security group, call it **license server**
    2. We’re going to open up that SG to up to Master and Compute SG’s of the cluster like so:
    3. ![image](https://user-images.githubusercontent.com/5545980/113461293-d3279780-93d0-11eb-8a38-16df67008679.png)
2. Now grab the MAC address from ifconfig and use it to 
3. Next we’re going to download and run the LSTC license server:
```
$ mkdir lstc_server && cd lstc_server 
$ wget https://ftp.lstc.com/user/license/Job-License-Manager/LSTC_LicenseManager_111345_xeon64_redhat50.
tgz --user [username] --password [password]
$ tar -xzf LSTC_LicenseManager_111345_xeon64_redhat50.tgz
```
1. Now we’re going to generate the server info to send to LSTC/Ansys. Edit the top 4 lines, as well as the IP ranges:
```
[ec2-user@ip-10-0-0-30 lstc]$ ./lstc_server info
Getting server information ...

The hostid and other server information has been written to LSTC_SERVER_INFO.
Please contact LSTC with this information to obtain a valid network license
[ec2-user@ip-10-0-0-30 lstc]$ vim LSTC_SERVER_INFO
AWS PoC
    EMAIL: seaam@amazon.com
      FAX: NONE
TELEPHONE: NONE
...
ALLOW_RANGE:  10.000.000.000 10.000.255.255
```
1. Email LSTC the LSTC_SERVER_INFO file, they’ll get back to you with a server_data file. Put this in the same directory then start the server:
```
scp server_data ec2-user@10.0.0.30:~
./lstc_server -l logfile.log
```
1. Once the server is started, you can check to make sure it’s running:
```
$ less logfile.log
LSTC License server version XXXXXX started...
Using configuration file 'server_data'
```
1. You can check the license by running:
```
[ec2-user@ip-10-0-0-30 lstc]$ ./lstc_qrun -s localhost -r
Using user specified server 0@localhost

LICENSE INFORMATION

PROGRAM          EXPIRATION CPUS  USED   FREE    MAX | QUEUE
---------------- ----------      ----- ------ ------ | -----
MPPDYNA          04/05/2021        384    216    600 |     0
MPPDYNA_971      04/05/2021          0    216    600 |     0
MPPDYNA_970      04/05/2021          0    216    600 |     0
MPPDYNA_960      04/05/2021          0    216    600 |     0
LS-DYNA          04/05/2021          0    216    600 |     0
LS-DYNA_971      04/05/2021          0    216    600 |     0
LS-DYNA_970      04/05/2021          0    216    600 |     0
LS-DYNA_960      04/05/2021          0    216    600 |     0
                   LICENSE GROUP   384    216    600 |     0
```
