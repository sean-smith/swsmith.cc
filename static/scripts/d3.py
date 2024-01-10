# Import library
from d3graph import d3graph, vec2adjmat
import boto3
from pprint import pprint

ec2 = boto3.client('ec2', region_name='us-west-2')

# response = ec2.describe_instance_topology(Filters = [{'Name':'instance-type', 'Values':['trn1.32xlarge']}])
response = ec2.describe_instance_topology(Filters = [{'Name':'instance-type', 'Values':['p4de.24xlarge']}])

pprint(response.get('Instances'))

# Create example network
source = []
target = []
for instance in response.get('Instances'):
    # Layer 3 (closest to instance)
    source += [instance.get('InstanceId')]
    target += [instance.get('NetworkNodes')[2]]
    # Layer 2
    source += [instance.get('NetworkNodes')[2]]
    target += [instance.get('NetworkNodes')[1]]
    # Layer 1
    source += [instance.get('NetworkNodes')[1]]
    target += [instance.get('NetworkNodes')[0]]

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
d3.show(filepath='p4de/')