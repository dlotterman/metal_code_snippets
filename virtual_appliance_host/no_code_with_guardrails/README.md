---
layout: no_code_safe_appliance_on_metal
title: No Code + Guard Rails + Metal Appliance Host
---


# Background

When evaluating or working with Equinix Metal, users often want a "fastest" path to running an appliance-like device inside of the Equinix Metal platform, often in the form of a virtual network or application appliance. Usually this is because what is being evaluated or worked on is the platform and network directly, not the Metal instances themselves.

While it may make sense to "short path" to running an appliance in Metal in a variety of ways (ESXi for example), those "short paths" often ignore very real and present challenges, namely security in the pursuit of "getting things to work".

This guide and associated folders is intended to provide a documented "short but safe path" to running a virtual appliance inside an Equinix Metal environment with "0 code", where minimal technical knowledge is assumed but that the end result should be "safe" within reason. 

For the purposes of brevity, it will be assumed that the "virtual appliance" in this case is a network focused (router / firewall etc) appliance.

<strong>Please note that fail2ban is currently not correctly protecting cockpit correctly</strong>

The characteristics of this "no code safe virtual appliance" host are as follow:

* `firewalld` is [installed and configured](https://www.redhat.com/sysadmin/beginners-guide-firewalld) to:
  * Drop all inbound
    * Allow in SSH from the world (also protected by `fail2ban`)
    * Allow in Cockpit from the world (also protected by `fail2ban`)
    * Allow all from the presumed Equinix Metal management network (10.0.0.0/8)
    * Allow all from yet unconfigured private networks (172.16.0.0/12)
* `fail2ban` is [installed and configured](https://fail2ban.readthedocs.io/en/latest/develop.html) to:
  * Watch system logs and ban IP's exhibiting abusive SSH behavior
  * Watch systems logs and ban IP's exhibiting abusive Cockpit behavior
  * Drop any bans after 5 minutes
* `dnf-automatic` is [installed and configured](https://dnf.readthedocs.io/en/latest/automatic.html) to:
  * Check automatically for package updates, both security and normal
  * Download updates automatically
  * Apply updates automatically
* `cockpit` is [installed and configured](https://www.redhat.com/en/blog/linux-system-administration-management-console-cockpit) to:
  * Significantly lower "experience" burden required to deploy safe and useable appliances
  * Manage Networks
  * Manage Linux KVM
  * Manage podman containers
* Apply basic best practices
  * Add less privildged user
  * Prepare for Metal centric things like VLAN configuration'
  * Maintain Hybrid Bonded Mode for availability characteristics
* Is <strong>NOT</strong> considered performant / good for benchmarking
  * By design, this is intended for useability discovery
  * Performance will be significantly degraded


# Network preperation

## Public IP's

Equinix Metal has two primary networking "namespaces", it's batteries included Layer-3 networking and it's customer managed Layer-2 networking modes. Network appliances in Metal will often want connectivity into a variety of networks so this guide will assume both Layer-3 and Layer-2 connectivity is desired for the virtual appliance.

Following best practices, the easiet way to provision a host as a hypervisor / VM host with Layer-3 networking for it's guests is to provision the host with defined, contigous IP blocks, for both public and private. Before provisioning any Metal hosts, ensure that a block of "Public" (not Global) IP's has been provisioned into the facility. It's strongly suggested the block be at least a /30 for ease of use. 

[More documentation here about reserving public IP addresses](https://metal.equinix.com/developers/docs/networking/standard-ips/)

<strong>Additional charges will be encured with the provisioning of additional IP addresses.</strong> [details here](https://metal.equinix.com/product/network/)

## VLAN's

[At minimum, a single Layer-2 VLAN must be created in advance](https://metal.equinix.com/developers/docs/layer2-networking/vlans/)

It is suggested to create two VLANs for configuration simplicities sake later one. The second VLAN will be unused in this guide other then as a way to simplify configuration later on.


# Provisioning the Metal instance

This guide currently leverages CentOS8 as the chosen operating system due to it's compatibility with the RedHat led `cockpit` stack. Understanding that CentOS8 has a limited lifecycle ahead of it, everything in this should be replicateable to any CentOS alternative.

## Facility / Metal Type / Operating System

* When provisioning, any Equinix site can be chosen. Any configuration of Metal server can be chosen so long as `CentOS8` is chosen as the deployed operating system.

![](https://s3.wasabisys.com/packetrepo/http_assets/simple.PNG)

## User Data

* At the <strong>"User Data"</strong> field, simply copy and paste the entire contents of the [accompanying cloud-init file](./no_code_with_guardrails/cloud_inits/centos8_no_code_safety_first_appliance_host.yaml). No modification should be necessary unless known / needed.

![](https://s3.wasabisys.com/packetrepo/http_assets/complex.PNG)

## Configure IPs

* After toggling the <strong>"Configure IPs" </strong> radio, the <strong>"Deploy from your subnet"</strong> option should be available. Choose the block of IPs that you provisioned in the "Network Preparation" section earlier. 

* Be sure to include a private block of the same size. This will allow the appliance to have access to both the public and management Layer-3 networks

# Provision the host

Once the <strong>"Deploy Now"</strong> button is hit, the provisioning request will proceed as normal.

* Note that the server will take ~5 minutes longer than a traditional CentOS8 install because of the provisioning work done by the cloud-init file.

## Configure Hybrid mode and VLANs

Once the instance has completed provisionig in the Metal platform, [it needs to be converted into "Hybrid Bonded Mode"](https://metal.equinix.com/developers/docs/layer2-networking/hybrid-bonded-mode/) with the two VLANs created earlier attached to the bond.

![](https://s3.wasabisys.com/packetrepo/http_assets/hybrid_bonded.PNG)

When done, the instance should visibly:
* Have it's public management address be the /30 we provisioned and configured the host with
* Be in "Hybrid Bonded Mode" with 1x or more VLANs attached where VLANs are tagged to the host (<strong>not native, not untagged</strong>)

![](https://s3.wasabisys.com/packetrepo/http_assets/networkconfigdone.PNG)

# Working with Cockpit

After configuring the hosts network in the Equinix Metal portal, the Metal instance itself should be ready for configuration in advance loading the virtual applinace.

Using the public IP from the hosts detail page, visit `https://$PUBLIC_IP:9090` where `$PUBLIC_IP` is the public IP of the instance. The addition of the port `9090` gets to the installed Cockpit login page. Note that it is expected to receive a SSL/TLS certificate error, as everything is configured with default, self-signed certificates.

Login with the `root` username and password of the instance. Note that can be gathered from the instances detail page in the Metal portal, however it is intentionally forgotten by the Metal platform after 24 hours.

![](https://s3.wasabisys.com/packetrepo/http_assets/cockpitlogin.PNG)

## Login attempts / Timeouts / Unavailable

If a number of failed login attempts have occured from a specific IP address, `fail2ban` on the Metal instance will block that IP. If one is inadvertantly banned, simply wait 5 minutes for the ban expiration to occur.


## Exploring Cockpit

Cockpit provides a browser based management interface for the Metal instance that was provisioned. It is safe to "explore" both Cockpit and the Metal instance in general so long as no destructive changes are made.

## Configuring the VLAN on the Metal instance

This step is not strictly needed, however it can be a useful step for debugging, as it gives the Metal host an address on the private Layer-2 VLANs that can be used for testing downstream connectivity isssues.

Add the primary VLAN to the bond via the "Networking" page:

![](https://s3.wasabisys.com/packetrepo/http_assets/vlan_bond.PNG)

The interface for the VLAN will be created, and it will by default try to obtain a DHCP lease that will fail. The VLAN interface can be "clicked into" by it's name of the Networking page to bring up the option to assign an IP by other means, assign an IP address from a private IP block of choice (ideally not overlapping with the `10.0.0.0/8` block that is semi-reserved by the Metal Layer-3 management network, where `172.16.0.0/12` has been assumed by this guide and is pre-configured to be allowed through the hosts's firewall.

![](https://s3.wasabisys.com/packetrepo/http_assets/vlan_ip.PNG)

# Creating the appliance VM

Under <strong>"Virtual Machines"</strong>, create a new VM. Chosing "URL" will allow you to specify a remote installation medium (iso for example) to leverage for the installation of the OS.

* Note that their may be a bug in Cockpit that requires the "Operating System" to be selected before entering anything into the "Installation Source" field. Entering a string into the URL field may cause the Operating System field to be unselectable. Simply star the VM creation flow again

<strong> it is very important to un-select the "Immediately Start VM" checkbox before hitting create</strong>

* Note that installing from a URL can be a significantly slower "user experience" than other installation paths. This should only be visible while the appliance is installing, and will perform as expected once the installation to local disk is complete.

![](https://s3.wasabisys.com/packetrepo/createvm.PNG)

Once the <strong> "Create VM"</strong> botton has been pressed, more configuration of the VM object will be needed, do not initiate the install process via the "Install" button till network interface create is complete.

## Configuring VM interfaces

When the VM is created, it is created on the default VM "bridged" network that is created by default by KVM. This will give it access to the public internet via a private, NAT'ed network local to the host (Tthe Metal instance). The decision to keep or remove this interface is up to the user, however it can facilitate installation of appliances dependant on internet connectivity as part of their installation (network installs etc).

In total, a minimum of 3x interfaces need to be added to the VM, all 3x of which need to be in "direct attachment" mode against the "bond0" interface. The "direct attachment" mode will give the guest appliance interfaces access to the same logical properties and access as the bonded interface it is attaching to. 

![](https://s3.wasabisys.com/packetrepo/vm_interface.PNG)

These 3x interfaces will individually assume the responsibilities of:
  * Layer-3 Public network interface
  * Layer-3 Management network interface
  * Layer-2 VLAN interface

![](https://s3.wasabisys.com/packetrepo/3interfaces.PNG)

# Install the virtual appliance inside of the VM

The <strong>"Install"</strong> button can now be pressed, and the VM's "console" tab can be selected to interact with the VM / appliance through its install process.

![](https://s3.wasabisys.com/packetrepo/pfsense_install.PNG)


## Configuring networking inside the VM / appliance

The VM's network interfaces were configuring in such a way as to give the VM / appliance the same logical network access as the plain "bond" device / interface of the Metal host. As such, when configuring the appliance interfaces inside the appliance operating system itself, the Layer-3 networks (public + management) will be configured as <strong>native / NON-vlan tagged traffic</strong> while the interface intende for Layer-2 VLAN traffic will need to be configured to be VLAN aware.

The Layer-3 "Public" IP address to configure inside the VM will be from the public block that was provisioned at the start of this guide. For example if a host was provisioned with a /30 such as:

`145.40.80.68/30`

Where `145.40.80.70` is the static public IP address of the Metal host and `145.40.80.69` is reserved as the gateway for the entire block. In this scenario, `145.40.80.71` would be available for allocation inside the guest, with the same gateway of `145.40.80.69`.

The same logic is true of the Layer-3 private management network.

## Troubleshooting Layer-2 inside the VM

If attempting to troubleshoot connectivity into the Layer-2 VLAN from inside the guest, it can be useful to configure the guest with an IP from the private block that was chosen in the Cockpit configuration section of this guide (presumably 172.16.0./1). 

To clarify this, both the bonded interface on the host and the virtual interface inside the guest should be configured to be VLAN aware for any "Layer-2" networks attached.

# Completion

You should now have a virtual appliance running succesfully on a Equinix Metal host.
