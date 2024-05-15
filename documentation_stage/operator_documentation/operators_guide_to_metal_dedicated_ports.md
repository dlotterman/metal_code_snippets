# Operators Guide to Equinix Metal Dedicated Ports

[Equinix Metal's](https://deploy.equinix.com/) [Dedicated Ports](https://deploy.equinix.com/developers/docs/metal/interconnections/dedicated-ports/) feature is a powerful but potentially obtuse feature set.

This guide aims to quickly walk through them from an [Operator's](https://en.wikipedia.org/wiki/Computer_operator) perspective to highlight and nuances or potential bumps in the road an Operator may experience.

## TLDR: What are EM Dedicated Ports

When Equinix Metal builds out a Metro, it may spread compute pods over multiple Equinix IBX's within that Metro. However, within each Metro, there will be a primary Metal network POP, which may be in a different IBX than the Metal compute pods all together.

Take the Silicon Valley Metro as an example. EM has compute pods in SV15 and SV16, but it's primary network POP is in SV5, where the SV15 and SV16 compute pods connect back to that SV5 network POP.

In SV5, EM builds out a specific set of switching infrastructure and configurations to be able to receive physical cross-connects on behalf of it's customers, where those cross-connects (also referred to as x-conns) can be configured to carry EM customer networks. This is what Equinix Metal Dedicated Ports is. If a customer of Equinix Metal wanted to Interconnect with a network at a physical level, as long as that customer can extend that netwok sufficiently (local loops etc), they can connect to Equinix Metal via Dedicated Ports.

### TLDR Example

An Equinix Metal wants to connect their on-prem database to a new scale-able Kubernetes deployment on Equinix Metal.

The customers "on-prem" is a datacenter on their corporate campus in Fremont CA. They source a local-loop from a vendor from their facility in Fremont CA going to Equinix SV5. The customer orders a patch x-conn to go from the vendors POP to Equinix Metal within SV5, with Metal's side terminating in SMF-LC. The customer orders Metal Dedicated Ports which will be the termination point for the SMF-LC patch / extension that goes from vendor's POP to Equinix Metal.

It is worth noting that each of these widgets will have cost implications. EM Dedicated Ports service charge is for the ports and the ports alone, no intermediary solution services included.

## Equinix Metal Dedicated Port High Availability

Like most Equinix Metal Interconnection, it is best to read any references to "Redundant" as being more "Maintenance Diverse". When you select the "Redundant" option for Dedicated Ports, what that is really saying is "Place these connections on Maintenance Diverse paths that do not share fault domains".

There is no LACP or active high-availability on Equinix Metal Interconnection. EM gives you two seperate paths, it's up to the Operator to build high availability into their design from their.

Please see this write-up on achieving [High Availability with Equinix Metal Interconnection](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/virtual_circuit_availability/equinix_metal_fabric_vcs_availability.md).


## Ordering Steps for Equinix Metal Dedicated Ports

1. [Follow the guide for ordering ports here](https://deploy.equinix.com/developers/docs/metal/interconnections/dedicated-ports/)
	1. Once "ordered", a Equinix Metal Customer Success Engineer will reach out to you via email to verify details.
		1. If it helps, inform the EM CSE of your EM Sales, Solutions Architect and or TAM contacts.
		1. Once the details are verified, that EM CSE will then provide you (the customer) with an [LOA for the Metal network POP](https://deploy.equinix.com/developers/docs/metal/interconnections/dedicated-ports/#the-letter-of-authorization) where you can order an x-conn into
2. EM LOA in hand, you as the customer can place the order with the vendor on the other end of the x-conn.
	1. If you are connecting to your own Equinix Colocation, take the Metal LOA and [order a new x-conn via the portal](https://docs.equinix.com/en-us/Content/Interconnection/Cross_Connects/xc-Getting-started.htm) to your existing footprint.
	2. If you are connecting to a third party, similarly to above, take the EM LOA and [order a new x-conn via the portal](https://docs.equinix.com/en-us/Content/Interconnection/Cross_Connects/xc-Getting-started.htm) to your third party location.
	3. If you are connect to Equinix Fabric, [follow this guide](https://deploy.equinix.com/developers/docs/metal/interconnections/dedicated-ports-fabric/).
		1. Be sure to match the redudancy option for the Fabric ports that you ordered for Metal Ports.
	4. If you are connecting to an Equinix IX, we strongly suggest going through each of this steps in conjunction with your EM DTS SA
	5. Be sure to select correct and reachable contacts for the order. You will be send notifications by email you will need to forward to other Equinix teams in order to fulfill the order in a timely way.
	6. Forwarding any information you get to your Sales, Solutions Architect and TAM team may reduce future troubleshooting round-trip time.
3. With the patching x-conn ordered, wait for a notification / email of "Completion Notice". This completion notice will indicate from Equinix that the physical cable has been run between the specified points, and is ready for further turn-up.
	1. Forward this email to your Equinix Metal Customer Success Engineer who orignally validated your order. It is also likely a good idea to send this notification to any Sales, Solutions Architect or TAM team members you may have assigned to your account.
	2. Once notified, EM will proceed to finalize the ports configuration and turn-up on EM's side, once complete the other side of the connection can be turned up if it is not already.
		1. Without this step, the EM side of the x-conn will stay dark. EM requires x-conn completion notices in order to proceed to the port turn-up stage.
4. Complete turn up on the otherside of the x-conn
5. Return to the documentation of [Managing Dedicated Ports in the EM documentation](https://deploy.equinix.com/developers/docs/metal/interconnections/dedicated-ports/#managing-dedicated-ports)
