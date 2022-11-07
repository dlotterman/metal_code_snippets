### Alpine / Rescue OS LACP or Bonding

The Equinix Metal Rescue OS feature reboot's an Equinix Metal instance into a Alpine based, iPXE hosted LiveOS with cloud-init. The intent behind Rescue OS is to provide a triage and debug environment for common scenarious in troubleshooting issues with Bare Metal.

One of the functions it can be useful for is verifying different elements of connectivity, and in the scope of this doc, LACP.

Normally when Rescue OS boots, Alpine will identify the first NIC with connectivity and DHCP off that NIC with just `eth0`, as opposed to a bonded LACP interface. This will trigger the Top of Rack's LACP fallback mode down to the same first interface and everything works as expected.

Alpine often has some particular opinions, and the easiest way to get bonding going in my experience is the following:

#### Via SSH:
- Add Alping bonding package:
	- `apk add bonding`
- Reset the root password to something known so that you can log into the  [SOS / OOB](https://metal.equinix.com/developers/docs/resilience-recovery/serial-over-ssh/) via local auth
	- `passwd root`
	- Login via OOB / SOS
#### Via OOB / SOS, down the `eth0` interface
- Down the exisiting interface 
	- `ip link set dev eth0 down`
- Create the `/etc/network/interfaces` file with the following contents (note Alpine doesn't ship with `vim`, but does ship with `vi`:
```
auto bond0
iface bond0 inet static
	address $YOUR_INSTANCE_IP, example: 147.75.35.209
	netmask $YOUR_INSTANCE_SUBNET, example: 255.255.255.254
	gateway $YOUR_INSTANCE_GATEWAY, example: 147.75.35.208
	# specify the ethernet interfaces that should be bonded
	bond-slaves eth0 eth1
	bond-mode 802.3ad
	bond-xmit-hash-policy layer3+4
```
- Restart networking
	- `/etc/init.d/networking restart`