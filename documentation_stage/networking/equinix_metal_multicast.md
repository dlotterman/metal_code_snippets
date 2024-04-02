# Multicast Networking with Equinix Metal

**TLDR:**

Equinix Metal supports simple or niave [multicast](https://en.wikipedia.org/wiki/Multicast) usage inside of Equinix Metal customer VLANs, but does not support IGMP / Multicast routing. This limit is imposed by the local Metal network in a Metro, and thus also includes Multicast networking brought in via [Interconnection](https://deploy.equinix.com/developers/docs/metal/interconnections/introduction/).

Customers who want to bring IGMP / Multicast routing dependant workloads must build their own overlay or tunneled network capable of supporting that traffic.

## Metal is a native Layer-3 network

Equinix Metal is principally a Layer-3 native network, meaning it's primary constructs are Layer-3, so IP addresses and route statements. Even when Metal provides customers with Layer-2 primitives, those are still functionally abstractions built on-top of the native Layer-3 Metal network.

## Understanding Metal Layer-2 VLANs

From an Equinix Metal instance to it's Top of Rack switches, a Metal VLAN exists as a real `802.1Q` VLAN, where that VLAN exists as a "local rack", "ephemeral" or "private VLAN", where the private VLAN exists only for a customer's instances hosted on that Top of Rack.

From the private / local rack VLAN, the customer VLAN is bridged into a customer VXLAN, where the Metal network being a fully routed Layer-3 mesh, that customer VXLAN will transverse the Metal network as needed to provide a broadcast domain between one Metal instance on one rack and another Metal instance configured with the same VLAN, potentially as far away as a different Equinix Metal facility (inside the same Metro) entirely.

## Understanding Multicast and IGMP

Because Equinix Metal "VLANs" are just VXLANs outside of their local rack, that means an Equinix Metal VLAN is really just an abitrarily large isolated broadcast domain, not a real switched network. By default, there are no switches or routers presented inside a customers VLAN which could acts as IGMP routing or advertisement endpoints.

So this means an Equinix Metal (or hosted VM) instance inside of a VLAN can issue and send Multicast traffic, and that multicast traffic will be propogated to everything else in the broadcast domain, but there is no infrastructure for IGMP routing.

### BUM traffic

While not immediately related to Multicast / IGMP, it should be noted that Equinix Metal VLANs will drop or limit some [BUM](https://en.wikipedia.org/wiki/Broadcast,_unknown-unicast_and_multicast_traffic), in particular link level or layer messaging.
