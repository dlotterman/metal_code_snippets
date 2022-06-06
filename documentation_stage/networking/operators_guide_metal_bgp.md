# Operators Guide to Equinix Metal' BGP feature

*Operating Equinix Metal's BGP feature with FRR as an example*

---

One of the novel features of the Equinix Metal network is its customer facing BGP endpoints and integrations, allowing operators to tap into some valuable and powerful network control and announcement toolsets.

Some excellent documentation here:
[Equinix Metal BGP Documentation](https://metal.equinix.com/developers/docs/bgp/bgp-on-equinix-metal/)
[Equinix Metal Local BGP Documnetation](https://metal.equinix.com/developers/docs/bgp/local-bgp/)
[Equinix Metal Global BGP Documentation](https://metal.equinix.com/developers/docs/bgp/global-bgp/)
[Equinix Metal Terraform BGP Resource](https://registry.terraform.io/providers/equinix/metal/latest/docs/resources/bgp_session)
[Load Balancing on Equinix Metal with BGP](https://metal.equinix.com/developers/guides/load-balancing-ha/)
[Metal Partner Page for IPXO](https://metal.equinix.com/ecosystem/partners/ipxo-on-equinix-metal/)
[Youtube guide on using IPXO leased blocks with Equinix Metal](https://www.youtube.com/watch?v=xeqkrJLWZFQ)
[Equinix Metal + MetalLB for k8s](https://metallb.universe.tf/installation/clouds/#metallb-on-equinix-metal)

## Setup context:

This document aims to provide a more generalized context from existing documentation about the feature, and specifically, how to drive it as an operator. While linux is used as the lingua franca, it should apply to any network-intelligent OS or appliance.

When discussing operating the [Equinix Metal network](https://metal.equinix.com/developers/docs/networking/), I always like to clarify if we are operating in it's Layer-3 OR/AND Layer-2 network namespaces, as being specific helps eliminate a lot of subject domain overlap and confusion. In this post, *everything* I am referring to is in the Equinix Metal [Layer-3 namespace](https://metal.equinix.com/developers/docs/networking/ip-addresses/). All BGP functionality with the Equinix Metal network happens over its native, un-VLAN'ed Layer-3 network. Any documentation that references BGP and VLANs is likely referring to an Interconnection (Metal <-> AWS for example) solution design, which is explicitly not in any way relevant to peering with Equinix Metal directly as is being discussed here.

It's also important to note that as of the time of this writing, the customer facing BGP interfaces do not allow for the management of Equinix Metal's [Anycast IP](https://metal.equinix.com/developers/docs/networking/global-anycast-ips/) functionality. That functionality, which is a sort of multi-tenant "Global Anycast As A Service" feature, is self contained and is implemented at a part of the stack not currently integrated with the downstream customer BGP mesh. Simply put, you cannot BGP control Metal owned Anycast IPs (but confusingly enough you can use BGP to BYO Anycast network with your own BYOIP space).

The Equinix Metal Layer-3 network is a [routed BGP mesh](https://metal.equinix.com/blog/how-equinix-metal-is-bringing-cloud-networking-to-bare-metal-servers/), where an operators Metal instances get IP blocks allocated to their instance that are directly routed in that mesh, that is to say no NAT or anything like that. When your Equinix Metal instance is assigned `145.40.76.240/31`, that `/31` is part of a fully routed block where the distribution of blocks and routes is orchestrated by the Equinix Metal platform and internally controlled via BGP (and other safeguards).

## What it is:

What the Equinix Metal BGP feature does is expose a direct BGP interface into the customers network, allowing a BGP speaker on customer compute instances to inform the live network about its own routing ideas and state. That BGP interface is hosted via the magic of Top of Rack orchestration, where every [BGP enabled instance](https://metal.equinix.com/developers/docs/bgp/local-bgp/#creating-local-bgp-sessions) is presented with a local network BGP neighbor hosted by that instance's Top of Rack switch. When an instance is enabled for BGP, that BGP endpoint is enabled on that instance ToR, and the ToR will distribute any valid and safe BGP routing advertisements to the rest of the mesh around it.

## Uses:

This BGP feature functionality enables a couple of key use cases:

### Realtime management of ElasticIPs:

Equinix Metal provides "table stakes" [ElasticIP](https://metal.equinix.com/developers/docs/networking/elastic-ips/) functionality, where specific IP's of specific blocks can be assigned to instance's for all the cloudy reasons an operator would normally do so. ElasticIP's can be managed through the usual routes, API or GUI, but in Metal, they can also be managed via BGP, allowing Metal instances acting as BGP speakers to dynamically moved ElasticIPs around in near real time, without having to wait for API calls and host re-configuration. There are great reasons to do this. 
- One of my personal favorites, is using Metal Private IP's as ElasticIPs for internal control plane management.

This functionality falls within the scope of the ["Local BGP"](https://metal.equinix.com/developers/docs/bgp/local-bgp/) sub-feature of BGP, where an operators intent is to control the  Metal Layer-3 network within the local scope of a [Metro](https://metal.equinix.com/developers/docs/locations/metros/).

### BYOIP:

Equinix Metal allows customers to bring their own IP's via its BGP functionality. Through the ["Global BGP"](https://metal.equinix.com/developers/docs/bgp/global-bgp/) sub-feature, customers can announce their own fully route-able public IP space (/24 or larger for IPv4). When a public block is announced from an Equinix Metal instance to its BGP neighbor ToR, the ToR will distribute that announcement up to the Metal Layer-3 mesh, and then on to its various upstream providers and the IX, thus propagating the announcement to the broader public Internet.

Some cool things this enables:
- BGP enabled DDoS protection services, this is pretty special in the automated hosting space
- BYO Global Anycast 
- Uniq

### Legacy vs Current clarifications:

Prior to its acquisition by [Equinix in 2020](https://www.equinix.com/newsroom/press-releases/2020/03/equinix-completes-acquisition-of-bare-metal-leader-packet), the platform currently known as Metal was developed and operated by a startup called ["Packet"](https://www.crunchbase.com/organization/packet-host). The BGP feature was initially released and documented prior to the acquisition, where after the acquisition Metal made some substantive advancements in its physical network infrastructure altered the BGP featureset in some discrete ways. 

The effect of this is that at the time of this writing on the BGP feature:

- There are two different kinds of Equinix Metal sites, [Legacy](https://metal.equinix.com/developers/docs/locations/facilities/#legacy-facility-sites) and IBX (IBX being Equinix's naming convention for its data centers), where there are some subtle technical implementation differences in the BGP feature depending on weather it's in the scope of a Legacy facility vs IBX facility.
    - The key differentiator between the two is that in Legacy sites, the IP of the instance's BGP neighbor is the Metal Private network Gateway for the instance. In an IBX facility, the IP of servers BGP neighbor will always be a pair of pre-defined [peer_ips](https://metal.equinix.com/developers/docs/bgp/bgp-on-equinix-metal/#bgp-metadata) (`169.254.255.1/32`,`169.254.255.2/32`).

So to clarify, if you are reading documentation where the BGP neighbor is a private `10.0.0.0/8` address, that documentation is **stale or old**, and is referencing the Legacy implementation. That documentation is likely 90% otherwise accurate, but some details, in particular the IPs of the BGP endpoints, will be incorrect and will **NOT** work in IBX facilities.

## So how do you actually drive it:

The customer facing BGP endpoint is hosted on an instance’s ToR, always on the pre-defined `169.254.255.1/32`,`169.254.255.2/32` Peer IPs.

Those peering IP's expect to be reached via the [Metal Private network](https://metal.equinix.com/developers/docs/networking/ip-addresses/#private-ipv4-management-subnets), **NOT** the [Metal Public Network](https://metal.equinix.com/developers/docs/networking/ip-addresses/#public-ipv4-subnet). To be clear, that means you must peer via your instances `10.0.0.0/8` IP address, not via its Public IP address (for example `145.40.76.240/28`).

On a default Metal Linux instance, this would look like:

`ip route add 169.254.255.1/32 via 10.70.114.145`
`ip route add 169.254.255.2/32 via 10.70.114.145`

Where `10.70.114.145` is the gateway IP for the instance's Metal [Private Network](https://metal.equinix.com/developers/docs/networking/ip-addresses/#private-ipv4-management-subnets).

The easiest way to configure a Linux instance to announce an [ElasticIP](https://metal.equinix.com/developers/docs/networking/elastic-ips/) address or block is to mount the IP block on the loopback interface, and then use your BGP speaker's equivalent of ["redistribute connected"](https://docs.frrouting.org/en/latest/bgp.html#redistribution) to have the BGP speaker announce all of the IP's and networks assigned to Linux interfaces (including loopback). For example to have the Linux instance announce a registered ElasticIP block of `145.40.76.241/28`:

`ip addr add 145.40.76.241/28 dev lo:0`

This will be registered as a "connected" network in your BGP speaker's configuration and redistribute that network into its BGP table.

The operator can then configure a BGP speaker of choice ([FRR](https://frrouting.org/), [Bird](https://bird.network.cz/), [GoBGP](https://github.com/osrg/gobgp) to interface with the [Peer IPs](https://metal.equinix.com/developers/docs/bgp/bgp-on-equinix-metal/#routing-overview). 

Quick reminders from official documentation:
- The Equinix Metal network will always participate as AS `65530`.
- You can get [BGP information from the Equinix Metal Metadata API](https://metal.equinix.com/developers/docs/bgp/bgp-on-equinix-metal/#bgp-metadata)


### Example FRR configuration for reference:

```
 frr defaults traditional
service integrated-vtysh-config
!
router bgp 65000
 bgp log-neighbor-changes
 bgp router-id 10.70.114.146
 no bgp network import-check
 no bgp ebgp-requires-policy
 neighbor MetalBGP peer-group
 neighbor MetalBGP remote-as 65530
 neighbor MetalBGP ebgp-multihop 5
 neighbor MetalBGP password EXAMPLE_PASSWORD
 neighbor 169.254.255.1 peer-group MetalBGP
 neighbor 169.254.255.1 remote-as 65530
 neighbor 169.254.255.2 peer-group MetalBGP
 neighbor 169.254.255.2 remote-as 65530
 !
 address-family ipv4 unicast
  redistribute connected
  neighbor 169.254.255.1 activate
  neighbor 169.254.255.2 activate
  no neighbor MetalBGP send-community
  neighbor MetalBGP route-map ALLOW-ALL in
  neighbor MetalBGP route-map ALLOW-ALL out
  no neighbor 169.254.255.1 send-community
  no neighbor 169.254.255.2 send-community
 exit-address-family
 !
!
route-map ALLOW-ALL permit 100
!
line vty
!
end
```

Some quick notes: 
- multihop should be configured for the BGP neighbors
- Equinix Metal's community strings are [documented here](https://metal.equinix.com/developers/docs/bgp/global-communities/)
    - They are really only useful in conjunction with BYO-IP


#### How to BGP peer through Metal hosted VNFs, Virtual appliances or just VMs:

For operators who want to BGP peer with Metal from a VM hosted on a Metal instance, the same concepts as above generally apply, with these additional design concerns:

- The Equinix Metal network will ONLY accept BGP connections from the [Metal Private IP address](https://metal.equinix.com/developers/docs/networking/ip-addresses/#private-ipv4-management-subnets) assigned to the Metal instance directly. So if a Metal instance is assigned an Metal Private network of `10.66.59.130/29`, then the ToRs will only accept connections from the specific `/32` IP assigned as the instance's private IP, not any other IP in the block, in this example: `10.66.59.131`
    - This means that the Metal Private IP **MUST BE REMOVED** from the Metal instance (host) itself, so that it can be assigned **INSIDE** of the VM.
    - The VM must also be configured with the same static routing so that BGP requests are directed via the Metal Private IP assigned above. 
- BGP peering happens ONLY on the Metal Layer-3 network. This means the VM must have ports on a virtual switch where that virtual switch is attached directly to the Metal Layer-3 network with NO abstraction in between (VLANs, NAT etc).
    - For ESXi this has its own specific implications. By default ESXi instances are launched in an un-bonded configuration on the ESXi host, where `vSwitch0` is associated with the first NIC (linux equivalent of `eth0`). The VM must be placed on an equivalent of `vSwitch0`, where it can pass packets directly to the Metal Layer-3 network with Metal Layer-3 IPs configured **INSIDE** the guest.
    - Linux instances by default are launched with the Metal Layer-3 IP's placed on the `bond0` interface. The VM's ports should be on a bridge or directly attached to that `bond0` interface, and not any sub-interfaces or VLANs.
- Easy ways to validate that your VM's networking is correctly configured:
    - The VM can ping the peer_ip's `169.254.255.1` and `169.254.255.2` **THROUGH** the Metal Private Gateway (example `10.70.114.145`)
    - Other Metal instance's can ping the VM through the Metal Private IP assigned inside the guest. For example if `server_A` is hosting `vm_A`, where `vm_A` has `server_A`'s Metal Private IP, then `server_B` should be able to ping `vm_A` on `server_A`'s Private IP.

The pseudo steps to launching an Equinix Metal instance and configuring it to host a BGP speaker VM would be:

- [Enable BGP on the Project](https://metal.equinix.com/developers/docs/bgp/local-bgp/#enabling-bgp-on-the-project)
- [Reserve a block of ElasticIP's](https://metal.equinix.com/developers/docs/networking/reserve-public-ipv4s/)
- [Launch and Equinix Metal instance](https://metal.equinix.com/developers/docs/deploy/on-demand/)
- [Enable BGP on that instance](https://metal.equinix.com/developers/docs/bgp/local-bgp/#creating-local-bgp-sessions)
- Remove the [Metal Private IP](https://metal.equinix.com/developers/docs/networking/ip-addresses/#private-ipv4-management-subnets) from the bonded interface of the host
- For ESXi this would be removing the VMKernel IP
- Create a VM with a port directly attached to `bond0`
    - For ESXi this would be assigned a port from the `vSwitch0` interface 
- Add the Metal Private IP and route to the VM's interface
    - `ip addr add 10.70.114.146/29 dev enp1s0`
    - `ip route add 10.0.0.0/8 via 10.70.114.145`
- Add the ElasticIP block (or BYO-IP block) to the loopback interface 
    - `ip addr add 145.40.76.241/28 dev lo:0`
- Add the static routes to send traffic to the peer_ip's through the Private Gateway
    - `ip route add 169.254.255.1/32 via 10.70.114.145`
    - `ip route add 169.254.255.2/32 via 10.70.114.1451`
- Add the ElasticIP or BYO-IP to the VM's loopback
    - `ip addr add 145.40.76.241/28 dev lo:0`

At this point the VM should be able to reach the [Peer IPs](https://metal.equinix.com/developers/docs/bgp/bgp-on-equinix-metal/#routing-overview), and other Metal instances should be able to reach the VM's Metal Private IP.

The BGP speaker can then be configured and started, and should [bring up peering with the Metal network](https://metal.equinix.com/developers/docs/bgp/monitoring-bgp/).

