# Operators Guide to Equinix Metal's BGP feature

*Operating Equinix Metal's BGP feature with FRR as an example*

---

One of the novel features of the Equinix Metal network is its customer facing BGP endpoints and integrations, allowing operators to tap into some valuable and powerful network control and announcement toolsets.

Best "code as documentation" resource:
- [Equinix-Metal-BGP Bird Toolkit](https://github.com/enkelprifti98/Equinix-Metal-BGP)

Some excellent other documentation here:
- [Equinix Metal BGP Documentation](https://metal.equinix.com/developers/docs/bgp/bgp-on-equinix-metal/)
- [Equinix Metal Local BGP Documnetation](https://metal.equinix.com/developers/docs/bgp/local-bgp/)
- [Equinix Metal Global BGP Documentation](https://metal.equinix.com/developers/docs/bgp/global-bgp/)
- [Equinix Metal Terraform BGP Resource](https://registry.terraform.io/providers/equinix/metal/latest/docs/resources/bgp_session)
- [Load Balancing on Equinix Metal with BGP](https://metal.equinix.com/developers/guides/load-balancing-ha/)
- [Metal Partner Page for IPXO](https://metal.equinix.com/ecosystem/partners/ipxo-on-equinix-metal/)
- [Youtube guide on using IPXO leased blocks with Equinix Metal](https://www.youtube.com/watch?v=xeqkrJLWZFQ)
- [Equinix Metal + MetalLB for k8s](https://metallb.universe.tf/installation/clouds/#metallb-on-equinix-metal)

## Setup context:

This document aims to provide a more generalized context from existing documentation about the feature, and specifically, how to drive it as an operator. While linux is used as the lingua franca, it should apply to any network-intelligent OS or appliance.

When discussing operating the [Equinix Metal network](https://metal.equinix.com/developers/docs/networking/), I always like to clarify if we are operating in it's Layer-3 OR/AND [Layer-2](https://metal.equinix.com/developers/docs/layer2-networking/overview/) network namespaces, as being specific helps eliminate a lot of subject domain overlap and confusion. In this post, *everything* I am referring to is in the Equinix Metal [Layer-3 namespace](https://metal.equinix.com/developers/docs/networking/ip-addresses/). All BGP functionality with the Equinix Metal network happens over its native, un-VLAN'ed Layer-3 network. Any documentation that references BGP and VLANs is likely referring to an Interconnection (Metal <-> AWS for example) solution design, which is explicitly not in any way relevant to peering with Equinix Metal directly as is being discussed here.

It's also important to note that as of the time of this writing, the customer facing BGP interfaces do not allow for the management of Equinix Metal's [Anycast IP](https://metal.equinix.com/developers/docs/networking/global-anycast-ips/) functionality. That functionality, which is a sort of multi-tenant "Global Anycast As A Service" feature, is self contained and is implemented at a part of the stack not currently integrated with the downstream customer BGP mesh. Simply put, you cannot BGP control Metal owned Anycast IPs (but confusingly enough you can use BGP to BYO Anycast network with your own BYOIP space).

The Equinix Metal Layer-3 network is a [routed mesh](https://metal.equinix.com/blog/how-equinix-metal-is-bringing-cloud-networking-to-bare-metal-servers/), where an operators Metal instances get IP blocks allocated to their instance that are directly routed in that mesh, that is to say no NAT or anything like that. When your Equinix Metal instance is assigned `145.40.76.240/31`, that `/31` is part of a fully routed block where the distribution of blocks and routes is orchestrated by the Equinix Metal platform and internally controlled via BGP.

## What the feature is:

What the Equinix Metal BGP feature does is expose a direct BGP interface into the customers network, allowing a BGP speaker on customer's compute instances to inform the network around it about its own routing ideas and state. That BGP interface is hosted via the magic of Top of Rack orchestration, where every [BGP enabled instance](https://metal.equinix.com/developers/docs/bgp/local-bgp/#creating-local-bgp-sessions) is presented with a local network BGP neighbor hosted by that instance's Top of Rack switch. When an instance is enabled for BGP, that BGP endpoint is enabled on that instance ToR, and the ToR will distribute any valid and safe BGP routing advertisements to the rest of the network around it.

## Uses:

This BGP feature functionality enables a couple of key use cases:

### Realtime management of ElasticIPs:

Equinix Metal provides "table stakes" [ElasticIP](https://metal.equinix.com/developers/docs/networking/elastic-ips/) functionality, where specific IPs of specific blocks can be assigned to instance's for all the cloudy reasons an operator would normally do so. ElasticIPs can be managed through the usual interfaces, API or GUI, but in Metal, they can also be managed via BGP, allowing Metal instances acting as BGP speakers to dynamically move ElasticIPs around in near real time, without having to wait for API calls and host re-configuration. There are great reasons to do this.
- One of my personal favorites, is using Metal Private IP's as ElasticIPs for internal control plane management.

This functionality falls within the scope of the ["Local BGP"](https://metal.equinix.com/developers/docs/bgp/local-bgp/) sub-feature of BGP, where an operators intent is to control the  Metal Layer-3 network within the local scope of a [Metro](https://metal.equinix.com/developers/docs/locations/metros/).

### BYOIP:

Equinix Metal allows customers to bring their own IP's via its BGP functionality. Through the ["Global BGP"](https://metal.equinix.com/developers/docs/bgp/global-bgp/) sub-feature, customers can announce their own fully route-able public IP space (/24 or larger for IPv4). When a public block is announced from an Equinix Metal instance to its BGP neighbor ToR, the ToR will distribute that announcement up to the Metal Layer-3 mesh, and then on to its various upstream providers and the IX, thus propagating the announcement to the broader public Internet.

### Legacy vs Current clarifications:

Prior to its acquisition by [Equinix in 2020](https://www.equinix.com/newsroom/press-releases/2020/03/equinix-completes-acquisition-of-bare-metal-leader-packet), the platform currently known as Metal was developed and operated by a startup called ["Packet"](https://www.crunchbase.com/organization/packet-host). The BGP feature was initially released and documented prior to the acquisition, where after the acquisition some substantive advancements in its network infrastructure altered the BGP featureset in some discrete ways.

The effect of this is that at the time of this writing:

- There are two different kinds of Equinix Metal sites, [Legacy](https://metal.equinix.com/developers/docs/locations/facilities/#legacy-facility-sites) and IBX (IBX being Equinix's naming convention for its data centers), where there are some subtle technical implementation differences in the BGP feature depending on weather it's in the scope of a Legacy facility vs IBX facility.
    - The key differentiator between the two is that in Legacy sites, the IP of the instance's BGP neighbor is the Metal Private network Gateway for the instance. In an IBX facility, the IP of servers BGP neighbor will always be a pair of pre-defined [peer_ips](https://metal.equinix.com/developers/docs/bgp/bgp-on-equinix-metal/#bgp-metadata) (`169.254.255.1/32`,`169.254.255.2/32`).

So to clarify, if you are reading documentation where the BGP neighbor is a private `10.0.0.0/8` address, that documentation is **stale or old**, and is referencing the Legacy implementation. That documentation is likely 90% otherwise accurate, but some details, in particular the IPs of the BGP endpoints, will be incorrect and will **NOT** work in IBX facilities.

## So how do you actually drive it:

The customer facing BGP endpoint is hosted on an instance’s ToR, always on the pre-defined `169.254.255.1/32`,`169.254.255.2/32` Peer IPs, which are [link-local](https://en.wikipedia.org/wiki/Link-local_address) IPs.

Those peering IP's expect to be reached via the [Metal Private network](https://metal.equinix.com/developers/docs/networking/ip-addresses/#private-ipv4-management-subnets), **NOT** the [Metal Public Network](https://metal.equinix.com/developers/docs/networking/ip-addresses/#public-ipv4-subnet). To be clear, that means you must peer via your instances `10.0.0.0/8` IP address, not via its Public IP address (for example `145.40.76.240/28`).

In the case of Linux networking and software routing, there are some differences in behavior between different ecosystems.

On a default Metal Linux instance, this would look like:

- `ip route add 169.254.255.1/32 via 10.70.114.145`
- `ip route add 169.254.255.2/32 via 10.70.114.145`

Where `10.70.114.145` is the gateway IP for the instance's Metal [Private Network](https://metal.equinix.com/developers/docs/networking/ip-addresses/#private-ipv4-management-subnets).

### Bird

In the Bird `1.X` config:

```
protocol static {
  route 169.254.255.1/32 via 10.70.114.145;
  route 169.254.255.2/32 via 10.70.114.145;
}
```

In the Bird `2.X` config scheme, there is no need for this static route specificity int the config,

An example complete Bird `2.X` config, generated from [Equinix-Metal-BGP](https://github.com/enkelprifti98/Equinix-Metal-BGP) is printed below in this document

Handy Bird documentation:
- https://blog.kintone.io/entry/bird
- https://www.datapacket.com/blog/bird-bgp-configuration

### Adding IP's to the announce
The easiest way to configure a Linux instance to announce an [ElasticIP](https://metal.equinix.com/developers/docs/networking/elastic-ips/) address or BYO-IP block is to mount the IP block on the loopback interface, and then use your BGP speaker's equivalent of ["redistribute connected"](https://docs.frrouting.org/en/stable-7.5/bgp.html#redistribution) to have the BGP speaker announce all of the IP's and networks assigned to Linux interfaces (including loopback). For example to have the Linux instance announce a registered ElasticIP block of `145.40.76.241/28`:

`ip addr add 145.40.76.241/28 dev lo:0`

This will be registered as a "connected" network in your BGP speaker's configuration and redistribute that network into its BGP table.

The operator can then configure a BGP speaker of choice ([FRR](https://frrouting.org/), [Bird](https://bird.network.cz/), [GoBGP](https://github.com/osrg/gobgp) to interface with the [Peer IPs](https://metal.equinix.com/developers/docs/bgp/bgp-on-equinix-metal/#routing-overview).

Quick reminders from official documentation:
- The Equinix Metal network will always participate as AS `65530`.
- You can get [BGP information from the Equinix Metal Metadata API](https://metal.equinix.com/developers/docs/bgp/bgp-on-equinix-metal/#bgp-metadata)


### Example FRR configuration for reference:

```
# default to using syslog. /etc/rsyslog.d/45-frr.conf places the log
# in /var/log/frr/frr.log
log syslog informational
frr defaults traditional
service integrated-vtysh-config
!
ip router-id 10.70.114.146
!
router bgp 65000
 bgp log-neighbor-changes
 bgp router-id 10.70.114.146
 no bgp network import-check
 no bgp ebgp-requires-policy
 neighbor MetalBGP peer-group
 neighbor MetalBGP remote-as 65530
 neighbor MetalBGP ebgp-multihop 5
 neighbor MetalBGP password Equinixmetal05
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
- This example config has a wide open route-map. This should not be used in production as it can easily have FRR do things an operator wouldnt want, but is also by far the easiest to use to get "FRR working in the first place"
    - Operators should go to production with a more specific route and prefix list structure.
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

#### FRR Output examples

```
2# show ip route
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, D - SHARP,
       F - PBR, f - OpenFabric,
       > - selected route, * - FIB route, q - queued route, r - rejected route

K>* 0.0.0.0/0 [0/0] via 147.28.143.193, enp1s0, 00:06:24
K>* 10.0.0.0/8 [0/0] via 10.70.114.145, enp1s0, 00:06:24
C>* 10.70.114.144/29 is directly connected, enp1s0, 00:06:24
C>* 145.40.76.240/28 is directly connected, lo, 00:06:24
C>* 147.28.143.192/29 is directly connected, enp1s0, 00:06:24
K>* 169.254.255.1/32 [0/0] via 10.70.114.145, enp1s0, 00:06:24
K>* 169.254.255.2/32 [0/0] via 10.70.114.145, enp1s0, 00:06:24
```

```
# show bgp ipv4
BGP table version is 3, local router ID is 10.70.114.146, vrf id 0
Default local pref 100, local AS 65000
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.70.114.144/29 0.0.0.0                  0         32768 ?
*> 145.40.76.240/28 0.0.0.0                  0         32768 ?
*> 147.28.143.192/29
                    0.0.0.0                  0         32768 ?

Displayed  3 routes and 3 total paths
```

```
# show bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.70.114.146, local AS number 65000 vrf-id 0
BGP table version 3
RIB entries 5, using 920 bytes of memory
Peers 2, using 41 KiB of memory
Peer groups 1, using 64 bytes of memory

Neighbor        V         AS MsgRcvd MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd
169.254.255.1   4      65530       4       6        0    0    0 00:00:24            0
169.254.255.2   4      65530       4       6        0    0    0 00:00:24            0

Total number of neighbors 2
```

```
# show bgp neighbors
BGP neighbor is 169.254.255.1, remote AS 65530, local AS 65000, external link
 Member of peer-group MetalBGP for session parameters
  BGP version 4, remote router ID 145.40.76.80, local router ID 10.70.114.146
  BGP state = Established, up for 00:01:57
  Last read 00:00:19, Last write 00:00:57
  Hold time is 180, keepalive interval is 60 seconds
  Neighbor capabilities:
    4 Byte AS: advertised and received
    AddPath:
      IPv4 Unicast: RX advertised IPv4 Unicast and received
    Route refresh: advertised and received(new)
    Address Family IPv4 Unicast: advertised and received
    Hostname Capability: advertised (name: ubuntu02,domain name: n/a) not received
    Graceful Restart Capabilty: advertised and received
      Remote Restart timer is 300 seconds
      Address families by peer:
        none
  Graceful restart information:
    End-of-RIB send: IPv4 Unicast
    End-of-RIB received: IPv4 Unicast
  Message statistics:
    Inq depth is 0
    Outq depth is 0
                         Sent       Rcvd
    Opens:                  1          1
    Notifications:          0          0
    Updates:                3          1
    Keepalives:             2          4
    Route Refresh:          1          0
    Capability:             0          0
    Total:                  7          6
  Minimum time between advertisement runs is 0 seconds

 For address family: IPv4 Unicast
  MetalBGP peer-group member
  Update group 1, subgroup 1
  Packet Queue length 0
  Community attribute sent to this neighbor(large)
  Inbound path policy configured
  Outbound path policy configured
  Route map for incoming advertisements is *ALLOW-ALL
  Route map for outgoing advertisements is *ALLOW-ALL
  0 accepted prefixes

  Connections established 1; dropped 0
  Last reset 00:01:58,   Waiting for NHT
  External BGP neighbor may be up to 5 hops away.
Local host: 10.70.114.146, Local port: 48592
Foreign host: 169.254.255.1, Foreign port: 179
Nexthop: 10.70.114.146
Nexthop global: fe80::5054:ff:fe1b:9c65
Nexthop local: fe80::5054:ff:fe1b:9c65
BGP connection: non shared network
BGP Connect Retry Timer in Seconds: 120
Peer Authentication Enabled
Read thread: on  Write thread: on  FD used: 23

BGP neighbor is 169.254.255.2, remote AS 65530, local AS 65000, external link
 Member of peer-group MetalBGP for session parameters
  BGP version 4, remote router ID 145.40.76.81, local router ID 10.70.114.146
  BGP state = Established, up for 00:01:57
  Last read 00:00:10, Last write 00:00:57
  Hold time is 180, keepalive interval is 60 seconds
  Neighbor capabilities:
    4 Byte AS: advertised and received
    AddPath:
      IPv4 Unicast: RX advertised IPv4 Unicast and received
    Route refresh: advertised and received(new)
    Address Family IPv4 Unicast: advertised and received
    Hostname Capability: advertised (name: ubuntu02,domain name: n/a) not received
    Graceful Restart Capabilty: advertised and received
      Remote Restart timer is 300 seconds
      Address families by peer:
        none
  Graceful restart information:
    End-of-RIB send: IPv4 Unicast
    End-of-RIB received: IPv4 Unicast
  Message statistics:
    Inq depth is 0
    Outq depth is 0
                         Sent       Rcvd
    Opens:                  1          1
    Notifications:          0          0
    Updates:                3          1
    Keepalives:             2          4
    Route Refresh:          1          0
    Capability:             0          0
    Total:                  7          6
  Minimum time between advertisement runs is 0 seconds

 For address family: IPv4 Unicast
  MetalBGP peer-group member
  Update group 1, subgroup 1
  Packet Queue length 0
  Community attribute sent to this neighbor(large)
  Inbound path policy configured
  Outbound path policy configured
  Route map for incoming advertisements is *ALLOW-ALL
  Route map for outgoing advertisements is *ALLOW-ALL
  0 accepted prefixes

  Connections established 1; dropped 0
  Last reset 00:01:58,   Waiting for NHT
  External BGP neighbor may be up to 5 hops away.
Local host: 10.70.114.146, Local port: 37034
Foreign host: 169.254.255.2, Foreign port: 179
Nexthop: 10.70.114.146
Nexthop global: fe80::5054:ff:fe1b:9c65
Nexthop local: fe80::5054:ff:fe1b:9c65
BGP connection: non shared network
BGP Connect Retry Timer in Seconds: 120
Peer Authentication Enabled
Read thread: on  Write thread: on  FD used: 24
```
#### Bird example config

```
filter equinix_metal_bgp {
  accept;
}

router id YOUR.PRIVATE.IP.HERE;

protocol direct {
  ipv4;
  interface "lo";
}

protocol kernel {
  merge paths;
  persist;
  scan time 20;
  ipv4 {
    import all;
    export all;
  };
}

protocol device {
  scan time 10;
}

protocol bgp Equinix_Metal_1 {
    ipv4 {
      export filter equinix_metal_bgp;
      import filter equinix_metal_bgp;
    };
    graceful restart;
    local as 65000;
    neighbor 169.254.255.1 as 65530;
    password "YOURPASSWORDHERE";
    multihop 4;
}
protocol bgp Equinix_Metal_2 {
    ipv4 {
      export filter equinix_metal_bgp;
      import filter equinix_metal_bgp;
    };
    graceful restart;
    local as 65000;
    neighbor 169.254.255.2 as 65530;
    password "YOURPASSWORDHERE";
    multihop 4;
}
```


#### Bird output examples
```
bird> show protocols
Name       Proto      Table      State  Since         Info
direct1    Direct     ---        up     17:21:40.286
kernel1    Kernel     master4    up     17:21:40.286
device1    Device     ---        up     17:21:40.286
Equinix_Metal_1 BGP        ---        up     17:21:45.195  Established
Equinix_Metal_2 BGP        ---        up     17:21:44.376  Established
```

```
bird> show protocols all Equinix_Metal_1
Name       Proto      Table      State  Since         Info
Equinix_Metal_1 BGP        ---        up     17:21:45.195  Established
  BGP state:          Established
    Neighbor address: 169.254.255.1
    Neighbor AS:      65530
    Local AS:         65000
    Neighbor ID:      136.144.54.16
    Local capabilities
      Multiprotocol
        AF announced: ipv4
      Route refresh
      Graceful restart
        Restart time: 120
        AF supported: ipv4
        AF preserved:
      4-octet AS numbers
      Enhanced refresh
      Long-lived graceful restart
    Neighbor capabilities
      Multiprotocol
        AF announced: ipv4
      Route refresh
      Graceful restart
      4-octet AS numbers
      ADD-PATH
        RX: ipv4
        TX:
      Enhanced refresh
    Session:          external multihop AS4
    Source address:   10.67.63.5
    Hold timer:       139.897/180
    Keepalive timer:  21.217/60
  Channel ipv4
    State:          UP
    Table:          master4
    Preference:     100
    Input filter:   equinix_metal_bgp
    Output filter:  equinix_metal_bgp
    Routes:         0 imported, 1 exported, 0 preferred
    Route change stats:     received   rejected   filtered    ignored   accepted
      Import updates:              0          0          0          0          0
      Import withdraws:            0          0        ---          0          0
      Export updates:              1          0          0        ---          1
      Export withdraws:            0        ---        ---        ---          0
    BGP Next hop:   10.67.63.5
    IGP IPv4 table: master4
```

```
bird> show protocols all
Name       Proto      Table      State  Since         Info
direct1    Direct     ---        up     17:21:40.286
  Channel ipv4
    State:          UP
    Table:          master4
    Preference:     240
    Input filter:   ACCEPT
    Output filter:  REJECT
    Routes:         1 imported, 0 exported, 1 preferred
    Route change stats:     received   rejected   filtered    ignored   accepted
      Import updates:              1          0          0          0          1
      Import withdraws:            0          0        ---          0          0
      Export updates:              0          0          0        ---          0
      Export withdraws:            0        ---        ---        ---          0

kernel1    Kernel     master4    up     17:21:40.286
  Channel ipv4
    State:          UP
    Table:          master4
    Preference:     10
    Input filter:   ACCEPT
    Output filter:  ACCEPT
    Routes:         0 imported, 1 exported, 0 preferred
    Route change stats:     received   rejected   filtered    ignored   accepted
      Import updates:              0          0          0          0          0
      Import withdraws:            0          0        ---          0          0
      Export updates:              1          0          0        ---          1
      Export withdraws:            0        ---        ---        ---          0

device1    Device     ---        up     17:21:40.286

Equinix_Metal_1 BGP        ---        up     17:21:45.195  Established
  BGP state:          Established
    Neighbor address: 169.254.255.1
    Neighbor AS:      65530
    Local AS:         65000
    Neighbor ID:      136.144.54.16
    Local capabilities
      Multiprotocol
        AF announced: ipv4
      Route refresh
      Graceful restart
        Restart time: 120
        AF supported: ipv4
        AF preserved:
      4-octet AS numbers
      Enhanced refresh
      Long-lived graceful restart
    Neighbor capabilities
      Multiprotocol
        AF announced: ipv4
      Route refresh
      Graceful restart
      4-octet AS numbers
      ADD-PATH
        RX: ipv4
        TX:
      Enhanced refresh
    Session:          external multihop AS4
    Source address:   10.67.63.5
    Hold timer:       139.130/180
    Keepalive timer:  12.180/60
  Channel ipv4
    State:          UP
    Table:          master4
    Preference:     100
    Input filter:   equinix_metal_bgp
    Output filter:  equinix_metal_bgp
    Routes:         0 imported, 1 exported, 0 preferred
    Route change stats:     received   rejected   filtered    ignored   accepted
      Import updates:              0          0          0          0          0
      Import withdraws:            0          0        ---          0          0
      Export updates:              1          0          0        ---          1
      Export withdraws:            0        ---        ---        ---          0
    BGP Next hop:   10.67.63.5
    IGP IPv4 table: master4

Equinix_Metal_2 BGP        ---        up     17:21:44.376  Established
  BGP state:          Established
    Neighbor address: 169.254.255.2
    Neighbor AS:      65530
    Local AS:         65000
    Neighbor ID:      136.144.54.17
    Local capabilities
      Multiprotocol
        AF announced: ipv4
      Route refresh
      Graceful restart
        Restart time: 120
        AF supported: ipv4
        AF preserved:
      4-octet AS numbers
      Enhanced refresh
      Long-lived graceful restart
    Neighbor capabilities
      Multiprotocol
        AF announced: ipv4
      Route refresh
      Graceful restart
      4-octet AS numbers
      ADD-PATH
        RX: ipv4
        TX:
      Enhanced refresh
    Session:          external multihop AS4
    Source address:   10.67.63.5
    Hold timer:       111.183/180
    Keepalive timer:  51.778/60
  Channel ipv4
    State:          UP
    Table:          master4
    Preference:     100
    Input filter:   equinix_metal_bgp
    Output filter:  equinix_metal_bgp
    Routes:         0 imported, 1 exported, 0 preferred
    Route change stats:     received   rejected   filtered    ignored   accepted
      Import updates:              0          0          0          0          0
      Import withdraws:            0          0        ---          0          0
      Export updates:              1          0          0        ---          1
      Export withdraws:            0        ---        ---        ---          0
    BGP Next hop:   10.67.63.5
    IGP IPv4 table: master4
```
