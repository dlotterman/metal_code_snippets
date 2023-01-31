# Manually Provisioning a Single Node OpenShift instance with Equinix Metal via Redhat's Hosted Assisted Installer

This document will cover the steps needed to launch an Equinix Metal instance and send it through the needed provisioning flow to load OpenShift as a [Single Node OpenShift](https://www.redhat.com/en/blog/meet-single-node-openshift-our-smallest-openshift-footprint-edge-architectures) (SNO) instance using the Assisted Installer hosted by Redhat via their Redhat Cloud platform.

Please note that this document will use an [n3.xlarge.x86](https://deploy.equinix.com/product/servers/n3-xlarge/) instance type, which is unusual in the Metal lineup for having 4x NICs. The 4x NICs should be the more complicated model, implying one should be able to use this guide and pair it down for the traditional 2x NIC configuration in most Metal instance types.
For this document, we will assume bond0 for the n3 will be devoted to the Metal Layer-3 network for management, whereas the NIs for bond1 will be left up to later assignment as data traffic interfaces.

## Requirements
This document assumes the following are accessible and ready.
- A Equinix Metal account
- A cloud.redhat.com account
	- Developer access is fine
- Public DNS
- A place to host an ISO via public internet HTTP


### Provision the Metal instance
We need to provision the Metal instance first because subsequent steps will be dependent on information like assigned IP addresses and MAC addresses.

Because we need it deployed before we can configure the Redhat Assisted Installer with the details needed for the instance, we deploy the instance with a "stall" iPXE configuration that will allow the instance to deploy, but we won't kick of its real OS provisioning flow till later.

The most important nuances of launching an instance for use with SNO:
- It must be launched with **custom_ipxe** as the OS, where we will use the iPXE via User-data functionality to manage our instance through its provisioning lifecycle
- The instance should even be launched with **"Always iPXE"** enabled.
- The instance must be launched with a `/29` or larger block of Metal IPs. This is because OpenShift needs multiple IPs for its apps and API services endpoint.

Deploy the instance:
- Select the location and instance type you would like to deploy
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/on_demand_provision_01PNG.PNG)
- Choose iPXE as the Operating System with "Always iPXE" enabled
	- Leave the URL empty, as we will provide the iPXE information via the User-data form path in a subsequent step
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/on_demand_provision_02PNG.PNG)


- Under the "Optional Settings" for the instance:
	- Be sure to configure the instance to launch with a /29 or larger block  of public IPs
		- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/on_demand_provision_03PNG.PNG)
	- Be sure to configure the User-data form with the example iPXE script
		- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/on_demand_provision_04PNG.PNG)
	- Deploy the instance
	- Wait til the instance "goes green".
		- No OS will be installed at this point, the server will intentionally stall out in a shell in the iPXE context, but "going green" signifies that the platform has correctly populated all of the metadata for the instance.

### Collecting Metal instance Metadata
In order to build the cluster in the Redhat cloud platform, we need the Metal IP addresses, gateways and MAC addresses. 

