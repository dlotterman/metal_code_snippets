An Operators TLDR on Metal Layer-3 and Layer-2 networking

## Underlay

An Equinix Metal instance starts with a Bare Metal Server (BMS), where that BMS is connected by at least 2x physical ethernet ports to a pair of Top of Rack switches, where those ToR's are configured to by default, LACP mLAG the ports across the switch chassis. [Blog documenting this here](https://deploy.equinix.com/blog/breaking-bond/).

When an Equinix Metal instance is provisioned, those switch ports are placed into an "access" mode of presenting the Customer's Service VLAN to the instance's LACP interface, such that traffic is untagged or native to the host.

The Metal network is at its core a Layer-3 first network, where customer access is provided by allocating customers [Public and Private IP space from that Layer-3](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/) network and providing that Layer-3 access over the Customer Service VLAN that is presented in access mode by the BMS's ToR on the mLAG interface facing the BMS.

## Customer Layer-3

The Customer Service VLAN provides access to[Metal's network local to that Metro. The Metal platform will allocate the customer and the instance a set of Public and Private IP subnets, where the gateways for those subnets are configured by the platform on the mLAG inteface, and the useable IP's for those blocks are configured by the cloud automation platform to be assigned into the Metal instace's Customer Operating system so that when the instance is delivered, it is able to achieve basic connectivity over the Public and Private Layer-3 networks over the native or untagged VLAN facing the instance's ToRs.

## Customer Layer-2

When a customer creates a [Layer-2 VLAN](https://deploy.equinix.com/developers/docs/metal/layer2-networking/overview/), that VLAN is really a VXLAN that lives on the Metal Layer-3 network (remember Metal is Layer-3 native), where the Metal platform takes care of the orchestration of performing a rack-local translation from the VXLAN to VLAN, so that the Metal instance receives [802.1q](https://en.wikipedia.org/wiki/IEEE_802.1Q) tagged frames on it's network interfaces.

These VLANs are entirely a customer's Layer-2 space, they can bring any subnetting / architecture design needed within those broadcast domains.

## Hybrid Networking Modes

When placed into a [Hybrid networking mode](https://deploy.equinix.com/developers/docs/metal/layer2-networking/hybrid-bonded-mode/), a Metal instance will have connectivity to both Metal's Layer-3 network and it's customer managed Layer-2 VLANs, potentially creating overlap between the two otherwise seperate networking domains

## Understanding Private IP's and the 10.0.0.0/8 route

When a Metal instance is launched, by default it is given:
- [/31 Public IP address](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#public-ipv4-subnet)
- [/31 Private IP address](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#private-ipv4-management-subnets)

Where: 

- That Public /31 is a block carved from a [larger, multi-tenant block of public IP's owned by Metal](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#equinix-metals-public-ip-address-blocks), presumably /24 or larger.
- The Private /31 comes from a larger, pre-defined /25 block of private IPs that the Equinix Metal platform assigned into the project for the specific Metro.
	- If a customer looks at their IP's in the ["Networking -> IPs"](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#managing-your-projects-ip-addresses) page of the Equinix Metal console, they will see the pre-defined / reserved blocks of `10.x.x.x/25" addresses, where when they provision a new Equinix Metal instance, the instance will get a /31 assigned to it from that block.
		- So if an Operator has `10.12.105.0/25` assigned to Amsterdam in their Project IPs, then when the customer goes to provision an instance in Amsterdam, it will get an assignment from that block, so for example it could get `10.12.105.24/31`
			- The instance gets an IP of `10.12.105.25`, and the instance's ToR gets assigned a gateway IP of `10.12.105.24`.

Again, this 10.x.x.x network is delivered to the Metal instance on the *native* or *untagged* VLAN, such that the instance attaches these IP's directly to the untagged bonded interface of the Metal instance.

So when an Equinix Metal instance is provisioned, it could have the following configuration:

IP Addresses 
```
Public IP: 93.187.217.143/31 on bond0
Private IP: 10.12.104.25/31 on bond0
```

Route Table:
```
default via 93.187.217.142 dev bond0
10.0.0.0/8 via 10.12.105.25 dev bond0
10.12.105.24/31 dev bond0 src 10.12.104.25
93.187.217.142/31 deb bond0 src 93.187.217.143
```

The purpose of the `10.0.0.0/8` is to enable the [Private Networking](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#private-ipv4-management-subnets) and [Backend Transfer](https://deploy.equinix.com/developers/docs/metal/networking/backend-transfer/) features of Equinix Metal, it's a simple, one line route statement that tells the Metal instance "Any 10.x.x.x traffic, just pass it to your private gateway and the network will figure it out". 

Example route scenarios:

- An Equinix Metal instance wants to reach a host on the Public Internet, say `69.188.199.22`
	- That network is not in its local routing table, so it finds `93.187.217.142` as it's default gateway and sends the direction that way
- An Equinix Metal instance wants to reach another Metal host in the same project in the same Metro (Amsterdam), say `10.12.104.98`
	- That network, `10.12.104.97/31`, is part of `10.12.104.0/25`, which is part of the larger `10.0.0.0/8` block.
		- So the Equinix Metal instance does have a route for it in it's local routing table, which says send any traffic for `10.0.0.0/8` to your private gateway of `10.12.105.25`
- An Equinix Metal instance wants to reach another Metal host in the same project in a different Metro (New York), say `10.10.38.1`
	- That network `10.10.38.1` will also be caught by the `10.0.0.0/8` route statement, the traffic will be sent to the private gateaway, and if the project is enabled for [Backend Transfer](https://deploy.equinix.com/developers/docs/metal/networking/backend-transfer/), the private gateway will send the traffic over the global network to the New York network where the local New York network will route the traffic to the instance living on `10.10.38.1`.


### 10.0.0.0/8 route statement and overlap with Customer Layer-2

Often, when a customer wants to bring their own subnet to Equinix Metal inside of a [Layer-2 VLAN](https://deploy.equinix.com/developers/docs/metal/layer2-networking/vlans/), that subnet may itself be a `10.0.0.0/8` subnet, which my overlap or conflict with the `10.x.x.x/25` network assigned by Equinix Metal, which can lead to a bit of a routing table mess without any planning.

When a customer wants to bring a `10.0.0.0/8` or large `10.x.x.x` subnet to Metal Layer-2, here are some ways of thinking of the overlap problem:

- If a customer does not inteded to use the [Private](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#private-ipv4-management-subnets) / [Backend](https://deploy.equinix.com/developers/docs/metal/networking/backend-transfer/) network at all, the route statement can simply be removed from the instance all together

- If a customer does want to use [Private](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#private-ipv4-management-subnets) / [Backend transfer](https://deploy.equinix.com/developers/docs/metal/networking/backend-transfer/) and wants to co-locate the networks on a Metal host:
	- Customer wants to bring `10.30.200.0/24` and use it inside Metal VLAN `2228`, which does not conflict with any Metal Layer-3 IP space directly, but does conflict with the `10.0.0.0/8` route statement:
		- The customer could assign a route statement specific to that network for that interface on the server, which should be done by default, so that any traffic that hits `10.30.200.0/24` should be sent out the `bond0@VLAN2228` interface, instead of the `bond0` interface, which will still be the default 

- Customer wants to bring a network of `10.51.43.0/24` which conflicts directly with a Metal assigned block of `10.51.43.128/25`
	- Customer can create a new project so that a new internal IP block is assigned that will likely not conflict
	- Customer can remove the Private / [Backend Transfer](https://deploy.equinix.com/developers/docs/metal/networking/backend-transfer/) networking and design using another network.
	
Customers can also create more specific route statements than the very large `10.0.0.0/8` statement that gets assigned by default, for example:

If a customer wanted to use Backend Transfer between a host in `FR` with IP `10.92.19.229/31` and a host in `PA` with an IP of `10.73.9.183/31`, instead of using the large `10.0.0.0/8`, they could assign `10.92.19.128/25` as a route via it's local private gateway of `10.73.9.182`. This will apply a more specific route `FR` <-> `PA` that will free up the `10.0.0.0/8` space for other routing.

