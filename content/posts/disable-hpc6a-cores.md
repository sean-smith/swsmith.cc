---
title: How to disable hpc6a.48xlarge cores
description:
date: 2022-05-09
tldr: Disable cores on hpc6a instances in order to speedup performance of certain applications.
draft: false
tags: [ec2, hpc6a.48xlarge, aws parallelcluster, hpc, aws]
---

# How to disable hpc6a.48xlarge cores

Due to the EPYC architecture, it makes more sense to disable specific cores rather than let the scheduler choose which cores to run on. This is because each ZEN 3 core is attached to a compute complex that's made up of 4 cores, L2 and L3 cache, by disabling 1, 2 or 3 cores from the same compute complex, we increase the memory bandwidth of the remaining cores.

![compute-complex](https://user-images.githubusercontent.com/5545980/165413574-7a56725c-b016-4ab6-af47-29a8e974c34f.png)


To do this, you can run the attached `disable-cores.sh` script on each instance:

```bash
./disable-cores --instance hpc6a.48xlarge --cores 72 # cores to disable i.e. use 24 / 96 cores
```

This can be done in Slurm or PBS submissions script using mpi to script it across all the instances:

**Intel MPI**

```bash
# this runs once on 72 instances:
mpirun -n 72 -ppn 1 ./disable-cores -i hpc6a.48xlarge -c 72
```

## disable-cores.sh

```bash
#!/bin/bash

usage() { echo "Usage: $0 [-i <instance-type>] [-c <num-cores-to-disable>]" 1>&2; exit 1; }

options=$(getopt -o c:i: --long cores:,instance: -- "$@")
   [ $? -eq 0 ] || {
        echo "Incorrect option provided"
        exit 1
    }
eval set -- "$options"

while true; do
    case "$1" in
        -i | --instance)
            i=${2};shift 2;;
        -c | --cores)
            c=${2};shift 2;;
      --) shift; break;;
        *)  echo "Unexpected option: $1"
            usage ;;
    esac
done

if [ -z "${i}" ] || [ -z "${c}" ]; then
    usage
fi

arch=${i} #Instance Type
cores=${c} #Number of cores to disable per instance

if [ ${arch} == "c6i.32xlarge" ]  || [ ${arch} == "m6i.32xlarge" ]; then

	if [ ${cores} == "16" ]; then
        	echo "Running with 75% cores"
        	#48C per instance#
        	for cpunum in {24..31} {56..63}
        	do
               	echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
        	done

	elif [ ${cores} == "32" ];then
        	echo "Running with 50% cores"
        	#32C per instance#
        	for cpunum in {16..31} {48..63}
        	do
               	echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
        	done
	else
		echo "Invalid cores option for $arch. This script allows to disable 16 or 32 cores per $arch instance"
	fi

elif [ ${arch} == 'hpc6a.48xlarge' ]; then
	if [ ${cores} == "24" ]; then
        	echo "Running with 75% cores"
        	#72C per instance#
        	for cpunum in {3,7,11,15,19,23,27,31,35,39,43,47,51,55,59,63,67,71,75,79,83,87,91,95}
        	do
               	echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
        	done
	elif [ ${cores} == "48" ];then
        	echo "Running with 50% cores"
        	#48C per instance#
        	for cpunum in {2,3,6,7,10,11,14,15,18,19,22,23,26,27,30,31,34,35,38,39,42,43,46,47,50,51,54,55,58,59,62,63,66,67,70,71,74,75,78,79,82,83,86,87,90,91,94,95}
        	do
               	echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
        	done
	elif [ ${cores} == "72" ];then
        	echo "Running with 25% cores"
        	#24C per hpc6a instance#
        	for cpunum in {1,2,3,5,6,7,9,10,11,13,14,15,17,18,19,21,22,23,25,26,27,29,30,31,33,34,35,37,38,39,41,42,43,45,46,47,49,50,51,53,54,55,57,58,59,61,62,63,65,66,67,69,70,71,73,74,75,77,78,79,81,82,83,85,86,87,89,90,91,93,94,95}
        	do
                echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
        	done

	else
		echo "Invalid cores option for $arch. This script allows to disable 24, 48  or 72 cores per $arch instance"
	fi

elif [ ${arch} == 'c5n.18xlarge' ]  || [ ${arch} == 'c5.18xlarge' ]; then

	if [ ${cores} == "12" ]; then
        	echo "Running with 67% cores"
        	#24C per instance#
        	for cpunum in {12..17} {30..35}
        	do
               	echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
        	done

	elif [ ${cores} == "18" ];then
        	echo "Running with 50% cores"
        	#18C per instance#
        	for cpunum in {9..17} {27..35}
        	do
               	echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
        	done
	else
		echo "Invalid cores option for $arch. This script allows to disable 12 or 24 cores per $arch instance"
	fi

elif [ ${arch} == 'c5.24xlarge' ]; then
	if [ ${cores} == "12" ]; then
        	echo "Running with 75% cores"
        	#36C per instance#
        	for cpunum in {18..23} {42..47}
        	do
               	echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
        	done

	elif [ ${cores} == "24" ];then
        	echo "Running with 50% cores"
        	#24C per instance#
        	for cpunum in {12..23} {36..47}
        	do
               	echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
        	done
	else
		echo "Invalid cores option for $arch. This script allows to disable 12 or 24 cores per $arch instance"
	fi

else
	echo "Invalid $arch type. This script only supports c6i.32xlarge, m6i.32xlarge, hpc6a.48xlarge, c5n.18xlarge, c5.18xlarge, c5.24xlarge"
fi
```