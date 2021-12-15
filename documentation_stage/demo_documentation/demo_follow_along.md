# Equinix Metal Demo "Follow-along" documentation

This document is intended to be used as a resource to "follow along" with while attending a demo of the Equinix Metal platform. 

The aim is to provide additional context and resources that may be of interest as the demo progresses.

## Platform and Ecosystem

- API and Integrations
- [API Documentation](https://metal.equinix.com/developers/api/) and [API Tools](https://metal.equinix.com/developers/guides/equinix-metal-api-with-postman/)
- [Equinix Metal CLI](https://metal.equinix.com/developers/docs/libraries/cli/)
- [Equinix Metal DevOps Integrations](https://metal.equinix.com/developers/docs/more-resources/devops/) including [Terraform](https://registry.terraform.io/providers/equinix/metal/latest) and [Ansible](https://github.com/equinix/ansible-collection-metal)
- Equinix Metal Libraries including [Golang](https://metal.equinix.com/developers/docs/libraries/go/) and [Python](https://metal.equinix.com/developers/docs/libraries/python/)

## Provisioning an "on-demand" instance

- Deployment models
	- [On-demand](https://metal.equinix.com/developers/docs/deploy/on-demand/) vs [Reserved](https://metal.equinix.com/developers/docs/deploy/reserved/) vs [Spot](https://metal.equinix.com/developers/docs/deploy/spot-market/)

	- Deployment Selections
	- [Locations](https://metal.equinix.com/developers/docs/locations/locations-about/)
	- [Current Server Lineup / Catalog](https://metal.equinix.com/product/servers/) and [Historical Server Lineup](https://metal.equinix.com/developers/docs/servers/server-specs/)
	- [Operating Systems](https://metal.equinix.com/developers/docs/operating-systems/)
		- [iPXE](https://metal.equinix.com/developers/docs/operating-systems/custom-ipxe/) and [iPXE example](https://metal.equinix.com/developers/guides/smart-os/)

	
- Instance Configuration Options at Deploy Time
	- [Number of instances AKA Batch](https://metal.equinix.com/developers/docs/deploy/batch-deployment/)
	- [Userdata](https://metal.equinix.com/developers/docs/servers/user-data/)
		- [Metadata](https://metal.equinix.com/developers/docs/servers/metadata/)
		- [Example Cloud-init for AlmaLinux](https://github.com/dlotterman/metal_code_snippets/blob/main/boiler_plate_cloud_inits/alma_linux_8_5.yaml)
	- [Networking](https://metal.equinix.com/developers/docs/networking/)
		- [Public and Private IP Addresses](https://metal.equinix.com/developers/docs/networking/ip-addresses/)
		- [VMWare Specific considerations with IP addressing at provision time](https://metal.equinix.com/developers/guides/vmware-esxi/#esxi-networking)
	- [SSH Keys](https://metal.equinix.com/developers/docs/accounts/ssh-keys/)
	
- Provisioning Engine
	- [Tinkerbell](https://tinkerbell.org/)

## Features Walk Through

- [Reserved IPs](https://metal.equinix.com/developers/docs/networking/reserve-public-ipv4s/) and ["Elastic" IPs](https://metal.equinix.com/developers/docs/networking/elastic-ips/)
- [BGP](https://metal.equinix.com/developers/docs/bgp/)
- [Layer 2](https://metal.equinix.com/developers/docs/layer2-networking/overview/)

### Interconnection

	![](https://s3.wasabisys.com/metalstaticassets/interconnect.JPG)


	- [Introduction to Interconnect](https://metal.equinix.com/developers/docs/equinix-interconnect/introduction/) 
	- [Equinix Fabric Product Page](https://www.equinix.com/interconnection-services/equinix-fabric) and [Documentation](https://docs.equinix.com/en-us/Content/Interconnection/Fabric/Fabric-landing-main.htm)
	- [Equinix Network Edge Product Page](https://edgeservices.equinix.com/) and [Documentation](https://docs.equinix.com/en-us/Content/Interconnection/NE/landing-pages/NE-landing-main.htm)
	
## Code from Demo Dashboard
- The code from the demo is publicly  visible (if ugly) on [Github](https://github.com/dlotterman/metal_benchmark_demo)
