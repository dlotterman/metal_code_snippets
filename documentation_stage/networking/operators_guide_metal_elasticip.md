## Operators Guide: Using Metal ElasticIPs with Metal Hosted Guest VMs


A common design with [Equinix Metal](https://metal.equinix.com/) is to use Virtual Machines hosted on Equinix Metal instances as network functions.

In order to fill that function, it's often likely that an Operator would want to assign that VM an [ElasticIP](https://metal.equinix.com/developers/docs/networking/reserve-public-ipv4s/).

Due to the added levels of abstraction in virtualization and some quirks of how ElasticIPs are implemented can make this a slightly more complicated task than an operator might first assume.

This guide intends to very simply describe the task at hand and walkthrough the steps and the reasoning associated with assigning an ElasticIP into or inside of a Virtual Machine.

It is worth clarifying that this document does *not* include any of the [Metal Gateway](https://metal.equinix.com/developers/docs/networking/metal-gateway/) feature functionality in scope. 

This document also assumed static ElasticIP assignment. If you are looking to manage ElasticIPs through BGP, additional documentation can be [found here](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/networking/operators_guide_metal_bgp.md)

### Understanding an Equinix Metal instance's own network attributes

Before working with ElasticIP's, we first need to cover the fundamentals of an Instance's [network attributes](https://metal.equinix.com/developers/docs/networking/ip-addresses/) as these will have implications on the ElasticIP work later on.

When an Equinix Metal instance is launched, it can be launched with a [Public](https://metal.equinix.com/developers/docs/networking/ip-addresses/#public-ipv4-subnet) and [Private](https://metal.equinix.com/developers/docs/networking/ip-addresses/#private-ipv4-management-subnets) address where that address is part of a block, and that block is assigned specifically to that instance (and only that instance), and the Metal platform takes care of all the network magic needed to assign routes and gateways to get network packets flowing to and from that instance.

#### Public vs Private IPs

There is quite a bit of overlap in subject domain space between public and private IPs. This document assumes [public IP's](https://metal.equinix.com/developers/docs/networking/ip-addresses/#public-ipv4-subnet) only.

#### Minimum block size for VM hosted ElasticIP 

The block size assigned to the instance by default will very as [documented here](https://metal.equinix.com/developers/docs/networking/reserve-public-ipv4s/). 

It is important to note, in order to work with ElasticIP's inside of hosted guests, you will need a block larger than the default Linux size of a `/31`, where you would likely want a minimum of a `/29`. The reason for this will be fleshed out below.

#### Understanding the instance's network attributes

When an instance is launched with a block larger than a `/31` (this document will assume a `/28`), that block is configured in the following way:

`145.40.76.240/28`:
- `145.40.76.241`: is assigned as the Gateway for the block `145.40.76.240/28`, and is the gateway for the instance
- `145.40.76.242`: is assigned as the IP address for the Metal instance, that is to say it is assumed that the Operating System of the Metal Instance is or will be configured to host that IP address on it's configuration of it's interfaces. 
- `145.40.76.243` - `145.40.76.254`: These IP's are unassigned, and are free to be assigned to either the instance itself, or to VM's hosted on the instance.


#### Understanding traffic flows around the gateway

The gateway attribute is critical. The gateway will not only be the gateway for any VM's that also take IPs from the `145.40.76.240/28` block, but it will **ALSO** be the gateway for any ElasticIPs assigned to both the host instance or guest instances.

Any VM that wants to host ElasticIP traffic MUST have an IP in the block of the host, where the VM also has that IP's Gateway assigned as the gateway for relevant traffic, so most likely the default gateway.


#### Assigning IPs from the instance's block into guests

If we wanted a guest VM to host an IP address from the host's block, it could be assigned `145.40.76.243` as a free IP from the hosts block, with a default gateway of `145.40.76.241`.

### ElasticIP blocks

ElasticIP blocks are simply blocks of IPs, and that's it. The quirk of working with them is that they do **NOT** have their own gateway, there is no routing or gateway specifically for an ElasticIP block. 

When a block of ElasticIP's is assigned to an Equinix Metal instance, the platform essentially instructs the network to "send any traffic for this block of IPs to the same place you send traffic for the host's network".

Put another way:

- An instance has the network `145.40.76.240/28`, where the host is assigned `145.40.76.242` and `145.40.76.241` is the gateway.
- Operator assigns ElasticIP block `147.28.143.192/29` to that instance

The platform will essentially instruct the network:

Any traffic you see for `147.28.143.192/29`, send it to the same place you have configured for `145.40.76.240/28`. It really is as simple as that.

#### Using an ElasticIP on the **HOST** 

If the Metal instance with the IP `145.40.76.242` and the gateway `145.40.76.241`, and the Operator assigns the IP `147.28.143.193` from the ElasticIP block `147.28.143.192/29`, then the network will direct all traffic for `147.28.143.192/29` to `145.40.76.240/28`, where the instance has `145.40.76.242`, so all traffic for `147.28.143.192/29` will be directed to it.

Once the traffic for `147.28.143.192/29` lands at the instance's door, that traffic can be computed, and when it needs to begin it's return journey, it will simply hit the configured default gateway of `145.40.76.241` for the hosts block of `145.40.76.240/28`.

#### Using an ElasticIP on a **GUEST**

In order to use an ElasticIP on a guest, we need to mimic the pattern we see above on the guest.

We need to assign an IP address from the hosts block of `145.40.76.240/28` into the guest, say `145.40.76.243`, with the same gateway of `145.40.76.241`.

In this scenario, the IP allocation would look like:
`145.40.76.240/28`:
- `145.40.76.241`: is assigned as the Gateway for the block `145.40.76.240/28`, and is the gateway for the instance
- `145.40.76.242`: is assigned as the IP address for the Metal instance, that is to say it is assumed that the Operating System of the Metal Instance is or will be configured to host that IP address on it's configuration of it's interfaces. 
- `145.40.76.243`: is assigned as the IP address for the inside of the *GUEST VM* 
- `145.40.76.244` - `145.40.76.254`: These IP's are unassigned, and are free to be assigned to either the instance itself, or to VM's hosted on the instance.

That `145.40.76.243` IP address needs to be hosted *inside* the guest VM in order to give the VM a path to the gateway of `145.40.76.241`. Once it has a gateway of `145.40.76.241`, it can then be configured to host the block `147.28.143.192/29`.

In this sceario the traffic flow could be outlined as:

- Traffic comes in for `147.28.143.192/29`
- Metal network see's that it should send traffic for `147.28.143.192/29` to the same destination it sends traffic for `145.40.76.240/28`
- Traffic for `147.28.143.192/29` reaches the **HOST** instance, and is passed into the hosts virtual-switch or virtual-network.
- Guest VM with `147.28.143.192/29` assigned is passed traffic through the *host*
- Guest VM computes what needs to happen
- Guest VM returns traffic for `147.28.143.192/29` to it's default gateway of `145.40.76.241`, which is returned through the *hosts* virtual network
- Traffic is passed back to the network via the gateway of `145.40.76.241` and goes off to whereever it needs to go.

