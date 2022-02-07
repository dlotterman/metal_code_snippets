## Moving the ESXi Management IP to a Metal Layer-2 VLAN Interface

**Disclaimer**: This document is **NOT** an official document, and is not supported by Equinix Metal. It is here for reference / convenience. 

When Equinix Metal instances are deployed with ESXi, by default the ESXi "management" interface, as in the IP address that is used to bind the management services (console, SSH etc), is assigned to the Equinix Metal provided Layer-3 IP addresses (by default Public IP, if not Public then Management). 

The following steps allow an operator to move that management interface to a Metal VLAN interface.

This guide makes the following assumptions where you can make changes or substitutions as relevant for your deployment.

* Layer-3 Networks:
	* Metal Public: `147.28.150.96/29`	
	* Metal Private: `10.68.93.184/29`
	* Operator Management Network: `172.16.10.15/24`
		* Where Operator has gateway in that network assigned to IP: `172.16.10.1/24`
* VLANS: Operator has two VLANs provisioned in Metal for the correct Metro. This guide assumes VLAN ID `1000` & `1001` where VLAN `1000` is the correct Layer-2 VLAN for the Operator Management Network `172.16.10.0/24`, and `1001` is here as the second VLAN that will be unconfigured on the host itself.
* SSH Keys: [That the customer has correctly configured SSH keys in the Equinix Metal platform](https://metal.equinix.com/developers/docs/accounts/ssh-keys/)

### Using Metal Gateways for network connectivity

This document does not address the use of [Metal's Gateway](https://metal.equinix.com/developers/docs/networking/metal-gateway/) feature as another vector for management access, though there may be very good reasons to do so. While the use of a Metal Gateway may be the preferred path, the reasons for / agaisnt fall outside the scope of this document and will not be addressed. For questions about the usage of Equinix Metal Gateway instances, please consult with your Equinix Metal sales and support team.

### Configuring the Equinix Metal instance in the Equinix Metal platform (Console / GUI)

#### Configuring the Metal Instance for Unbonded Layer-2 aware modes

[This section is convered by the Metal "Hybrid Unbonded" documentation visible here](https://metal.equinix.com/developers/docs/layer2-networking/hybrid-unbonded-mode/): 

1) Find the newly provisioned ESXi instance and load it's details page
2) Under the "Network" details page where "Network" is visible on the lefthand side page selection bar:
	1) Click the blue "Convert to Other Network Type" button
	2) Select `Hybrid` or `Layer-2` depending on your design, this guide assumes Hybrid
	3) Select `Unbonded`, as we are working with a currently unlicensed ESXi instance, LACP is unavailable to us so the switch bond must be broken.
		* **If the reasoning behind breaking the bond / interaction with LACP is not understood, please reach out to your Equinix Metal sales and support team as this requires substantial contextual understanding**
	4) Click the "Convert to Hybrid Networking" button at the bottom of the side panel
	5) The Metal instances switch ports will now be converted to Hybrid Unbonded mode
3) Once complete, the blue "+ Add New Vlan" button should be visible in the lower right hand side
	1) Add your first VLAN to the `eth1` interface (this represent the second physical interface of the box, for `n2.xlarge.x86` instances this would likely be `eth3`)
	2) Add a second VLAN to the `eth1` interface. The reasoning for this is it enforces `802.1q` tagging all the way to the host. 
