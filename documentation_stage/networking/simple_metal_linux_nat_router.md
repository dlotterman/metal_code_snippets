### Fun with Metal: A simple Metal Linux Internet Gateway / Router

There are times where an operator may want to launch [Metal](https://metal.equinix.com/) instances with OS's that should not be long lived on the public Internet. Windows, ESXi, Nutanix etc would all consider "best practice" to be deploying them in a non-public Internet facing network. At the same time, an Operator trying to work with those ecosystems might likely want outbound Internet access for tasks like pulling down images or patches or anything else. 

Especially for "brush clearing" labs or test deployments, this highlights a gap in Metal's networking features. While Metal offers incredible networking primitives for "at scale" production deployments, it doesn't have some of the guard rails features like a "NAT gateway as a service", where those gaps can make lab / trash deployments more cumbersome than they feel like they should be. Deploying VNF VM's is an option, but often even that is way more work than you want to dedicate to that role for labs like work. You don't **want** a router/firewall/vnf, you **just** want Internet access as easily as is safely possible.

A common character in these kinds of labs deployments is a Linux "Ops" or "Bastion" box, that can serve as a quick swiss army knife for a variety of roles. Turning a Linux "Ops box" into a quick NAT / router for other Metal instance's that should live on private networks is a breeze, as long as you don't need to worry about any kind of high availability requirements.

#### Sample commands

The below is intentionally Linux distro agnostic, and makes the instance available on the Metal [Layer-2](https://metal.equinix.com/developers/docs/layer2-networking/overview/) VLAN `2897` to other instances on that same network.

The VLAN `2897` needs to be attached to the instance in the Metal platform (GUI / API) before this.

```
[adminuser@router01 ~]# sudo ip link add link bond0 name bond0.2897 type vlan id 2897
[adminuser@router01 ~]# sudo ip addr add 10.16.16.1/24 dev bond0.2897
[adminuser@router01 ~]# sudo ip link set dev bond0.2897 up
[adminuser@router01 ~]# sudo echo 1 >> /proc/sys/net/ipv4/ip_forward
[adminuser@router01 ~]# sudo iptables -A INPUT -i lo -j ACCEPT
[adminuser@router01 ~]# sudo iptables -A INPUT -i bond0.2897 -j ACCEPT
[adminuser@router01 ~]# sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
[adminuser@router01 ~]# sudo iptables -t nat -A POSTROUTING -o bond0 -j MASQUERADE
[adminuser@router01 ~]# sudo iptables -A FORWARD -i bond0 -o bond0.2897 -m state --state RELATED,ESTABLISHED -j ACCEPT
[adminuser@router01 ~]# sudo iptables -A FORWARD -i bond0.2897 -o bond0 -j ACCEPT
```

The Linux box will now act as a primitive NAT / router, and any other instance in the `2897` VLAN can use `10.16.16.1` as it's default gateway without having to directly expose the instance to the public Internet.

It's important to note that this intentionally "preserves the bond", and this instance is presumed to be in ["Hybrid Bonded"](https://metal.equinix.com/developers/docs/layer2-networking/hybrid-bonded-mode/) network mode. Also the VLAN `2897` needs to be attached to the instance in the Metal platform (GUI / API) as well.

#### Cloud-init for extra security flavor

I love cloud-init, it's an incredible brush clearing automation tool. For any distro I commonly launch, I try to maintain [a list of basic cloud-init's](https://github.com/dlotterman/metal_code_snippets/tree/main/boiler_plate_cloud_inits) that do basic, sane operational tasks that I would consider best practices for any Internet facing host. With repeatable cloud-init's, where I can just copy and paste the same boilerplate every time without thinking, I can launch **secure-ish** Internet facing instances with some kind of confidence I won't be embarrassed with a drive by pwn. 

Those cloud-init's also help make this labs kind of work much easier, my `8021q` module is already loaded, my firewall is already turned up etc, I can focus on the work I want to do. Automation is important even in labs work.