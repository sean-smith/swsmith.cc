#!/bin/sh
# copyright Sean Smith <seaam@amazon.com>
# attach_ebs.sh - Attach an EBS volume to an EC2 instance.

#   Usage:
#   attach_ebs.sh /scratch gp2|gp3|io1|io2 100 /dev/xvdb
#
#   1. Create a EBS volume
#   2. Wait for it to become availible
#   3. Mount it
#   4. Format filesystem

mount_point="${1:-/scratch}"
type="${2:-gp3}"
size="${3:-100}"

az=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# 1. create ebs volume
volume_id=$(aws ec2 --region $region create-volume \
    --availability-zone ${az} \
    --volume-type ${type} \
    --size ${size} | jq -r .VolumeId)
echo "Created $volume_id..."

# 2. wait for volume to create
aws ec2 --region $region wait volume-available \
    --volume-ids ${volume_id}

# 3. attach volume
aws ec2 --region $region attach-volume \
    --device /dev/sdf \
    --instance-id ${instance_id} \
    --volume-id ${volume_id}

# 4. format filesystem
mkfs -t ext4 /dev/xvdf

# 5. mount filesystem
mkdir -p ${mount_point}
mount /dev/xvdf ${mount_point}
