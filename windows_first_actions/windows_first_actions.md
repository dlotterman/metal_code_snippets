---
layout: personal_windows_first_actions
title: Personal Windows "First Actions" for Equinix Metal
---

# Background

This document is intended to describe my personal "first actions" when launching an Equinix Metal instance with Windows 2019. These first actions are what I take for operational sanity and security any time I launch an ad-hoc windows instance inside Equinix Metal. These are not intended to be prescriptive or complete compared to other best practices, this is purely supplementary and being shared for ease of communication.

<strong>Please note that this is not intended to be a best practices document. There is no support offered around the content of this document.</strong>

The gist of the actions taken here:
* Configure a SSH based local to remote SOCKS proxy through an ssh bastion / endpoint
* Lock down the Windows Defender Firewall
  * Remove all "allowed inbound" on the public side of the public profile of the firewall
  * Allow RDP in via 10.0.0.1/8 network
* Install outstanding windows updates
  * Enabled automatic updates
* Update Windows "Admin" password  
* Add VLANs to the Windows 2019 NIC Teaming function
  * Opt VLAN interfaces into "Private" firewall namespace
  * Configure "Private" firewall namespace for Allow / Allow style traffic
* Disable Public IP Interface  

This document will presume that the operator is working of a Equinix Metal instance provisioned entirely according to defaults with the Equinix Metal Windows 2019 option as the chosen OS. 
  
  
## SSH + SOCKS
It is commonly accepted that leaving any kind of host OS exposed directly to the public internet is a high risk vector for compromise, in particular Windows environments, which are generally "presumed to be installed and operated on a private first network model". 

In order to get to a "private only" network mode for a provisioned Equinix Metal instance, we need at least one path for network based management (RDP).

As someone who generally has at least 1x sshd enabled (Linux) instance provisioned into their account / networks at any given time, I find it easiest to leverage the well understood SSH + SOCKs + RDP operational pattern. This pattern is quite well understood any a plethora of available documentation should only be a google search away, however this section will quickly walk through the process for the purposes of covering the Equinix Metal particulars

### Kitty / Putty Configuration + Metal configuration details

In this example, the Metal instance labeled "home" is a Metal instance provisioned with ubuntu_2004, where the sshd configuration of the instances allows SOCKs proxy functionality (should be enabled by default). We will leverage the "private" or "management" network for access. Notice that with Equinix Metal's ["Backend Transfer"](https://metal.equinix.com/developers/docs/networking/backend-transfer/) feature enabled, an instance in any region can be a SOCKs proxy for any other instance on the private / management network, I.E as host in DA11 could act as SOCKs proxies for hosts in SG1 as well as AM6.

![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/socks_sshd.PNG)

### RDP into the instance @ localhost

Once the SOCKs proxy is established, the RDP session can be initiated against the localhost port configured, where the string ".\" before "Admin" can be useful to break any uneeded domain information, and "Admin" is the username one would expect to be fulfilled by "Administrator" in a Windows environment.

![]https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/localhost.PNG

When RDP is intiatied through this localhost SSHD + SOCKs proxy, it will functionally avoid the public interface of the Windows instance, where the RDP session / traffic will exist between the SSHD "bastion" endpoint and the Windows instance over the private network, and will be proxied back to your workstation via the SOCKs proxy over that Bastion instances public network. This will allow us to re-configure and eventually remove the public internet / access from the Windows instance.

## Windows Firewall configuration

The Defender Firewall included with Windows 2019 is an often overlooked feature, and while I wouldn't trust it to protect my banking information, it can be a useful tool to maintain some kind of operational security while quickly testing something out or while covering the operational efforts to otherwise secure an instance. I leverage it to provide a slightly safer environment while I perform other configuration work on the instance.

The Defender Firewall is slightly wonky to configure, but it does follow a traditional zone based / deny then allow ACL structure, where any traffic is matched to one or more zones, where the traffic must be allowed in through a rule all zones to pass the firewall.

First, we "disable" all rules besides RDP:
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/rdp_10_in.PNG)

Second, we modify the "scope" of the RDP allow to allow in anything from our 10.0.0.1/8 management network. This is implying an implicit trust of that network and is what will continue to allow our RDP traffic to proxy through our bastion host:
![]https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/rdp_10_in.PNG

When these rule changes are applied, the host will be in a state where the only traffic allowed IN will be RDP traffic over the private network. Outbound internet requests will be allowed as expected. This gives us a better operational posture for the remaining configuration work.

## Install outstanding windows updates
While the "image" for an Operating System is often updated by Equinix Metal to catch up from the upstream sources, the time delay between that action and any updates released upstream may be significant, so the host must be updated immediately. There is no special construct to this with Equinix Metal + Windows Server 2019, it's just traditional systems administration.

For reference, this can include multiple reboot loops to catch up on all incremental updates from Microsoft. As of June 2021, it requires 3x full patch / reboot cycles to catch the instance up to current.

