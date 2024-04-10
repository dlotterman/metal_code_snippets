gtst_project_dashboard(){
metal device list -p $METAL_PROJECT_ID -o json | jq -r '.[] | .id + "\t" + .plan.slug + "\t" + .facility.code + "\t" + (.ip_addresses[]| select((.public==true) and .address_family==4) | .address|tostring) + "\t" + (.ip_addresses[]| select((.public==false) and .address_family==4) | .address|tostring) + "\t" + .hostname[0:15] + "\t\t" + .state[0:6] + "\t" +  .operating_system.slug[0:8]'
}

gtst_project_dashboard_private(){
metal device list -p $METAL_PROJECT_ID -o json | jq -r '.[] | .id + "\t" + .plan.slug + "\t" + .facility.code + "\t" + (.ip_addresses[]| select((.public==false) and .address_family==4) | .address|tostring) + "\t" + .hostname[0:15] + "\t\t" + .state[0:6] + "\t" +  .operating_system.slug[0:8]'
}

gtst_project_dashboard_nn(){
metal device list -p $METAL_PROJECT_ID -o json | jq -r '.[] | .id + "\t" + .plan.slug + "\t" + .hostname[0:15] + "\t\t" + .state[0:6] + "\t" +  .operating_system.slug[0:8]'
}

gtst_instance_meta(){
INSTANCE_ID=$(metal -p $METAL_PROJECT_ID device list -o json | jq --arg METAL_INSTANCE_NAME "$METAL_INSTANCE_NAME" -r '.[] | select(.hostname==$METAL_INSTANCE_NAME) | .id')
INSTANCE_BOND0=$(metal -p $METAL_PROJECT_ID device list -o json | jq  --arg METAL_INSTANCE_NAME "$METAL_INSTANCE_NAME" -r '.[] | select(.hostname==$METAL_INSTANCE_NAME) | .network_ports[] | select(.name=="bond0") | .id')
INSTANCE_PIP0=$(metal device get -i $INSTANCE_ID -o json | jq -r '.ip_addresses[] | select((.public==true) and .address_family==4) | .address')
INSTANCE_BEIP0=$(metal device get -i $INSTANCE_ID -o json | jq -r '.ip_addresses[] | select((.public==false) and .address_family==4) | .address')
echo "Metal Instance Hotname: $METAL_INSTANCE_NAME"
echo "Metal Instance ID: $INSTANCE_ID"
echo "Metal Instance Public IP: $INSTANCE_PIP0"
echo "Metal Instance Backend IP: $INSTANCE_BEIP0"
echo "Metal instance root password is: $(metal device get -i $INSTANCE_ID -o json | jq -r '.root_password')"
}
