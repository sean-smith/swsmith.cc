# Import library
from d3graph import d3graph, vec2adjmat
import boto3
from pprint import pprint

ec2 = boto3.client('ec2', region_name='us-west-2')

response = ec2.describe_instance_topology(Filters = [{'Name':'instance-type', 'Values':['p4de.24xlarge']}])

pprint(response.get('Instances'))

# Create example network
source = []
target = []
for instance in response.get('Instances'):
    instance_id = instance.get('InstanceId')
    for network_node in instance.get('NetworkNodes'):
        source += [instance_id]
        target += [network_node]

pprint(source)
pprint(target)

# Convert to adjacency matrix
adjmat = vec2adjmat(source, target)

# # Initialize
d3 = d3graph()
# Proces adjmat
d3.graph(adjmat)
# Plot
d3.show()

# Make changes in node properties
d3.set_node_properties(color=adjmat.columns.values)
# Plot
d3.show(filepath='temp/')