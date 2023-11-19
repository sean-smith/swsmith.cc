#!/bin/bash
# Copyright Sean Smith 2023 <seaam@amazon.com>

GREEN='\033[0;32m'
NC='\033[0m' # No Color

if ! command -v pcluster >/dev/null 2>&1 ; then
    echo "Must install aws-parallelcluster cli... exiting"
    exit
fi
if ! command -v aws >/dev/null 2>&1 ; then
    echo "Must install aws cli... exiting"
    exit
fi
if ! command -v jq >/dev/null 2>&1 ; then
    echo "Must install jq... exiting"
    exit
fi
if ! command -v packer >/dev/null 2>&1 ; then
    echo "Must install packer... exiting"
    exit
fi
    
echo 'Listing your clusters...'
pcluster list-clusters | jq '.clusters[].clusterName'
read -p 'What cluster would you like to create a Login node for? ' cluster_name
echo -e "Selected ${GREEN}$cluster_name${NC}..."
version=$(pcluster list-clusters | jq  ".clusters[] | select(.clusterName | contains(\"${cluster_name}\")) | .version")
echo -e "Found Version... ${GREEN}$version${NC}"
if ! test "$version" = "$(pcluster version | jq '.version')"
then
    echo -e "Must install pcluster version ${GREEN}$version${NC}... exiting"
    exit
fi
headnode_ip=$(pcluster describe-cluster -n $cluster_name | jq '.headNode.privateIpAddress')
echo -e "Found HeadNode ip ${GREEN}$headnode_ip${NC}..."
subnet=$(aws ec2 describe-instances \
    --instance-ids `pcluster describe-cluster -n $cluster_name | jq '.headNode.instanceId' | tr -d '"' ` | jq '.Reservations[0].Instances[0].SubnetId')
echo -e "Found Subnet ${GREEN}$subnet${NC}..."
region=$(pcluster describe-cluster -n $cluster_name | jq '.region')
echo "Found Subnet $region...${NC}"

echo 'Writing to variables.json...'
cat <<EOF | tee variables.json
{
  "aws_region": $region,
  "cluster_name": "$cluster_name",
  "parallel_cluster_version": $pcluster_version,
  "instance_type": "c5a.2xlarge",
  "encrypt_boot": "false",
  "public_ip": "true",
  "ssh_interface": "public_dns",
  "head_node_ip": $headnode_ip,
  "subnet_id": $subnet
}
EOF
echo 'Now run the command:'
echo -e "${GREEN}packer build -color=true -var-file variables.json packer.json${NC}"
