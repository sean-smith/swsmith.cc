#!/bin/bash
# Copyright Sean Smith 2023 <seaam@amazon.com>

GREEN='\033[0;32m'
NC='\033[0m' # No Color
    
read -p "What's your AMI ID? " ami_id
read -p "What instance type? " instance_type
cluster_name=$(cat variables.json | jq '.cluster_name' | tr -d '"')
subnet_id=$(cat variables.json | jq '.subnet_id' | tr -d '"')
instance_id=$(pcluster describe-cluster -n $cluster_name | jq '.headNode.instanceId' | tr -d '"')
security_group=$(aws ec2 describe-instances \
    --instance-ids $instance_id | jq '.Reservations[0].Instances[0].SecurityGroups[0].GroupId' | tr -d '"')

echo -e "Cluster ${GREEN}$cluster_name${NC}..."
echo -e "Subnet ID ${GREEN}$subnet_id${NC}..."
echo -e "HeadNode ID ${GREEN}$instance_id${NC}..."
echo -e "Security Group ID ${GREEN}$security_group${NC}..."

# launch Login Node
aws ec2 run-instances \
   --subnet-id $subnet_id \
   --image-id $ami_id \
   --instance-type $instance_type \
   --security-group-ids $security_group \
   --tag-specifications "ResourceType=instance,Tags=[{Key='parallelcluster:cluster-name',Value=$cluster_name},{Key='parallelcluster:node-type',Value='HeadNode'}]"