The following [Metal CLI](https://github.com/equinix/metal-cli/) commands should capture the needed info. This document assumes you have configured Metal CLI

You can also capture the MAC addresses via SSH'ing into the [SOS / OOB](https://deploy.equinix.com/developers/docs/metal/resilience-recovery/serial-over-ssh/) endpoint for the instance and running the correct commands.

The n3.large.x86 configuration type is cabled up in the following way:
```
eth0 -> ToR_A
eth1 -> ToR_A
eth2 -> ToR_B
eth3 -> ToR_B
```

So we want the MAC addresses for eth0 and eth1 which are part of bond0:
- `metal-p $METAL_PROJ_ID device device list -o json | jq  -r '.[] | select(.hostname=="$HOSTNAME") | .network_ports[] | select(.name=="eth0") | .data.mac'`
- `metal -p $METAL_PROJ_ID device device list -o json | jq  -r '.[] | select(.hostname=="$HOSTNAME") | .network_ports[] | select(.name=="eth2") | .data.mac'`
- `metal -p $METAL_PROJ_ID device device list -o json | jq -r '.[] | select(.hostname=="$HOSTNAME") | .ip_addresses[] | select(.public) | select(.address_family==4)' `




### Creating and installing the SNO Cluster
We will now follow the steps to create the SNO Cluster object in the Redhat cloud platform. Please note there are a number of specific details in these screens, please progress slowly.

The general flow is as follows:
- First we create the OpenShift Cluster object in the Redhat Cloud Console
- The Redhat Cloud Console will provide is with an ISO (with metadata provided here loaded) 
- The instance we have already provisioned is configured to boot from that ISO
- The Redhat Cloud platform will supervise the installation and configuration of OpenShift SNO from there

#### Detailed Steps:
- After signing into the Redhat Console and finding the "OpenShift" context via the navigation menu, we will begin the flow for creating the SNO Cluster Object:
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/redhat_cloud_01.PNG)
- Then choose Data Center -> Bare Metal (x86_64) -> Interactive
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/redhat_cloud_02.PNG)
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/redhat_cloud_03.PNG)
- Create name cluster object
		- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/redhat_cloud_04.PNG)
- Configure Static Networking
	```
---
dns-resolver:
  config:
    server:
      - "147.75.207.207"
interfaces:
  -
    ipv4:
      address:
        -
          ip: "139.178.87.26"
          prefix-length: 29
      dhcp: false
      enabled: true
    ipv6:
      enabled: false
    link-aggregation:
      mode: 802.3ad
      options:
        miimon: "100"
      port:
        - ens3f0
        - ens3f2
    name: bond0
    state: up
    type: bond
routes:
  config:
    -
      destination: 0.0.0.0/0
      next-hop-address: "139.178.87.25"
      next-hop-interface: bond0
      table-id: 254

	```
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/redhat_cloud_05.PNG)
- Leave "Operators" at defaults
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/redhat_cloud_06.PNG)
- Add hosts
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/redhat_cloud_07.PNG)
	- Add public SSH key and generate ISO
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/redhat_cloud_08.PNG)
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/redhat_cloud_09.PNG)
- Download and host the ISO somewhere accessible
- Update the Metal instance with the follow iPXE configuration!
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/update_metal_instance_01.PNG)
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/update_metal_instance_02.PNG)
- Reboot the Metal Instance
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/update_metal_instance_03.PNG)
- After sometime, the instance should be visible in the redhat console
	- May take ~5-10 minutes while the server reboots into the ISO
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/update_metal_instance_04.PNG)
- You can also watch via the OOB / SOS
- Change Hostname
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/update_metal_instance_05.PNG)
- Proceed
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/update_metal_instance_06.PNG)
- Leave storage at defaults
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/update_metal_instance_07.PNG)	
- Leave networking at defaults
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/update_metal_instance_08.PNG)
- Install Cluster
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/update_metal_instance_09.PNG)
- Monitor installation progress
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/installation_progress_01.PNG)
- Disable always_ipxe!
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/disable_always_ipxe_1.PNG)
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/disable_always_ipxe_2.PNG)
- Cluster Install Complete!
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/installation_complete_01.PNG)
- Modify DNS
	- `apps.DOMAIN` needs to point to the IP listed
		- So example `apps.sno-ocp01.ocp-da01.dlott.casa -> 139.178.87.26`
	- `*.apps.DOMAIN` wildcard needs to point to the IP listed
		- So example `*.apps.sno-ocp01.ocp-da01.dlott.casa -> 139.178.87.26`	
	- `api.DOMAIN` needs to point to the IP listed
		- Some example `api.sno-ocp01.ocp-da01.dlott.casa -> 139.178.87.26`
- Login to OpenShift
	- ![](https://s3.us-east-1.wasabisys.com/metalstaticassets/ocpsno/installation_complete_02.PNG)	
