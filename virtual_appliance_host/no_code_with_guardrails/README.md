---
layout: no_code_safe_appliance_on_metal
title: No Code + Guard Rails + Metal Appliance Host
---


# Background

When evaluating or working with Equinix Metal, users often want a "fastest" path to running an appliance-like device inside of the Equinix Metal platform, often in the form of a virtual network or application appliance. Usually this is because what is being evaluated or worked on is the platform and network directly, not the Metal instances themselves.

While it may make sense to "short path" to running an appliance in Metal in a variety of ways (ESXi for example), those "short paths" often ignore very real and present challenges, namely security in the pursuit of "getting things to work".

This guide and associated folders is intended to provide a documented "short but safe path" to running a virtual appliance inside an Equinix Metal environment with 0 "code", where minimal technical knowledge is assumed but that the end result should be "safe" within reason. 

For the purposes of brevity, it will be assumed that the "virtual appliance" in this case is a network focused (router / firewall etc) appliance.

The characteristics of this "no code safe virtual appliance" host are as follow:

* `firewalld` is [installed and configured](https://www.redhat.com/sysadmin/beginners-guide-firewalld) to:
  * Drop all inbound
    * Allow in SSH from the world (also protected by `fail2ban`)
    * Allow in Cockpit from the world (also protected by `fail2ban`)
    * Allow all from the presumed Equinix Metal management network (110.0.0.0/811)
* `fail2ban` is [installed and configured](https://fail2ban.readthedocs.io/en/latest/develop.html) to:
  * Watch system logs and ban IP's exhibiting abusive SSH behavior
  * Watch systems logs and ban IP's exhibiting abusive Cockpit behavior
  * Drop any bans after 5 minutes
* `dnf-automatic` is [installed and configured](https://dnf.readthedocs.io/en/latest/automatic.html) to:
  * Check automatically for package updates, both security and normal
  * Download updates automatically
  * Apply updates automatically
* `cockpit` is [installed and configured](https://www.redhat.com/en/blog/linux-system-administration-management-console-cockpit) to:
  * Manage Networks
  * Manage Linux KVM
  * Manage podman containers
* Apply basic best practices
  * Add less privildged user
  * Prepare for Metal centric things like VLAN configuration'
  
  
This is all done via the cloud-init file in the accompanying sub-directory.

# Network preperation

## Public IP's

Equinix Metal has two primary networking "namespaces", it's batteries included Layer-3 networking and it's customer managed Layer-2 networking modes. Network appliances in Metal will often want connectivity into a variety of networks so this guide will assume both Layer-3 and Layer-2 connectivity is desired for the virtual appliance.

Following best practices, the easiet way to provision a host as a hypervisor / VM host with Layer-3 networking for it's guests is to provision the host with defined, contigous IP blocks, for both public and private. Before provisioning any Metal hosts, ensure that a block of "Public" (not Global) IP's has been provisioned into the facility. It's strongly suggested the block be at least a /30 for ease of use. 

[More documentation here about reserving public IP addresses](https://metal.equinix.com/developers/docs/networking/standard-ips/)

<strong>Additional charges will be encured with the provisioning of additional IP addresses.</strong>[details here](https://metal.equinix.com/product/network/)

## VLAN's

[At minimum, a single Layer-2 VLAN must be created in advance](https://metal.equinix.com/developers/docs/layer2-networking/vlans/)


# Provisioning the Metal instance

This guide currently leverages CentOS8 as the chosen operating system due to it's compatibility with the RedHat led `cockpit` stack. Understanding that CentOS8 has a limited lifecycle ahead of it, everything in this should be replicateable to any CentOS alternative.


When provisioning, any Equinix site can be chosen. Any configuration of Metal server can be chosen so long as `CentOS8` is chosen as the deployed operating system.

![](https://s3.wasabisys.com/packetrepo/http_assets/simple.PNG)

At the "User Data" field, simply copy and paste the entire contents of the accompanying cloud-init file. No modification should be necessary unless known / needed.

![](https://s3.wasabisys.com/packetrepo/http_assets/complex.PNG)