### Automatic updates
For an instance deployment that may be long-lived, it would be strongly [suggested to configure](https://docs.microsoft.com/en-us/windows-server/administration/windows-server-update-services/deploy/4-configure-group-policy-settings-for-automatic-updates#allow-automatic-updates-immediate-installation) the instance to [automatic updates](https://docs.microsoft.com/en-us/windows/deployment/update/waas-wufb-group-policy). 

GPO Automatic Updates Path:  [Server Manager, > Tools, > Group Policy Management](https://docs.microsoft.com/en-us/windows-server/administration/windows-server-update-services/deploy/4-configure-group-policy-settings-for-automatic-updates#accessing-the-windows-update-settings-in-group-policy)

![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/automatic_updates_first.PNG)
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/automatic_updates.PNG)

## Windows Updates
While the "image" that is installed to an Equinix Metal instance is often updated to incorporate patches / updates from upstream, it should be considered best practices to update any Windows image immediately to receive any updates that were released by Microsoft since the Metal image was last updated

# Reset Windows "Admin" password

It should always be considered a best practice to reset the shared password an instance is provisioned with by the cloud platform that provided it. There is nothing special regarding this and Equinix Metal, usual systems administration concept apply.

## VLANs

VLANs and NIC Teaming were significantly revamped in both Windows 2016 and 2019. The systems administration regarding Server 2019 and VLANs + Teaming is quite seperate from any previous release, and so there may be extremely conflicting documentation (via say Google) in the space. Take care to reference documentation that is relevant to Server 2019 specifically.

In [Server 2019](https://docs.microsoft.com/en-us/windows-server/networking/technologies/nic-teaming/nic-teaming), LACP is now managed by the ["NIC Teaming"](https://docs.microsoft.com/en-us/windows-server/networking/technologies/nic-teaming/nic-teaming-settings) function on Windows (where previously LACP or VLANs were primarily a vendor driver function), and the ["NIC Teaming"](https://adamtheautomator.com/nic-teaming/) function can also be used to easily work with VLAN based networks. This is likely the operationally simplest path to VLAN aware networking within windows, however note that this documentation in this page will conflict with documentation for more complicated Hyper-V centric deployments. For those more complicated deployments, consult more specific information.

### Assign Metal VLANs to the instance
This follows traditional [Metal documentation](https://metal.equinix.com/developers/docs/layer2-networking/overview/), this document assumes the operator is pursuing a ["Hybrid Bonded"](https://metal.equinix.com/developers/docs/layer2-networking/hybrid-bonded-mode/) implementation

![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/hyrid_vlan_first.PNG)
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/second_vlan.PNG)

### NIC Teaming

The ["NIC Teaming"](https://msftwebcast.com/2019/05/setup-nic-teaming-in-windows-server-2019.html) tool can be reached via the Server Manager dashboard. Note that the "Local Server" on the left hand selector can sometimes be cached / stale. If the "local server" appears to be greyed out or not selectable or "Host is unavailable" warnings are given, simply find the sole instance in the "All Servers" list.
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/right_click.PNG)

After select both the "bond_bond0" Team and bond0 object in the "Team Interface" pain, the "Add Interface" option should be available in the "Tasks" dropdown to the right of "Adapter and Interfaces"
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/add_vlan_interface.PNG)

A new team interface can then be created, specifying the VLAN ID from the Equinix Metal portal
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/add_1000_interface.PNG)

Multiple new interfaces can be created as needed for each VLAN being added to the Metal instance
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/vlan10001.PNG)

The interface can then be configured with the IPV4/IPV6 information intended. At this point it's just a traditional Windows Network Adapted / Interface and traditional systems administration applies
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/properties_interfacve.PNG)
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/vlan_interfacceip.PNG)

### Opt VLAN interfaces into "Private" firewall namespace

Because we will continue to make use of the Defender Firewall, we need to inform the firewall that the two new created VLAN interfaces are intended for private / trust traffic, and opting those interfaces out of other zones that may apply a deny rule to traffic. We are choosing the "private" namespace for allow here, and removing the interfaces from the "domain" and "public" zones.

![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/allow_vlan.PNG)
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/uncheck_vlan.PNG)

### Configure "Private" firewall namespace for Allow / Allow style traffic

We must also change the "private" zone to an allow / allow posture
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/inbound_allow.PNG)

## Disable Public IP Interface

Now that updates have been applied and there should be no current dependency on the public internet, we can remove that IP interface entirely to withdraw the host entirely from any publically accessible networking, but still manage the host via RDP as well any other network function / service that may leverage the private VLAN networking

We can also update the default gateway to point to the GW associated with the private network, allowing us to continue to leverage Backend Transfer as our management / control plane across facility network boundaries
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/removepublic.PNG)
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/private_gateway.PNG)
![](https://s3.wasabisys.com/packetrepo/http_assets/windows_first_actions/privategateway.PNG)