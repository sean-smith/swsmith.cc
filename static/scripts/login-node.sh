#!/bin/bash
# Copyright Sean Smith 2022 <seaam@amazon.com>

GREEN='\033[0;32m'
NC='\033[0m' # No Color

if ! command -v pcluster >/dev/null 2>&1 ; then
    echo "Must install aws-parallelcluster cli"
fi
if ! command -v aws >/dev/null 2>&1 ; then
    echo "Must install aws cli"
fi
if ! command -v jq >/dev/null 2>&1 ; then
    echo "Must install jq"
fi
if ! command -v packer >/dev/null 2>&1 ; then
    echo "Must install packer"
fi
    
echo 'Listing your clusters...'
pcluster list-clusters | jq '.clusters[].clusterName'
read -p 'What cluster would you like to create a Login node for? ' cluster_name
echo -e "Selected ${GREEN}$cluster_name${NC}..."
headnode_ip=$(pcluster describe-cluster -n $cluster_name | jq '.headNode.privateIpAddress')
echo -e "Found HeadNode ip ${GREEN}$headnode_ip${NC}..."
pcluster_version=$(pcluster describe-cluster -n $cluster_name | jq '.version')
echo -e "Found Version ${GREEN}$pcluster_version${NC}..."
subnet=$(aws ec2 describe-instances \
    --instance-ids `pcluster describe-cluster -n $cluster_name | jq '.headNode.instanceId' | tr -d '"' ` | jq '.Reservations[0].Instances[0].SubnetId')
echo -e "Found Subnet ${GREEN}$subnet${NC}..."
region=$(pcluster describe-cluster -n $cluster_name | jq '.region')
echo "Found Subnet $region...${NC}"

echo 'Writing to variables.json...'
cat <<EOF | tee variables2.json
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
echo -e "${GREEN}packer build -color=true -var-file variables.json pc-login-node.json${NC}"