#!/bin/sh
# copyright Sean Smith <seaam@amazon.com>
# attach_ebs.sh - Attach an EBS volume to an EC2 instance.

#   Usage:
#   attach_ebs.sh /scratch gp2|gp3|io1|io2 100 /dev/xvdb
#
#   1. Create a EBS volume
#   2. wait for volume to create
#   3. attach volume
#   4. wait for volume to attach
#   5. format filesystem
#   6. mount filesystem
#   7. persist volume after reboots

mount_point="${1:-/scratch}"
type="${2:-gp3}"
size="${3:-100}"
device=${4:-/dev/sdf}

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
    --device ${device} \
    --instance-id ${instance_id} \
    --volume-id ${volume_id}

# 4. wait until volume is attached
DEVICE_STATE="unknown"
until [ "${DEVICE_STATE}" == "attached" ]; do
    DEVICE_STATE=$(aws ec2 describe-volumes \
    --region ${region} \
    --filters \
        Name=attachment.instance-id,Values=${instance_id} \
        Name=attachment.device,Values=${device} \
    --query Volumes[].Attachments[].State \
    --output text)
    sleep 5
done

# 5. format filesystem
mkfs -t xfs ${device}

# 6. mount filesystem
mkdir -p ${mount_point}
mount ${device} ${mount_point}

# 7. Persist Volume after reboots by putting it into /etc/fstab
echo "${device} ${mount_point} xfs defaults,nofail 0 2" >> /etc/fstab
