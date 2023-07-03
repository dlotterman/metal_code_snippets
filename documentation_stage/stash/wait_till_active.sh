#!/bin/bash

METAL_READ_API_KEY="YOUR_KEY_HERE"
INSTANCE_ID=$(curl -s https://metadata.platformequinix.com/2009-04-04/meta-data/instance-id)


STATE=$(curl -s -X GET --header 'Accept: application/json' --header "X-Auth-Token: $METAL_READ_API_KEY" "https://api.equinix.com/metal/v1/devices/$INSTANCE_ID"  | python3 -c 'import json,sys; print(json.load(sys.stdin)["state"])')


echo "state is $STATE for instance $INSTANCE_ID"

while [ "$STATE" != "active" ]
do
        date
        echo "waiting for instance to go active"
        sleep 10
        STATE=$(curl -s -X GET --header 'Accept: application/json' --header "X-Auth-Token: $METAL_READ_API_KEY" "https://api.equinix.com/metal/v1/devices/$INSTANCE_ID"  | python3 -c 'import json,sys; print(json.load(sys.stdin)["state"])')

done
