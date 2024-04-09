# GTST Labs: Using ElasticIPs + BGP for load balancing with Equinix Metal

This lab intends to walk the reader through the logical concepts involved with spinning up 2x Equinix Metal instances, and configuring them with the correct BGP configuration to have them load balance an ElasticIP via BGP, leveraging BGP's ECMP to distribute load across instances.

## Requirements

This lab assumes the reader has:

1. A correct and working Linux like shell, this guide assumes `bash`
2. That shell has [metal-cli](https://deploy.equinix.com/developers/docs/metal/libraries/cli/) installed and correctly configured
3. The reader has a **read-write** Metal API key

## Environment setup

First we must clone this repository and configure some shell variables. This variables will be consumed by subsequent shell scripts to mangle and glue as needed.

## Clone
- `git clone https://github.com/dlotterman/metal_code_snippets.git`
- `cd metal_code_snippets/`

## Set environment variables

Only mandatory change is `$METAL_PROJ_ID`

-
	```
	INSTANCE_INT=11
	METAL_METRO=SV
	INSTANCE_HOSTNAME=node-$METAL_METRO-$INSTANCE_INT
	METAL_PROJ_ID=YOUR_PROJ_ID
	source shell/gtst.env
	source shell/gtst_metal_shellisms.sh
	source shell/get_config_from_metal_cli.sh
	```

## Provision Metal instance

Note: this example uses a `cloud-init` from the author to do some basic security toil

- `metal device create --hostname $INSTANCE_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system ubuntu_22_04 --project-id $METAL_PROJ_ID -t "metalcli,elasticlab" --userdata-file boiler_plate_cloud_inits/ubuntu_22_04_v1.mime`


## Provision ElasticIP and Enable BGP

Note: This project assumes a single ElasticIP or "/32". Just edit here as needed to create a larger block

- `PROJ_ELAS_IPS=$(metal -p $METAL_PROJ_ID ip get -o json | jq '.[] | select(.tags[0]=="elasticlab")')`

-
	```
	if [ -z "$PROJ_ELAS_IPS" ]; then
		echo "no existing IPs found, requesting new block"
		metal ip request -p $METAL_PROJ_ID -t public_ipv4 --tags elasticlab -q 1 -m $METAL_METRO
		sleep 5
		PROJ_ELAS_IPS=$(metal -p $METAL_PROJ_ID ip get -o json | jq '.[] | select(.tags[0]=="elasticlab")')
	fi
	```

- `metal project bgp-enable -p $METAL_PROJ_ID --deployment-type local --md5 Equinixmetal05 --asn 65000`

### More glue mangling

-
```
source shell/gtst_instance_meta.sh
ELASTIC_IP=$(echo $PROJ_ELAS_IPS | jq -r .address)
ELASTIC_CIDR=$(echo $PROJ_ELAS_IPS | jq -r .cidr)
```

## Configure host

-
```
ssh adminuser@$INSTANCE_PIP0 "wget https://raw.githubusercontent.com/enkelprifti98/Equinix-Metal-BGP/main/Equinix-Metal-BIRD-Setup.sh"
ssh adminuser@$INSTANCE_PIP0 "sudo METAL_AUTH_TOKEN=$METAL_AUTH_TOKEN bash Equinix-Metal-BIRD-Setup.sh"
ssh adminuser@$INSTANCE_PIP0 "sudo ip addr add $ELASTIC_IP/$ELASTIC_CIDR dev lo"
ssh adminuser@$INSTANCE_PIP0 "sudo apt-get install -y nginx && sudo systemctl enable --now nginx"
ssh adminuser@$INSTANCE_PIP0 "sudo ufw allow http"
```
