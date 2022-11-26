#!/bin/bash
    
read -p "What's your AMI ID? " ami_id
read -p "What's instance type? " instance_type
cluster_name=$(cat variables.json | jq '.cluster_name' | tr -d '"')
subnet_id=$(cat variables.json | jq '.subnet_id' )
instance_id=$(pcluster describe-cluster -n $cluster_name | jq '.headNode.instanceId' | tr -d '"')
security_group=$(aws ec2 describe-instances \
    --instance-ids $instance_id | jq '.Reservations[0].Instances[0].SecurityGroups[0].GroupId')

echo -e "Cluster $cluster_name..."
echo -e "Subnet ID $subnet_id..."
echo -e "HeadNode ID $instance_id..."
echo -e "Security Group ID $security_group..."

# launch Login Node
aws ec2 run-instances \
   --subnet-id $subnet_id \
   --image-id $ami_id \
   --instance-type $instance_type \
   --security-group-ids $security_group \
   --tag-specifications "ResourceType=instance,Tags=[{Key='parallelcluster:cluster-name',Value=$cluster_name},{Key='parallelcluster:node-type',Value='HeadNode'}]"