4) Connect to the "Out-of-band console", [the details for which should be exposed by a clickable button at the top of the instances details page](https://metal.equinix.com/developers/docs/resilience-recovery/serial-over-ssh/)
	* It is strongly recommended to ensure your SSH / terminal client is sized for *at least* 80x pixels wide by 25x pixels tall. It may be useful for operator sanity to have your terminal be signifincalty larger than that.
5) Once connected to the console, you may need to press enter or other keystroke to be presented with the output from the VMWare mangement text interface:
```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x       VMware ESXi 6.7.0 (VMKernel Release Build 16713306)                    x
x                                                                              x
x       Dell Inc. PowerEdge R6515                                              x
x                                                                              x
x       AMD EPYC 7402P 24-Core Processor                                       x
x       63.6 GiB Memory                                                        x
x                                                                              x
x                                                                              x
x       To manage this host go to:                                             x
x       http://dc-c3-medium-x86-01/                                            x
x       http://147.28.150.98/ (STATIC)                                         x
x       http://[2604:1380:45f1:a400::13]/ (STATIC)                             x
x       http://[fe80::42a6:b7ff:fe5f:dc90]/ (STATIC)                           x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x <F2> Customize System/View Logs                      <F12> Shut Down/Restart x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj

```
6) Send an `F2` keystroke to bring up the authentication prompt (not OSX / Macbook users may need to identify how to properly send an `F2` keystroke.
7) Leave `root` as the user and enter the password from the Equnix Metal's details page where the root user password should still be available and hit enter:
```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x       VMlqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk         x
x         x  Authentication Required                                 x         x
x       Dex                                                          x         x
x         x  Enter an authorized login name and password for         x         x
x       AMx  dc-c3-medium-x86-01..                                   x         x
x       63x                                                          x         x
x         x                                                          x         x
x         x  Login Name:        [ root                           ]   x         x
x       Tox  Password:          [ **********                     ]   x         x
x       htx                                                          x         x
x       htx                                                          x         x
x       htx                                 <Enter> OK  <Esc> Cancel x         x
x       htmqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj         x
x                                                                              x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
```
8) You should be greeted with a list of management options available in this interface:
```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x  System Customization                   Configure Password                   x
xqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqx
x                                                                              x
x  Configure Password                     Set                                  x
x  Configure Lockdown Mode                                                     x
x                                         To prevent unauthorized access to    x
x  Configure Management Network           this system, set the password for    x
x  Restart Management Network             the user.                            x
x  Test Management Network                                                     x
x  Network Restore Options                                                     x
x                                                                              x
x  Troubleshooting Options                                                     x
x                                                                              x
x  View System Logs                                                            x
x                                                                              x
x  View Support Information                                                    x
x                                                                              x
x  Reset System Configuration                                                  x
x                                                                              x
x                                                                              x
x                                        <Enter> Change          <Esc> Log Out x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)
	
```
9) Use the arrow keys to select `Configure Management Network` and hit enter:
```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x  Configure Management Network           Network Adapters                     x
xqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqx
x                                                                              x
x  Network Adapters                       vmnic0 (PCIe Slot 3)                 x
x  VLAN (optional)                                                             x
x                                         The adapters listed here provide the x
x  IPv4 Configuration                     default network connection to and    x
x  IPv6 Configuration                     from this host. When two or more     x
x  DNS Configuration                      adapters are used, connections will  x
x  Custom DNS Suffixes                    be fault-tolerant and outgoing       x
x                                         traffic will be load-balanced.       x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x                                                                              x
x <Up/Down> Select                       <Enter> Change             <Esc> Exit x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)
```
10) Select "Network Adapters" and hit enter
```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
xlqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx
xx  Network Adapters                                                          xx
xx                                                                            xx
xx  Select the adapters for this host's default management network            xx
xx  connection. Use two or more adapters for fault-tolerance and              xx
xx  load-balancing.                                                           xx
xx                                                                            xx
xx                                                                            xx
xx      Device Name  Hardware Label (MAC Address)  Status                     xx
xx  [X] vmnic0       PCIe Slot 3 (...b7:5f:dc:90)  Connected (...)            xx
xx  [ ] vmnic1       PCIe Slot 3 (...b7:5f:dc:91)  Connected                  xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx <D> View Details  <Space> Toggle Selected         <Enter> OK  <Esc> Cancel xx
xmqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqjx
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)
```
11) Unselect "vmnic0", and select "vmnic1" and hit enter:
```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
xlqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx
xx  Network Adapters                                                          xx
xx                                                                            xx
xx  Select the adapters for this host's default management network            xx
xx  connection. Use two or more adapters for fault-tolerance and              xx
xx  load-balancing.                                                           xx
xx                                                                            xx
xx                                                                            xx
xx      Device Name  Hardware Label (MAC Address)  Status                     xx
xx  [ ] vmnic0       PCIe Slot 3 (...b7:5f:dc:90)  Connected (...)            xx
xx  [X] vmnic1       PCIe Slot 3 (...b7:5f:dc:91)  Connected                  xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx                                                                            xx
xx <D> View Details  <Space> Toggle Selected         <Enter> OK  <Esc> Cancel xx
xmqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqjx
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)

```
12) Select `VLAN (Optional)` and enter in the Management VLAN, where we earlier in this guide declared VLAN `1000` as our management VLAN, this should be substitured for the Operators if different from this guide, and hit enter:
```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x  Configure Management Network           VLAN (optional)                      x
xqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqx
x                                                                              x
x  Network Adapters                       Not set                              x
x  VLAN (optional)                                                             x
x    lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkn a x
x  IPx  VLAN (optional)                                                   x    x
x  IPx                                                                    x    x
x  DNx  If you are unsure how to configure or use a VLAN, it is safe to   x    x
x  Cux  leave this option unset.                                          x    x
x    x                                                                    x    x
x    x                                                                    x    x
x    x  VLAN ID (1-4094, or 4095 to access all VLANs):        [ 1000  ]   xl   x
x    x                                                                    x    x
x    x                                                                    x    x
x    x                                           <Enter> OK  <Esc> Cancel xe   x
x    mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqje   x
x                                         this option unset.                   x
x                                                                              x
x                                                                              x
x <Up/Down> Select                       <Enter> Change             <Esc> Exit x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)
```
13) Use the arrows to select `IPv4 Configuration` and press enter:

