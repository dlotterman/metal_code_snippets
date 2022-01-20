### Installing Redhat CoreOS on Equinix Metal via iPXE

Disclaimer: This was written as a quick todo brain dump, apologies for horrible formatting and writing.

In the iPXE file for RedHat CoreOS, there are some attributes that deserve an explanation. It is worth noting that the CoreOS project seems to have a number of "provisioning level" architecture changes in flight, between the separation of Operating System and OpenShift, FC <-> RH, and its current place in that versioning between 4.8 -> 4.10. It is highly likely that this documentation will be out of date before too long.

For the most part, this follows the documentation on FC / RH branded sites for installing FC/RH CoreOS to Bare Metal via PXE / LiveOS / iPXE:

* https://docs.openshift.com/container-platform/4.9/machine_management/user_infra/adding-bare-metal-compute-user-infra.html
* https://docs.fedoraproject.org/en-US/fedora-coreos/live-booting-ipxe/
* https://github.com/coreos/ignition


#### iPXE file options

* `ignition.platform.id=metal`
	- This should be self-explanatory, this deviates from older documentation which asks for `coreos.inst.platform_id=packet`, and I haven't looked into the change here
	
* `coreos.inst.ignition_url`
	- This is the URL for the ignition file for the `coreos-installer` that gets run inside the live environment. It's important to note that because we are getting to the `coreos-installer` inside of the live environment, we do need this config as well as the live OS, which is `ignition.config.url`
	- https://discussion.fedoraproject.org/t/can-coreos-inst-ignition-url-and-ignition-config-url-be-used-at-the-same-time/21810/3

* `ignition.config.url`
	- Configures the LiveOS environment that is pulled / booted into by iPXE, this is the live env that the `coreos-installer` lives in and subsequently pulls `coreos.inst.ignition_url`
	
* `inst.sshd`
	- Pure convenience
	
* `rd.net.timeout.carrier=30 rd.neednet=1`
	- `rd.neednet` should supposedly not need to be here anymore, `timeout.carrier` helps with the delay Equinix Metal instances have in getting networking going because of the need to link-up two interfaces and negotiate LACP
	
* `ip=bond0:dhcp bond=bond0:enp1s0f0:enp1s0f1:mode=802.3ad,lacp_rate=slow:miimon=100,xmit_hash_policy=layer3+4,updelay=1000,downdelay=1000`
	- These kernel args both configure bonded networking for the LiveOS / installer env, and are also [supposed to be picked up by dracut / networkmanager downstream to be used as the configuration values for networkmanager in the installed](https://docs.openshift.com/container-platform/4.6/installing/installing_bare_metal/installing-bare-metal-network-customizations.html#installation-user-infra-machines-advanced_network_installing-bare-metal-network-customizations) environment. My experience with 4.8 is this expected behavior was broken, and I had to patch the systemd unit file for the `coreos-installer` to re-pass the kernel args to get picked up post install. This appears to be fixed in 4.10-expiramental and works as intended in the documentation. 
	
	
#### Ignition file 

The unit file patch here shouldn't be necessary, but the CoreOS ecosystem seems to be deadset on either completely re-writing or breaking this functionality with every minor release. 

Ignition will path the systemd unit file for the `coreos-installer` before the service is started, letting us configure the installer. Our patch [deletes an old / stale console](https://github.com/coreos/fedora-coreos-tracker/issues/567) config thats left in the installer default, adds the correct console line for Equinix Metal. This apppears to be needed for 4.8 through 4.10. It also re-appends the kernel args for networking we set in the iPXE kernel args. This line is needed in 4.8, it is not needed in 4.10-expiramental. 

Also the Ignition file example here currently has a hardcoded URL for the Ignition file to be re-downloaded by the installer in the unit patch, this should not be necessary but is there for example.

#### Ignition vs Butane documentation

There is some confusing overlap with Butane documentation regarding the ignition spec's for fcos vs rhcos vs openshift. For the installer of the Operating System, which is `coreos-installer` as of 4.8, we want butane `3.2`-ish era configs. References to the RHCOS specific configuration spec of Ignition / Butane are primarily for the OpenShift ecosystem that lives above the CoreOS operating system installer. That is to say, OpenShift can eventually become responsible for it's own provisioning of new hosts. That path has it's own conflicting documentation / configuration paths as the RHCOS Operating System installer itself. 

* https://coreos.github.io/butane/

#### Networking

The way this is currently put together leans on Equinix Metal providing DHCP for "iPXE" instances with public networking. The documentation from the RedHat branded RHCOS installer covers how to assign this statically. It would be pretty trivial to pull this data dynamically from [Equinix Metal's metadata api](https://metal.equinix.com/developers/docs/servers/metadata/) [or add VLANs to the bond.](https://docs.openshift.com/container-platform/4.6/installing/installing_bare_metal/installing-bare-metal-network-customizations.html#installation-user-infra-machines-advanced_network_installing-bare-metal-network-customizations)

