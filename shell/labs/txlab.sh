metal_project(){
metal device list -p $METAL_PROJ_ID -o json | jq -r '.[] | .id + "\t" + .plan.slug + "\t" + .facility.code + "\t" + (.ip_addresses[]| select((.public==true) and .address_family==4) | .address|tostring) + "\t" + (.ip_addresses[]| select((.public==false) and .address_family==4) | .address|tostring) + "\t" + .hostname[0:15] + "\t\t" + .state[0:6] + "\t" +  .operating_system.slug[0:8]'
}