We are initially greeted with the IPv4 information being loaded that is present for the Layer-3 information assigned by Equinix Metal:
```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x  Configure Management Network           IPv4 Configuration                   x
xlqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx
xx  IPv4 Configuration                                                        xx
xx                                                                            xx
xx  This host can obtain network settings automatically if your network       xx
xx  includes a DHCP server. If it does not, the following settings must be    xx
xx  specified:                                                                xx
xx                                                                            xx
xx                                                                            xx
xx  ( ) Disable IPv4 configuration for management network                     xx
xx  ( ) Use dynamic IPv4 address and network configuration                    xx
xx  (o) Set static IPv4 address and network configuration:                    xx
xx                                                                            xx
xx  IPv4 Address                                       [ 147.28.150.98    ]   xx
xx  Subnet Mask                                        [ 255.255.255.248  ]   xx
xx  Default Gateway                                    [ 147.28.150.97    ]   xx
xx                                                                            xx
xx                                                                            xx
xx <Up/Down> Select  <Space> Mark Selected           <Enter> OK  <Esc> Cancel xx
xmqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqjx
x <Up/Down> Select                       <Enter> Change             <Esc> Exit x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)
```

Reconfigure this to reflect the information we collected previously for our management network, in this document this is `172.16.10.15/24`

```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x  Configure Management Network           IPv4 Configuration                   x
xlqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx
xx  IPv4 Configuration                                                        xx
xx                                                                            xx
xx  This host can obtain network settings automatically if your network       xx
xx  includes a DHCP server. If it does not, the following settings must be    xx
xx  specified:                                                                xx
xx                                                                            xx
xx                                                                            xx
xx  ( ) Disable IPv4 configuration for management network                     xx
xx  ( ) Use dynamic IPv4 address and network configuration                    xx
xx  (o) Set static IPv4 address and network configuration:                    xx
xx                                                                            xx
xx  IPv4 Address                                       [ 172.16.10.15     ]   xx
xx  Subnet Mask                                        [ 255.255.255.0    ]   xx
xx  Default Gateway                                    [ 172.16.10.1      ]   xx
xx                                                                            xx
xx                                                                            xx
xx <Up/Down> Select  <Space> Mark Selected           <Enter> OK  <Esc> Cancel xx
xmqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqjx
x <Up/Down> Select                       <Enter> Change             <Esc> Exit x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)
```

