### Cloud-init walkthrough

This document will break down an example `#cloud-config` line by line, with the hope that it provides some context and understanding for new users of Cloud-init with Equinix Metal.


#### `#cloud-config` docstring

```
#cloud-config
```
You always want to begin a Cloud-init `#cloud-config` file with this string.

While appearing to be just a doc string, this line is actually critical for both the Metal Platform and an instance's Cloud-init package to correctly identify the `user_data` text as a configuration for cloud-init. While Cloud-init `#cloud-config`'s are just YAML files, it should be noted that you do want to be safe with your doc strings as they can easily get misinterpreted by Cloud-init or the Metal Platform.

#### Packages Update and Reboot

```
package_upgrade: true
package_reboot_if_required: true
```

When an instance is launched, that instance [likely comes with an OS from a Equinix Metal image](https://metal.equinix.com/developers/docs/operating-systems/), or through our Custom iPXE functionality. It's likely that the OS or it's packages are likely out of date, as install media and pre-built images tend to be static and drift over time as patches and fixes get published through upstream repositories.

These two lines will instruct Cloud-init to [update all of the packages installed](https://cloudinit.readthedocs.io/en/latest/topics/modules.html?highlight=package_upgrade#package-update-upgrade-install) on the instance, and if one of those packages requires a reboot (say kernel update) to take effect, to reboot the server at the very end of it's Cloud-init stage so that when the instance returns to the operator, it will have those changes live.


### bootcmd
```
bootcmd:
  - [ mkdir, -p, /opt/metal_ddve/ ]
  - [ mkdir, -p, /mnt/md0 ]
  - [ subscription-manager, register, --username, MYUSERNAME, --password, 'MYPA$$WORD' ]
  - [ subscription-manager, repos, --enable, rhel-8-for-x86_64-baseos-rpms ]
  - [ subscription-manager, repos, --enable, rhel-8-for-x86_64-appstream-rpms ]
```

[`bootcmd`](https://cloudinit.readthedocs.io/en/latest/topics/modules.html?highlight=bootcmd#bootcmd) is a place to list "commands", where those "commands" are interpreted by the Cloud-init's default shell (likely `bash` or `sh`) and run by cloud-init to configure the system. 

`bootcmd` is very similar to [`runcmd`](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/cloud_init/example_cloud_init_walkthrough.md#runcmd), just that it is run much earlier in the provisioning process, meaning it can be useful for ordering dependencies. If you need commands run before you can say install packages, you can put those in `bootcmd` so that the downstream packages section act without modification.

The commands are "comma space" seperated in order to minimize the problems of shell command string parsing and the headaches that come with.

Here, we are creating file structures for commands run later, and we are also joining the instance, which is presumably RHEL based, to active Redhat subscriptions, so that packages can be installed later on as well.
    * Note that as of the time of this writing, the default `cloud.cfg` that comes with Equinix Metal instances does not support the [rh_subscription](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#red-hat-subscription) Cloud-init module.
        * This is planned to be enabled sometime in the near future

#### `packages`
```
packages:
  - tmux
  - firewalld
  - jq
  - vim
  - nc
  - git
  - dnf-automatic
  - dnf-plugins-core
  - unzip
  - virt-manager
  - libguestfs-tools
  - qemu-kvm
  - libvirt-daemon
  - virt-install
  - virt-manager
  - network-scripts
  - libguestfs
  - net-tools
  - wget
  - virt-install
  - mdadm
```

This will instruct Cloud-init to [install these packages by name](https://cloudinit.readthedocs.io/en/latest/topics/modules.html?highlight=bootcmd#package-update-upgrade-install). Cloud-init will then work with the OS's package manager (if supported), to install these packages. `packages` will be installed *after* `bootcmd` but *before* `runcmd`.


#### `runcmd`
```
runcmd:
  - [ modprobe, 8021q ]
  - [ sysctl, -p ]
  - [ systemctl, enable, NetworkManager.service ]
  - [ systemctl, restart, NetworkManager.service ]
  - [ systemctl, enable, libvirtd ]
  - [ systemctl, restart, libvirtd ]
  - [ virsh, net-destroy, default ]
  - [ virsh, net-undefine, default ]
  - [ virsh, net-define, /opt/metal_ddve/metal_bridge.xml ]
  - [ virsh, net-autostart, br0 ]
  - [ virsh, net-start, br0 ]
  - [ /opt/metal_ddve/raid6_largest_drives.sh ]
  - [ mkfs.ext4, -F, /dev/md0 ]
  - [ mount, /dev/md0, /mnt/md0 ]
  - [ systemctl, restart, NetworkManager.service ]
```

These are [commands that will be exectued](https://cloudinit.readthedocs.io/en/latest/topics/modules.html?highlight=bootcmd#runcmd) by the default shell (likely `bash` or `sh`), with "comma space" seperation to minimize common shell command + string parsing problems. 

`runcmd` comes after `bootcmd`, `packages` *and* `write_files`.

This is [generally where the bulk](https://cloudinit.readthedocs.io/en/latest/topics/modules.html?highlight=bootcmd#runcmd) of work is done in `#cloud-config`'s, and represent the "operator action steps" of automation. It should be noted that variables and other complex actions are either not possible or very difficult, so complex work should be done inside of a script of configuration file, where the below section on `write_files` can help with that, where complex logic can be written to disk, and then executed by `runcmd` here

In the case of this `#cloud-config`, these steps will:

- `- [ modprobe, 8021q ]` load the VLAN kernel module
- `- [ sysctl, -p ]` load the `sysctl` settings defined in the `sysctl` config file, which we appended a line of configuration to in the `write_files` section below.
- `- [ systemctl, enable, NetworkManager.service ]`, `- [ systemctl, restart, NetworkManager.service ]` start and set boot-time start of the Linux NetworkManage service
- `- [ systemctl, enable, libvirtd ]`, `- [ systemctl, restart, libvirtd ]` start and set boot-time start of the Linux KVM orchestration daemon.
- `- [ virsh, net-destroy, default ]`, `- [ virsh, net-undefine, default ]` Destroy the default network configuration that comes with KVM via the `virsh` management command
- `- [ virsh, net-define, /opt/metal_ddve/metal_bridge.xml ]` load a new network definition from the specified file. That file is create below in the `write_files` section.
- `- [ virsh, net-autostart, br0 ]` configure KVM networking to `autostart` the `br0` bridge, which was defined in `/opt/metal_ddve/metal_bridge.xml`, when the `libvrtd` service starts
- `- [ /opt/metal_ddve/raid6_largest_drives.sh ]` run the `/opt/metal_ddve/raid6_largest_drives.sh` script, which will take all of the high capacity drives (ignoring NVMe) visible on a server and place them into a RAID6 linux software raid. This script is written to disk ahead of time in below in the `write_files` section


#### `write_files`

```
write_files:
```

[Write files provides](https://cloudinit.readthedocs.io/en/latest/topics/modules.html?highlight=bootcmd#runcmd) a "helpers and safeguards included" path to writing arbitraty strings to declared files, with useful options to say `append` (instead of replace) or manage permissions of a file easily with safety, including safety for complex or long string stanzas.


```
- path: "/etc/sysconfig/network-scripts/ifcfg-bond0.1001"
  permissions: "0644"
  owner: "root:root"
  content: |
    DEVICE=bond0.1001 
    NAME=bond0.1001 
    ONPARENT=yes 
    VLAN=yes 
    BOOTPROTO=none 
    ONBOOT=yes 
    USERCTL=no 
    NM_CONTROLLED=no
    BRIDGE=br0
```

This will will write the configuration needed to add the VLAN 1000 to the bonded interface that comes by default with a Metal instance. 

`NM_CONTROLLER` is set to `no` because KVM / `libvirtd` will manage the turnup of `br0`, which will then manage the turnup of the `bond0.1001` VLAN interface.


```
- path: "/etc/sysconfig/network-scripts/ifcfg-br0"
  permissions: "0644"
  owner: "root:root"
  content: |
    DEVICE=br0 
    TYPE=Bridge 
    IPADDR=192.168.100.10 
    NETMASK=255.255.255.0 
    ONBOOT=yes 
    BOOTPROTO=none 
    NM_CONTROLLED=no
    DELAY=0 
```

This configures the IP information for the `br0` default device we created in the `runcmd` section

```
- path: "/etc/sysctl.conf"
  permissions: "0644"
  owner: "root:root"
  write_files:
  permissions: "0644"
  content: |
    net.ipv4.ip_forward = 1
```

Set a needed `sysctl` variable permantnely in the file. A `runcmd` line is also above to set this variable on the running system during provisioning.

Note the use of `write_files:` here, where this will cause Cloud-init to **ADD** the line only to the bottom of the file, rather than replacing the whole file. This can allow for multiple sections of `write_file` to touch the same file, or to not clobber the file that might have existed there before.

```
- path: "/opt/metal_ddve/metal_bridge.xml"
  permissions: "0644"
  owner: "root:root"
  content: |
    <network> 
      <name>br0</name> 
      <forward mode="bridge" /> 
      <bridge name="br0" />   
    </network> 
```

This is the xml file definition for the `br0` device we create in the `runcmd` section.

```
- path: "/opt/metal_ddve/raid6_largest_drives.sh"
  permissions: "0744"
  owner: "root:root"
  content: |
    #!/bin/bash
    DRIVE_SIZE=$(lsblk --bytes | grep -v nvme | grep disk | awk '{print$4}' | sort -nr | head -1)
    RAID_DRIVES=$(lsblk --bytes | grep $DRIVE_SIZE | awk '{print"/dev/"$1}' | tr '\n' ' ')
    NUM_DRIVES=$(echo $RAID_DRIVES | wc -w)
    for DRIVE in $RAID_DRIVES ; do
        mdadm --zero-superblock $DRIVE > /dev/null 2>&1
    done
    mdadm --create --verbose --level=6 --raid-devices=$NUM_DRIVES /dev/md0 $RAID_DRIVES
    mdadm --detail --scan >> /etc/mdadm.conf
```

This is a script that is written to disk, where the script:
- Gets a list of all drives with their byte sizes listed
  - Removes NVMe drives from that list
  - Finds the largest drive by byte size
- Gets a list of all drives with their byte sizes listed
  - Looks for drives that have the largest, earlier found size, puts them in a list with the right string so `sdj` becomes `/dev/sdj` in the script's list
- Finds the number of drives in the list of the largest drives
- Goes through the list of drives (`/dev/sde, /dev/sdf` etc), and wipes any pre-existing RAID superblocks from them
- Create a software RAID6 device where the drives come from the list of our largest, non-NVMe drives and the number of RAID devices is the number of drives we found in that list
- Writes the RAID configuration to `/etc/mdadm.conf` so it's persistant across reboots.

```
- path: "/etc/fstab"
  permissions: "0644"
  owner: "root:root"
  append: true
  content: |
    /dev/md0 /mnt/md0 ext4 defaults,nofail,discard 0 0
```
Add the needed line to the `fstab` file so that the RAID6 software raid we create is mounted into the expected path at boot


#### Boilerplate

There are some configuration options that are there to silence cloud-init alarms or other logs:
    
```    
datasource:
  Ec2:
    strict_id: false
```

This stanza is there just to reduce the logging verbosity of Cloud-init as it steps through some of it's changes. No impact on a system is expected.


#### Full `cloud-init`

```
#cloud-config

package_upgrade: true
package_reboot_if_required: true

bootcmd:
  - [ mkdir, -p, /opt/metal_ddve/ ]
  - [ mkdir, -p, /mnt/md0 ]
  - [ subscription-manager, register, --username, MYUSERNAME, --password, 'MYPA$$WORD' ]
  - [ subscription-manager, repos, --enable, rhel-8-for-x86_64-baseos-rpms ]
  - [ subscription-manager, repos, --enable, rhel-8-for-x86_64-appstream-rpms ]

packages:
  - tmux
  - firewalld
  - jq
  - vim
  - nc
  - git
  - dnf-automatic
  - dnf-plugins-core
  - unzip
  - virt-manager
  - libguestfs-tools
  - qemu-kvm
  - libvirt-daemon
  - virt-install
  - virt-manager
  - network-scripts
  - libguestfs
  - net-tools
  - wget
  - virt-install
  - mdadm

runcmd:
  - [ modprobe, 8021q ]
  - [ sysctl, -p ]
  - [ systemctl, enable, NetworkManager.service ]
  - [ systemctl, restart, NetworkManager.service ]
  - [ systemctl, enable, libvirtd ]
  - [ systemctl, restart, libvirtd ]
  - [ virsh, net-destroy, default ]
  - [ virsh, net-undefine, default ]
  - [ virsh, net-define, /opt/metal_ddve/metal_bridge.xml ]
  - [ virsh, net-autostart, br0 ]
  - [ virsh, net-start, br0 ]
  - [ /opt/metal_ddve/raid6_largest_drives.sh ]
  - [ mkfs.ext4, -F, /dev/md0 ]
  - [ mount, /dev/md0, /mnt/md0 ]
  - [ systemctl, restart, NetworkManager.service ]
  

write_files:
- path: "/etc/sysconfig/network-scripts/ifcfg-bond0.1001"
  permissions: "0644"
  owner: "root:root"
  content: |
    DEVICE=bond0.1001 
    NAME=bond0.1001 
    ONPARENT=yes 
    VLAN=yes 
    BOOTPROTO=none 
    ONBOOT=yes 
    USERCTL=no 
    NM_CONTROLLED=no
    BRIDGE=br0 

- path: "/etc/sysconfig/network-scripts/ifcfg-br0"
  permissions: "0644"
  owner: "root:root"
  content: |
    DEVICE=br0 
    TYPE=Bridge 
    IPADDR=192.168.100.10 
    NETMASK=255.255.255.0 
    ONBOOT=yes 
    BOOTPROTO=none 
    NM_CONTROLLED=no
    DELAY=0 

- path: "/etc/sysctl.conf"
  permissions: "0644"
  owner: "root:root"
  append: true
  permissions: "0644"
  content: |
    net.ipv4.ip_forward = 1

- path: "/opt/metal_ddve/metal_bridge.xml"
  permissions: "0644"
  owner: "root:root"
  content: |
    <network> 
      <name>br0</name> 
      <forward mode="bridge" /> 
      <bridge name="br0" />   
    </network> 

- path: "/opt/metal_ddve/raid6_largest_drives.sh"
  permissions: "0744"
  owner: "root:root"
  content: |
    #!/bin/bash
    DRIVE_SIZE=$(lsblk --bytes | grep -v nvme | grep disk | awk '{print$4}' | sort -nr | head -1)
    RAID_DRIVES=$(lsblk --bytes | grep $DRIVE_SIZE | awk '{print"/dev/"$1}' | tr '\n' ' ')
    NUM_DRIVES=$(echo $RAID_DRIVES | wc -w)
    for DRIVE in $RAID_DRIVES ; do
        mdadm --zero-superblock $DRIVE > /dev/null 2>&1
    done
    mdadm --create --verbose --level=6 --raid-devices=$NUM_DRIVES /dev/md0 $RAID_DRIVES
    mdadm --detail --scan >> /etc/mdadm.conf

- path: "/etc/fstab"
  permissions: "0644"
  owner: "root:root"
  append: true
  content: |
    /dev/md0 /mnt/md0 ext4 defaults,nofail,discard 0 0
    
datasource:
  Ec2:
    strict_id: false
```
