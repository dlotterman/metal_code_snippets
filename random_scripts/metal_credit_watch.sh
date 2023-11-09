#!/bin/bash

while getopts t:o:d flag
do
    case "${flag}" in
        t) TOKEN=${OPTARG};;
        o) ORG=${OPTARG};;
        d) DELETEALL=${OPTARG};;
    esac
done

OUTPUT=$(curl -s "https://api.equinix.com/metal/v1/organizations/$ORG" \
-X GET \
-H "Content-Type: application/json" \
-H "X-Auth-Token: $AUTH_TOKEN")
sleep 1
if (echo $OUTPUT | jq -e 'has("errors")' > /dev/null); then
        echo $OUTPUT | jq
else
        echo "Done..."
fi