Similar steps can be used to re-configure any DNS that may be needed in the new management network.

When done, the Operator should be at the general management network configuration screen:

```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x  Configure Management Network           IPv6 Configuration                   x
xqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqx
x                                                                              x
x  Network Adapters                       IPv6 is enabled.                     x
x  VLAN (optional)                                                             x
x                                         Automatic                            x
x  IPv4 Configuration                                                          x
x  IPv6 Configuration                     IPv6 Addresses:                      x
x  DNS Configuration                      fe80::42a6:b7ff:fe5f:dc90/64         x
x  Custom DNS Suffixes                    2604:1380:45f1:a400::13/127          x
x                                                                              x
x                                         Default Gateway:                     x
x                                         fe80::400:deff:fead:beef%vmk1        x
x                                                                              x
x                                         This host can obtain IPv6 addresses  x
x                                         and other networking parameters      x
x                                         automatically if your network        x
x                                         includes a DHCPv6 server or supports x
x                                         Router Advertisement.                x
x                                                                              x
x <Up/Down> Select                       <Enter> Change             <Esc> Exit x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)
```

When `esc` or the escape key is pressed from this context, the Operator should be greeted by a prompt to restart the ESXi management network after being re-configured:

```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x  Configure Management Network           IPv6 Configuration                   x
xqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqx
x                                                                              x
x  Nelqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk    x
x  VLx  Configure Management Network: Confirm                             x    x
x    x                                                                    x    x
x  IPx  You have made changes to the host's management network.           x    x
x  IPx  Applying these changes may result in a brief network outage,      x    x
x  DNx  disconnect remote management software and affect running virtual  x    x
x  Cux  machines. In case IPv6 has been enabled or disabled this will     x    x
x    x  restart your host.                                                x    x
x    x                                                                    x    x
x    x                                                                    x    x
x    x   Apply changes and restart management network?                    x    x
x    x                                                                    xes  x
x    x                                                                    x    x
x    x <Y> Yes  <N> No                                       <Esc> Cancel x    x
x    mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqjrts x
x                                         Router Advertisement.                x
x                                                                              x
x <Up/Down> Select                       <Enter> Change             <Esc> Exit x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)
```

Press the `Y` key to apply the change, which should return the Operator to the main configuration screen for this interface:
```
lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk
x  System Customization                   Configure Management Network         x
xqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqx
x                                                                              x
x  Configure Password                     Hostname:                            x
x  Configure Lockdown Mode                dc-c3-medium-x86-01                  x
x                                                                              x
x  Configure Management Network           IPv4 Address:                        x
x  Restart Management Network             172.16.10.15                         x
x  Test Management Network                                                     x
x  Network Restore Options                IPv6 Addresses:                      x
x                                         fe80::42a6:b7ff:fe5f:dc91/64         x
x  Troubleshooting Options                2604:1380:45f1:a400::13/127          x
x                                                                              x
x  View System Logs                       To view or modify this host's        x
x                                         management network settings in       x
x  View Support Information               detail, press <Enter>.               x
x                                                                              x
x  Reset System Configuration                                                  x
x                                                                              x
x                                                                              x
x                                        <Enter> More            <Esc> Log Out x
mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj
               VMware ESXi 6.7.0 (VMKernel Release Build 16713306)
```

The new management interface should now be reachable over the VLAN, and should be reachable from anything else inside the Layer-2 VLAN including other Metal instances in the same VLAN or what ever may be on the other side of a Interconnect attached to that VLAN.
