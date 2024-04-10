INSTANCE_ID=$(metal -p $METAL_PROJECT_ID device list -o json | jq --arg INSTANCE_HOSTNAME "$INSTANCE_HOSTNAME" -r '.[] | select(.hostname==$INSTANCE_HOSTNAME) | .id')

INSTANCE_BOND0=$(metal -p $METAL_PROJECT_ID device list -o json | jq  --arg INSTANCE_HOSTNAME "$INSTANCE_HOSTNAME" -r '.[] | select(.hostname==$INSTANCE_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id')

INSTANCE_PIP0=$(metal -p $METAL_PROJECT_ID device get -i $INSTANCE_ID -o json | jq -r '.ip_addresses[] | select((.public==true) and .address_family==4) | .address')
