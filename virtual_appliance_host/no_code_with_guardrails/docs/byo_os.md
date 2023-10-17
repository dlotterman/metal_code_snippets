# Bring Your Own OS to Equinix Metal with NCB

Please note, if all you are trying to do is BYO common operating system to Equinix Metal, there are almost certainly easier paths than this, most likely [custom_ipxe](https://deploy.equinix.com/developers/docs/metal/operating-systems/custom-ipxe/).

This collateral is intended to provide advanced users with an alternate BYO-OS to Equinix Metal path that enables installs of certain OS's that are otherwise cumbersome or impossible to install through the more normal, better supported and documented paths.

You should really only be reading this if working with the support of an Equinix Digital Services technical sales team.

TLDR walkthrough:

- Provision a bootstrap instance, this guide uses `ncb`
    - Configure instace with Metal L2 networking
    - Configure instance with DHCP
    - Configure instance with TFTP
    - Configure instance with other network services
        - DNS
        - NAT

    - This is all provided for free with `ncb`, so we will use `ncb`
- Configure bootstrap instance with install environment
- Provision instance that will be target for BYO-OS
    - Collect instance's metadata
- Reboot instance in bootstrap's L2 network
- Proceed with traditional network installation
    - Target instance DHCP's off boostrap instance in private L2
        - DHCP offers TFTP netxt
        - TFTP points to PXE capable kernel / loader
        - PXE capable loader knows what to do from there
    - Any manual installation work can be done by Metal SOS / OOB
- After install complete, reconfigure target box for Metal Layer-3
- Reboot target box into real OS
- Delete bootstrap instance

## Credentials needed

- [] Metal Read / Write API key
     - Project or Personal should work

# 1) Provision an NCB instance

When launching the `ncb` instance, be sure to launch it with a name that ends in `-1`, `-01`, or `-001`. The hostname ending with the `-1` string will instruct the `ncb` instance to configure DHCP and related services inside the management network.

- [Launch an NCB instance](https://github.com/dlotterman/metal_code_snippets/blob/main/virtual_appliance_host/no_code_with_guardrails/docs/provisioning.md)

## Create mgmt_a (defualt 3880) VLAN

[Through the Metal UI, create a VLAN](https://deploy.equinix.com/developers/docs/metal/layer2-networking/vlans/#creating-a-vlan)

## Assign mgmt_a VLAN to NCB instance

[Assign that VLAN to the `ncb` instance in Hybrid Bonded mode](https://deploy.equinix.com/developers/docs/metal/layer2-networking/hybrid-bonded-mode/#enabling-hybrid-bonded-mode)

From there, `ncb` will take care of the rest of the hardwork of provisioning it's networking and internal state.

# 2) Configure the NCB instance as a DevOps workstation
- SSH onto instance
    - Optionally, run everything in a screen or tmux session
- Download the Metal CLI
```
mkdir ~/bin
curl -L -o ~/bin/metal https://github.com/equinix/metal-cli/releases/download/v0.17.0/metal-linux-amd64
chmod 0750 ~/bin/metal
```
- Write metal configuration file
```
cat > /dev/shm/forget/metal.yaml << EOL
---
organization-id: YOUR_ORG_ID_HERE
project-id: YOUR_PROJECT_HERE
token: YOUR_TOKEN_HERE
EOL
```
# 3) Provision the Metal instance that will the target for BYO-OS installation
It needs to be a `custom_ipxe` instance one primary technical reason:
- We need PXE control, which is exposed through a Metal instance via `always_pxe`

We set the iPXE target to something not relevant, we really just want the instance to stall out on at the iPXE stage, where it will wait for us to catchup in our configuration and later reboot it into the VLAN: DHCP + PXE context.
```
METAL_CONFIG=/dev/shm/forget/metal.yaml
METAL_PROJ_ID=YOUR_PROJECT_ID_HERE
METAL_HOSTNAME=freebsd-installtarget-01
METAL_VLAN=3880
METAL_METRO=sv
```
```
metal device create --config $METAL_CONFIG --hostname $METAL_HOSTNAME --plan m3.small.x86 --metro sv --operating-system alma_9 --project-id $METAL_PROJ_ID -t "metalcli,byo-os" --operating-system custom_ipxe --ipxe-script-url "http://HOST/ipxes/stall.ipxe"
```
- Watch for the instance to go "green" or "state: active":
  - User `Ctrl + c` to cancel the watch command
```
HOSTNAME_ID=$(metal --config $METAL_CONFIG -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id') && \
watch -n5 "metal device get --config $METAL_CONFIG -i $HOSTNAME_ID -o json | jq '.state'"
```
- Gather some needed data about the instance and document it.

- This gives you as the operator a chance to understand your driver configuration in particular for [NICs](nic_configuration_matrix.md) and [BIOS vs UEFI state](../../metal_configurations/bios_uefi_x86.md)
    - If you landed the iPXE script URL at iPXE script that provides an ipxe shell, we can discover these details here:
```
iPXE> ifstat
net0: e8:eb:d3:1a:8e:3e using ConnectX-5 on 0000:01:00.0 (Ethernet) [open]
iPXE> iseq ${platform} efi && echo "Platform is UEFI"
"Platform is UEFI"
```
- So our NIC is a Mellanox ConnectX-5 inside a metal `m3.small.x86`. We are installing FreeBSD, which builds [Mellanox into the kernel](https://forums.freebsd.org/threads/mellanox-connectx-3-w-freebsd-11-2-p6.70623/)
  - Conveniently, this also gave us our MAC which we will need later
- [iPXE](https://forum.ipxe.org/showthread.php?tid=7879) tells us we are in UEFI, which is expected for an `m3.small.x86`

- We can also collect the mac address of the `eth0` via:
```
METAL_MAC=$(metal --config $METAL_CONFIG device get -i $HOSTNAME_ID -o json | jq --arg eth_name "eth0" -r '.network_ports[] | select(.name==$eth_name) | .data.mac')
```
- Collect the instances networking details:
  - Public IP, network/CIDR, GW
```
metal --config $METAL_CONFIG device get -i $HOSTNAME_ID -o json | jq '.ip_addresses[] | select((.public==true) and .address_family==4)'
```
  - Private IP, network/CIDR, GW
```
metal --config $METAL_CONFIG device get -i $HOSTNAME_ID -o json | jq '.ip_addresses[] | select((.public==false) and .address_family==4)'
```

# Prepare NCB install environment

This step is easiest to illustrate using a full example, so FreeBSD 14-Beta will be chosen as the stand in. It should be functionally similar to any other OS that can PXE ecosystem install.

FreeBSD is a great example because it requires an intermediary stage, something some OS install environments may depend on. In the FreeBSD case, we hop through [mfsbsd](https://mfsbsd.vx.sk/) as the network'ed installer environment, which then installs the FreeBSD operating system through `bsdinstall`.

This is similar to some other network install environments, such as OpenStack Ironic with it's hardware inspector, or disk image based systems that boot into an intermediary LiveOS stage.

## Prepare install environment on NCB
- Download and unpack media
  - mfsbsd, we unpack this into `export/tftp`.
```
sudo mkdir -p /mnt/util/export/isos/
sudo curl -o /mnt/util/export/isos/mfsbsd-se-13.2-RELEASE-amd64.iso $YOUR_MFSBSD_URL
sudo mkdir -p /tmp/ncb/tmpmount_mfsbsd
sudo mount -o loop /mnt/util/export/isos/mfsbsd-se-13.2-RELEASE-amd64.iso /tmp/ncb/tmpmount_mfsbsd
sudo rsync -a /tmp/ncb/tmpmount_mfsbsd/ /mnt/util/export/tftp
```
  - freebsd, unpack it into `export/html`, and copy the `loader.efi` binary to the TFTP target file
```
sudo curl -o /mnt/util/export/isos/FreeBSD-14.0-BETA4-amd64-dvd1.iso http://HOST/util/freebsd/FreeBSD-14.0-BETA4-amd64-dvd1.iso
sudo mkdir /tmp/ncb/tmpmount_freebsd
sudo mount -o loop /mnt/util/export/isos/FreeBSD-14.0-BETA4-amd64-dvd1.iso /tmp/ncb/tmpmount_freebsd
sudo mkdir /mnt/util/export/html/autoindex/freebsd/
sudo rsync -a /tmp/ncb/tmpmount_freebsd/ /mnt/util/export/html/autoindex/freebsd
sudo cp /mnt/util/export/html/freebsd/boot/loader.efi /mnt/util/export/tftp/tftptarget.file
```

- Configure install environment, in this case, mfsbsd specific settings for the intermediary install environment.

***BE SURE TO NOTE THE OOB / SOS specific serial settings, use the correct equivalent for your OS***

```
sudo -i
```
```
cat > /mnt/util/export/tftp/boot/loader.conf << EOL
boot_serial="YES"
comconsole_port="0x2F8"
comconsole_speed="115200"
console="efi"
beastie_disable="YES"
autoboot_delay="15"
security.bsd.allow_destructive_dtrace=0
kern.geom.label.disk_ident.enable="0"
kern.geom.label.gptid.enable="0"
hw.nvme.use_nvd="0"
hw.mfi.mrsas_enable="1"
vfs.root.mountfrom="ufs:/dev/md0"
mfsbsd.autodhcp="YES"
mfs_load="YES"
mfs_type="mfs_root"
mfs_name="/mfsroot"
ahci_load="YES"
sshd_enable="YES"
EOL
```
- exit sudo
```
exit
```

- Be sure to configure your DHCP / TFTP setup for the correct way of catching the box. In `ncb` this is done with:
  - NOTE this depends on all the environment settings and commands run from ^^
```
METAL_CONFIG=/dev/shm/forget/metal.yaml
METAL_PROJ_ID=YOUR_PROJECT_ID_HERE
METAL_HOSTNAME=freebsd-installtarget-01
METAL_VLAN=3880
METAL_METRO=sv
HOSTNAME_ID=$(metal --config $METAL_CONFIG -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id') && \
METAL_MAC=$(metal --config $METAL_CONFIG device get -i $HOSTNAME_ID -o json | jq --arg eth_name "eth0" -r '.network_ports[] | select(.name==$eth_name) | .data.mac')
echo $METAL_MAC",set:pxeinstall,,"$METAL_HOSTNAME",infinite" | sudo tee /var/tmp/ncb/etc/dnsmasq.d/hostsdir/test01.conf

```

# Entry into L2 Space

- Convert the box to L2 mode with the mgmta vlan (3880) as the sole or native VLAN (the server must not receive 3800 tagged, it must receive it untagged. Once this action is completed, it is expected that the deployed instance will be unavailable to Metal's L3 networking for this intermediary stage. All subsequent steps will happen in our Layer-2 space of VLAN 3880, where network services will come from our NCB instance.

It is also recommended to already have the OOB / SOS for the target instance loaded, watching the output can be important for debugging or understanding state.

```
HOSTNAME_BOND0=$(metal --config $METAL_CONFIG -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id') && \
HOSTNAME_ID=$(metal --config $METAL_CONFIG -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id') && \
metal port convert --config $METAL_CONFIG -i $HOSTNAME_BOND0 --layer2 --bonded
metal port vlan --config $METAL_CONFIG -i $HOSTNAME_BOND0 -a $METAL_VLAN
metal device update --config $METAL_CONFIG -i $HOSTNAME_ID -a
```
- Reboot the instance
```
metal device reboot --config $METAL_CONFIG -i $HOSTNAME_ID
```

The instance should reboot and attempt to DCHP, where it should get an answer from the `ncb` instance. That DHCP answer should include a TFTP forward to the kernel, in this case `loader.efi`. Example output:

```
>>Checking Media Presence......
>>Media Present......
>>Start PXE over IPv4 on MAC: E8-EB-D3-1A-8E-3E.
  Station IP address is 172.16.100.147

  Server IP address is 172.16.100.1
  NBP filename is tftptarget.file
  NBP filesize is 659968 Bytes

>>Checking Media Presence......
>>Media Present......
 Downloading NBP file...

  NBP file downloaded successfully.
Consoles: EFI console
    Reading loader env vars from /efi/freebsd/loader.env
FreeBSD/amd64 EFI loader, Revision 1.1

   Command line arguments: loader.efi
   Image base: 0x8a4a1000
   EFI version: 2.80
   EFI Firmware: American Megatrends (rev 5.22)
   Console: efi (0x20000000)
   Load Path:
   Load Device: PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0)/MAC(E8EBD31A8E3E,0x1)/IPv4(0.0.0.0)
   BootCurrent: 0003
   BootOrder: 0003[*] 0006 0005 0004
   BootInfo Path: PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0)/MAC(E8EBD31A8E3E,0x1)/IPv4(0.0.0.0)
   BootInfo Path: VenHw(2D6447EF-3BC9-41A0-AC19-4D51D01B4CE6,5000580045002000490050007600340020004D0065006C006C0061006E006F00780020004E006500740077006F0072006B002000410064006100700074006500720020002D002000450038003A00450042003A00440033003A00310041003A00380045003A00330045000000)
Ignoring Boot0003: No Media Path
Setting currdev to net1:
Loading /boot/defaults/loader.conf
Loading /boot/defaults/loader.conf
Loading /boot/device.hints
Loading /boot/loader.conf
Loading /boot/loader.conf.local
Failed to load conf dir '/boot/loader.conf.d': not a directory
?cLoading kernel...
/boot/kernel/kernel text=0x18aa98 text=0xdfd150 text=0x675154 \
```

From there, you can access the HTTP, NFS or TFTP exports to network install your OS. For example with FreeBSD, you may need to configure the repository to look at the artifacts currently hosted on the `ncb`, for example the unpacked ISO:

```
$ curl http://172.16.100.1:82/autoindex/freebsd/
<html>
<head><title>Index of /autoindex/freebsd/</title></head>
<body>
<h1>Index of /autoindex/freebsd/</h1><hr><pre><a href="../">../</a>
<a href="bin/">bin/</a>                                               29-Sep-2023 10:03                   -
<a href="boot/">boot/</a>                                              29-Sep-2023 10:15                   -
<a href="dev/">dev/</a>                                               29-Sep-2023 09:59                   -
<a href="etc/">etc/</a>                                               29-Sep-2023 10:18                   -
<a href="lib/">lib/</a>                                               29-Sep-2023 10:04                   -
<a href="libexec/">libexec/</a>                                           29-Sep-2023 10:03                   -
<a href="media/">media/</a>                                             29-Sep-2023 09:59                   -
<a href="mnt/">mnt/</a>                                               29-Sep-2023 09:59                   -
<a href="net/">net/</a>                                               29-Sep-2023 09:59                   -
<a href="packages/">packages/</a>                                          29-Sep-2023 10:18                   -
<a href="proc/">proc/</a>                                              29-Sep-2023 09:59                   -
<a href="rescue/">rescue/</a>                                            29-Sep-2023 09:59                   -
<a href="root/">root/</a>                                              29-Sep-2023 10:12                   -
<a href="sbin/">sbin/</a>                                              29-Sep-2023 10:07                   -
<a href="tmp/">tmp/</a>                                               29-Sep-2023 09:59                   -
<a href="usr/">usr/</a>                                               29-Sep-2023 10:14                   -
<a href="var/">var/</a>                                               29-Sep-2023 09:59                   -
<a href="COPYRIGHT">COPYRIGHT</a>                                          29-Sep-2023 10:11                6109
</pre><hr></body>
</html>
```

So that would create a repository URL for `bsdinstall` of `http://172.16.100.1:82/autoindex/freebsd/usr/freebsd-dist/`:
```
$ curl http://172.16.100.1:82/autoindex/freebsd/usr/freebsd-dist/
<html>
<head><title>Index of /autoindex/freebsd/usr/freebsd-dist/</title></head>
<body>
<h1>Index of /autoindex/freebsd/usr/freebsd-dist/</h1><hr><pre><a href="../">../</a>
<a href="MANIFEST">MANIFEST</a>                                           29-Sep-2023 10:14                1046
<a href="base-dbg.txz">base-dbg.txz</a>                                       29-Sep-2023 10:15           272266908
<a href="base.txz">base.txz</a>                                           29-Sep-2023 10:15           199258400
<a href="kernel-dbg.txz">kernel-dbg.txz</a>                                     29-Sep-2023 10:15           105128952
<a href="kernel.txz">kernel.txz</a>                                         29-Sep-2023 10:15            54026624
<a href="lib32-dbg.txz">lib32-dbg.txz</a>                                      29-Sep-2023 10:15            22379480
<a href="lib32.txz">lib32.txz</a>                                          29-Sep-2023 10:15            62651680
<a href="ports.txz">ports.txz</a>                                          29-Sep-2023 10:15            50276848
<a href="src.txz">src.txz</a>                                            29-Sep-2023 10:15           204223156
<a href="tests.txz">tests.txz</a>                                          29-Sep-2023 10:15            17226872
</pre><hr></body>
</html>
```

That could also be exposed by NFS:
```
$ showmount -e 172.16.100.1
Export list for 172.16.100.1:
/mnt/util/export/tftp 172.16.100.0/24
/mnt/util/export/nfs1 192.168.252.0/24,172.16.253.0/24
/mnt/util/export      192.168.101.0/24,172.16.100.0/24,10.0.0.0/8
```

The instance should have NAT'ed access to the Internet via `ncb`:
```
Oct 17 21:45:46 mfsbsd login[1239]: ROOT LOGIN (root) ON ttyu1
FreeBSD 13.2-RELEASE releng/13.2-n254617-525ecfdad597 GENERIC

Welcome to FreeBSD!

Release Notes, Errata: https://www.FreeBSD.org/releases/
Security Advisories:   https://www.FreeBSD.org/security/
FreeBSD Handbook:      https://www.FreeBSD.org/handbook/
FreeBSD FAQ:           https://www.FreeBSD.org/faq/
Questions List:        https://www.FreeBSD.org/lists/questions/
FreeBSD Forums:        https://forums.FreeBSD.org/

Documents installed with the system are in the /usr/local/share/doc/freebsd/
directory, or can be installed later with:  pkg install en-freebsd-doc
For other languages, replace "en" with a language code like de or fr.

Show the version of FreeBSD installed:  freebsd-version ; uname -a
Please include that output and any error messages when posting questions.
Introduction to manual pages:  man man
FreeBSD directory layout:      man hier

To change this login announcement, see motd(5).
root@mfsbsd:~ # ping google.com
PING google.com (142.251.2.100): 56 data bytes
64 bytes from 142.251.2.100: icmp_seq=0 ttl=105 time=16.664 ms
64 bytes from 142.251.2.100: icmp_seq=1 ttl=105 time=16.597 ms
^C
--- google.com ping statistics ---
2 packets transmitted, 2 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 16.597/16.630/16.664/0.034 ms
```

## Installation complete and cleanup:

When the installation is complete, which should include the needed networking configuration so that the instance comes up in it's desired networking mode, for example Metal Layer-3 Bonded. Any other best practices like serial settings etc should also be set.

This can all be automated with each OS's network automation install chain. FreeBSD can use `.cfg` files for `bsdinstall`, Linux can use `ks` or *pre-seed* files, Windows can enter the Configuration Managed ecosystem.

When the OS is installed to disk, configured as required and ready to be entered into service

- Return the Metal install instance to it's Layer-3 Bonded configuration as would be default:
```
metal port convert --config $METAL_CONFIG -i $HOSTNAME_BOND0 -2=false --bonded --public-ipv4 --public-ipv6
```
#### Disable always_pxe

This can currently only be done through the UI or a raw curl command against the API
```
curl -s -X PUT \
--header 'X-Auth-Token: $YOURTOKENHERE' \
--header 'Content-Type: application/json' 'https://api.equinix.com/metal/v1/devices/$YOURUUIDHERE'  \
--data '{"always_pxe": "false"}'
```

- Reboot
```
metal device reboot --config $METAL_CONFIG -i $HOSTNAME_ID
```

And the instance will reboot into the BYO-OS.

The `ncb` instance can be decommisioned.

# Random Notes
## FreeBSD
I am stashing FreeBSD notes here only because I will later fork them off to their own dedicated document:

```
cat > /etc/pkg/ncb.conf << EOL
ncb: {
  url: "pkg+http://172.16.100.31:81/freebsd/packages/FreeBSD:11:amd64",
  mirror_type: "srv",
  signature_type: "none",
  fingerprints: "/usr/share/keys/pkg",
  enabled: yes
}
EOL

mkdir -p /usr/local/etc/pkg/repos
echo "FreeBSD: { enabled: no }" > /usr/local/etc/pkg/repos/FreeBSD.conf

pkg update

pkg install -y curl rsync sudo tmux

mkdir /root/src
curl -o /root/src/src.txz http://172.16.100.31:81/freebsd/usr/freebsd-dist/src.txz
tar -xf /root/src/src.txz -C /

curl -o /root/src/ice-1.37.11.tar.gz http://172.16.100.31:81/ice-1.37.11.tar.gz
tar -xf /root/src/ice-1.37.11.tar.gz -C /root/src/
cd /root/src/ice-1.37.11/
make
make install
gzip -c ice.4 > /usr/share/man/man4/ice.4.gz

# Convert to hybrid bonded to get IP back

cat > /etc/rc.conf << EOL
dumpdev="AUTO"
if_ice_load="YES"
ifaces_enable="YES"
cloned_interfaces="lagg0"
sshd_enable="YES"
# Set dumpdev to "AUTO" to enable crash dumps, "NO" to disable
dumpdev="AUTO"
zfs_enable="YES"
ifconfig_ice0=up
ifconfig_ice2=up
ifconfig_lagg0="laggproto lacp laggport ice0 laggport mce1"
ifconfig_lagg0_alias0="inet 86.109.11.235 netmask 255.255.255.254"
ifconfig_lagg0_alias1="inet 10.67.167.131 netmask 255.255.255.254"
defaultrouter="86.109.11.234"
static_routes="private"
route_private="-net 10.0.0.0/8 10.67.167.130"
sendmail_enable="NONE"
ifaces_enable="YES"
EOL

cat > /etc/resolv.conf << EOL
nameserver 147.75.207.207
nameserver 147.75.207.208
EOL
```

#### ICE driver
```
/etc/rc.conf
hostname="charlierulesok-03"
ifconfig_mce0="DHCP"
sshd_enable="YES"
# Set dumpdev to "AUTO" to enable crash dumps, "NO" to disable
dumpdev="AUTO"
zfs_enable="YES"
if_ice_load="YES"
ifconfig_ice0=up
ifconfig_ice1=up
ifconfig_lagg0="laggproto lacp laggport ice0 laggport ice1"
ifconfig_lagg0_alias0="inet 147.75.71.219 netmask 255.255.255.254"
ifconfig_lagg0_alias1="inet 10.67.203.133 netmask 255.255.255.254"
defaultrouter="147.28.155.76"
static_routes="private"
route_private="-net 10.0.0.0/8 10.65.15.132"
sendmail_enable="NONE"
ifaces_enable="YES"
dumpdev="AUTO"
```
```
### NOTE THE ICE DRIVER version
## NEWER WILL BREAK ON FreeBSD 12 and older
### FreeBSD 13 and newer should be free to install new new
mkdir /root/src
curl -o /root/src/src.txz http://172.16.100.31:81/freebsd/usr/freebsd-dist/src.txz
tar -xf /root/src/src.txz -C /

curl -o /root/src/ice-1.37.11.tar.gz http://172.16.100.31:81/ice-1.37.11.tar.gz
tar -xf /root/src/ice-1.37.11.tar.gz -C /root/src/
cd /root/src/ice-1.37.11/
make
make install
gzip -c ice.4 > /usr/share/man/man4/ice.4.gz
```

#### MLNX
```
cat > /etc/rc.conf << EOL
dumpdev="AUTO"
if_ice_load="YES"
ifaces_enable="YES"
cloned_interfaces="lagg0"
sshd_enable="YES"
# Set dumpdev to "AUTO" to enable crash dumps, "NO" to disable
dumpdev="AUTO"
zfs_enable="YES"
ifconfig_ice0=up
ifconfig_ice2=up
ifconfig_lagg0="laggproto lacp laggport ice0 laggport mce1"
ifconfig_lagg0_alias0="inet 86.109.11.235 netmask 255.255.255.254"
ifconfig_lagg0_alias1="inet 10.67.167.131 netmask 255.255.255.254"
defaultrouter="86.109.11.234"
static_routes="private"
route_private="-net 10.0.0.0/8 10.67.167.130"
sendmail_enable="NONE"
ifaces_enable="YES"
EOL
```
