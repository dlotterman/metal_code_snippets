# GTST Labs: Using ElasticIPs + BGP for load balancing with Equinix Metal

This lab intends to walk the reader through the logical concepts involved with spinning up 2x or more Equinix Metal instances, and configuring them with the correct BGP configuration to have them load balance an ElasticIP via BGP, leveraging BGP's ECMP to distribute load across instances.

## Relevant Documentation

* [Metal Instance Networking](https://deploy.equinix.com/developers/docs/metal/networking/server-level-networking/)
* [Metal BPG](https://deploy.equinix.com/developers/docs/metal/bgp/bgp-on-equinix-metal/)
	- [Local BPG](https://deploy.equinix.com/developers/docs/metal/bgp/local-bgp/)
	- [Operators Guide to Equinix Metal BGP](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/networking/operators_guide_metal_bgp.md)
	- [Operators Guide to ElasticIPs](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/networking/operators_guide_metal_elasticip.md)
	- [Equinix Metal BGP / Bird Repository](https://github.com/enkelprifti98/Equinix-Metal-BGP/blob/main/Equinix-Metal-BIRD-Setup.sh)
* [Equinix Metal PeeringDB](https://www.peeringdb.com/net/5230)
* [Equinix Metal HE BGP Toolkit](https://bgp.he.net/AS54825#_peers)

## Requirements

This lab assumes the reader has:

1. A correct and working Linux like shell, this guide assumes `bash`
2. That shell has [metal-cli](https://deploy.equinix.com/developers/docs/metal/libraries/cli/) installed and correctly configured
3. The reader has a **read-write** Metal API key
4. The reader has a project created, with correct users invited.

## Environment setup

First we must clone this repository and configure some shell variables. This variables will be consumed by subsequent shell scripts to mangle and glue as needed.

Following this guide will create:

- 1x Metal Instance
- 1x ElasticIP (managed by BGP)
- 1x BGP session between Metal instance and Metal Networking


To create a second, third or (n) instance, simply repeat these steps while changing / incrementing the below `INSTANCE_INT` variable.


## Clone
- `git clone https://github.com/dlotterman/metal_code_snippets.git`
- `cd metal_code_snippets/`

## Set environment variables

-
	```
	eval $(metal env)
	INSTANCE_INT=11
	METAL_METRO=CH
	INSTANCE_HOSTNAME=node-$METAL_METRO-$INSTANCE_INT
	source shell/gtst.env
	source shell/gtst_metal_shellisms.sh
	```

The sourcing of the included shell scripts simply removes some bash mangling from public view / needing to be copy and pasted for the reader of this lab.

## Provision Metal instance

Note: this example uses a `cloud-init` from the author to do some basic security toil
- `metal device create --hostname $INSTANCE_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system ubuntu_22_04 --project-id $METAL_PROJECT_ID -t "metalcli,elasticlab" --userdata-file boiler_plate_cloud_inits/ubuntu_22_04_v1.mime`


## Provision ElasticIP and Enable BGP

Note: This project assumes a single ElasticIP or "/32". Just edit here as needed to create a larger block

Get ElasticIPs that are tagged with our tag
- `PROJ_ELAS_IPS=$(metal -p $METAL_PROJECT_ID ip get -o json | jq '.[] | select(.tags[0]=="elasticlab")')`


If list of ElasticIPs does not include one with our tag, then provision a new block:
-
	```
	if [ -z "$PROJ_ELAS_IPS" ]; then
		echo "no existing IPs found, requesting new block"
		metal ip request -p $METAL_PROJECT_ID -t public_ipv4 --tags elasticlab -q 1 -m $METAL_METRO
		sleep 5
		PROJ_ELAS_IPS=$(metal -p $METAL_PROJECT_ID ip get -o json | jq '.[] | select(.tags[0]=="elasticlab")')
	fi
	```

Enable BGP on the Metal project:
- `metal project bgp-enable -p $METAL_PROJECT_ID --deployment-type local --md5 Equinixmetal05 --asn 65000`

Mangle glue:
-
```
source shell/gtst_instance_meta.sh
ELASTIC_IP=$(echo $PROJ_ELAS_IPS | jq -r .address)
ELASTIC_CIDR=$(echo $PROJ_ELAS_IPS | jq -r .cidr)
```

## Configure host

The reader should wait till the instance is visibly "green" status in the Metal WebUI or console before proceeding.

-
```
ssh adminuser@$INSTANCE_PIP0 "wget https://raw.githubusercontent.com/enkelprifti98/Equinix-Metal-BGP/main/Equinix-Metal-BIRD-Setup.sh"
ssh adminuser@$INSTANCE_PIP0 "sudo METAL_AUTH_TOKEN=$METAL_AUTH_TOKEN bash Equinix-Metal-BIRD-Setup.sh"
ssh adminuser@$INSTANCE_PIP0 "sudo ip addr add $ELASTIC_IP/$ELASTIC_CIDR dev lo"
ssh adminuser@$INSTANCE_PIP0 "sudo apt-get install -y nginx && sudo systemctl enable --now nginx"
ssh adminuser@$INSTANCE_PIP0 "sudo ufw allow http"
```

Get host info:
- `gtst_project_dashboard`
