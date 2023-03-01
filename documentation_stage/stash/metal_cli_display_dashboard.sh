```
metal device list -o json > /tmp/metal_device_list.json && for DEVICE_ID in $(jq -r '.[].id' /tmp/metal_device_list.json); do jq --arg DEVICE_ID "$DEVICE_ID" -r '.[] | select ((.id==$DEVICE_ID))' /tmp/metal_device_list.json | jq -r '.state + " " + .id + " " + (.ip_addresses[]| select ((.address_family==4) and .public==true) | .address|tostring) + " " + .hostname'; done
```