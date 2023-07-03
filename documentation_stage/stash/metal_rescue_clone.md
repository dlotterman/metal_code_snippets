# Flyover of "cloning" one Equinix Metal instance to another with a disk image copy

There may be a variety of reasons why an operator would want to create a disk based clone of an Equinix Metal instance.

Equinix Metal provides all of the primitives needed to BYO install environment, including ecosystems such as:

- [Tinkerbell](https://tinkerbell.org/)
- [FOG](https://fogproject.org/)
- [Foreman](https://theforeman.org/)
- [Cobbler](https://cobbler.github.io/)
- [WDS](https://learn.microsoft.com/en-us/windows/win32/wds/windows-deployment-services-portal)
- [Serva](https://www.vercot.com/~serva/)

This document will cover a path to "cloning" a Linux based Equinix Metal instance that should provide some illumination to the tasks required to begin image / clone based deployments of Equinix Metal instances.

This document is delibarely walking a "simple" path to the goal. There may be many ways to optimize or make more efficient, those are intentionally left to the operators inclination.

It should be noted that disk based cloning has a number of pitfalls not covered in this document. Just because Equinix Metal delivers Bare Metal instances in a cloudy way does not mean that images are the best path to automated, repeatable deployments.

Drivers, disk redudancy, `sysprep`'ing, image storage and other subjects are not covered here. This document only works because we are copying to and from like for like hardware and we are extending the natural use of `cloud-init` as a quick `sysprep`-lite tool

## Provision the Metal instance to be cloned

First we will provision an instance that will be our "Can we clone it?" test subject. We will use the term "target" to describe this system, where the "destination" is the Metal instance that this instance will be cloned TO ->.

- `metal device create --hostname image01-sv --plan c3.medium.x86 --metro sv --operating-system rocky_9 --project-id YOURPROJECTID -t "metalcli"`

Wait for the instance to complete provisioning before continuing on, but we will need the UUID of the instance which can be gathered at any time:

- `metal device list -o json | jq '.[] | select(.hostname=="image01-sv") | .id'`


## Put the target instance in Rescue mode

[Equinix Metal rescue mode is a fantastic operator feature for getting at Metal instances in a Live-OS environment](https://deploy.equinix.com/developers/docs/metal/resilience-recovery/rescue-mode/)

- Rescue API call:
	```
	curl -s -X POST \
	--header 'X-Auth-Token: $YOURTOKEN' \
	--header 'Content-Type: application/json' 'https://api.equinix.com/metal/v1/devices/$UUID/actions'  \
	--data '{"type": "rescue"}'
	```

## SSH into rescue mode

Get the instance's IP address:

- `metal device list -o json |jq  -r '.[] | select(.hostname=="image01-sv") | .ip_addresses[] | select ((.address_family==4) and .public==true) | .address'`

SSH into the rescue instance

- `ssh root@139.178.91.219`

Note that if you have issues SSH'ing into the Rescue Mode instance, you likely have some SSH key confusion. You should be able to SSH in with the same SSH key as you would for a regular Equinix Metal instance, as one of the benifits of the Rescue Mode feature is that Rescue Mode will still pull the instances public SSH keys via cloud-init via the [metadata api
](https://deploy.equinix.com/developers/docs/metal/server-metadata/metadata/).


## Find a format a disk larger than the bootdisk

We will use one of the instance's spare disks to hold the disk image:

```
# lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0    7:0    0 327.6M  1 loop /.modloop
sda      8:0    0 447.1G  0 disk
sdb      8:16   0 447.1G  0 disk
sdc      8:32   0 223.6G  0 disk
├─sdc1   8:33   0     2M  0 part
├─sdc2   8:34   0   1.9G  0 part
└─sdc3   8:35   0 221.7G  0 part
sdd      8:48   0 223.6G  0 disk
```
Here, `sdc` is clearly our OS installed target disk.

We need to add a couple of Alpine packages:
```
# apk add pv xfsprogs lz4 e2fsprogs
fetch http://vendors.edge-a.sv15.metalkube.net/metal/osie/current/repo-x86_64/main/x86_64/APKINDEX.tar.gz
ERROR: http://vendors.edge-a.sv15.metalkube.net/metal/osie/current/repo-x86_64/main: No such file or directory
WARNING: Ignoring http://vendors.edge-a.sv15.metalkube.net/metal/osie/current/repo-x86_64/main: No such file or directory
fetch https://dl-cdn.alpinelinux.org/alpine/v3.15/community/x86_64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.15/main/x86_64/APKINDEX.tar.gz
(1/3) Installing inih (53-r1)
(2/3) Installing libuuid (2.37.4-r0)
(3/3) Installing xfsprogs (5.13.0-r0)
Executing busybox-1.34.1-r7.trigger
OK: 269 MiB in 77 packages
```

Put a filesystem on the larger disk:

```
# mkfs.xfs /dev/sda
meta-data=/dev/sda               isize=512    agcount=4, agsize=29303222 blks
         =                       sectsz=4096  attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=0 inobtcount=0
data     =                       bsize=4096   blocks=117212886, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=57232, version=2
         =                       sectsz=4096  sunit=1 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
Discarding blocks...Done.
```

Mount it:
```
mkdir /tmp/mount
```

```
mount -t xfs /dev/sda /tmp/mount
```

## Copy target's boot disk
```
# dd if=/dev/sdc bs=8M | pv | dd of=/tmp/mount/image01-sv-sdc.dd
1.52GiB 0:00:08 [ 185MiB/s] [             <=>
```

```
# dd if=/dev/sdc bs=8M | pv | dd of=/tmp/mount/image01-sv-sdc.dd
28617+1 records in.00 B/s] [                             <=>                                                           ]
28617+1 records out
 223GiB 0:19:46 [ 192MiB/s] [                           <=>                                                            ]
468862128+0 records in
468862128+0 records out
```

### Compress the disk image
```
# lz4 image01-sv-sdc.dd
Compressed filename will be : image01-sv-sdc.dd.lz4
Read : 13012 MB   ==> 3.07%
```


## Network copy the disk image

There are lots of ways to get the file off the instance. For this example, we will use SFTP included with SSH to copy the file to another Metal instance.

```
# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa
Your public key has been saved in /root/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:REDACTED root@localhost
The key's randomart image is:
+---[RSA 3072]----+
|..               |
|..               |
|. o              |
|REDAC      .     |
|REDAC      .     |
|REDAC      .     |
|REDAC      ..    |
|REDAC      .     |
|REDAC      .     |
+----[SHA256]-----+
```

Where the public key is copied to another Metal instance's `authorized_keys`.

The file can now be SFTP'ed:
```
# scp /tmp/mount/image01-sv-sdc.dd.lz4 dlotterman@139.178.87.218:
The authenticity of host '139.178.87.218 (139.178.87.218)' can't be established.
ED25519 key fingerprint is SHA256:REDAC.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '139.178.87.218' (ED25519) to the list of known hosts.
image01-sv-sdc.dd.lz4                                                                  12%  224MB  50.1MB/s   00:32 ETA
```

## Provision the destination instance:

- `metal device create --hostname image02dst-sv --plan c3.medium.x86 --metro sv --operating-system rocky_9 --project-id $YOURPROJECTID -t "metalcli"`

Wait for it to finish provisioning and be marked as "Ready"

## Put the destination instance in rescue mode:

Get the destination instance's UUID:
```
$ metal device list -o json | jq '.[] | select(.hostname=="image02dst-sv") | .id'
"252c24e2-3e9a-4c40-b4d2-9dff6617dd3e"
```

Put the destination box in Rescue mode:
```
curl -s -X POST \
--header 'X-Auth-Token: YOURTOKEN' \
--header 'Content-Type: application/json' 'https://api.equinix.com/metal/v1/devices/252c24e2-3e9a-4c40-b4d2-9dff6617dd3e/actions'  \
--data '{"type": "rescue"}'
```

It can take 3-5 minutes for the box to reboot correctly into Rescue mode.

Get the destination boxes IP:
```
$ metal device list -o json |jq  -r '.[] | select(.hostname=="image02dst-sv") | .ip_addresses[] | select ((.address_family==4) and .public==true) | .address'
139.178.91.19
```

Install packages:
```
# apk add pv xfsprogs lz4 e2fsprogs
fetch http://vendors.edge-a.sv15.metalkube.net/metal/osie/current/repo-x86_64/main/x86_64/APKINDEX.tar.gz
ERROR: http://vendors.edge-a.sv15.metalkube.net/metal/osie/current/repo-x86_64/main: No such file or directory
WARNING: Ignoring http://vendors.edge-a.sv15.metalkube.net/metal/osie/current/repo-x86_64/main: No such file or directory
fetch https://dl-cdn.alpinelinux.org/alpine/v3.15/community/x86_64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.15/main/x86_64/APKINDEX.tar.gz
(1/5) Installing lz4 (1.9.3-r1)
(2/5) Installing pv (1.6.20-r0)
(3/5) Installing inih (53-r1)
(4/5) Installing libuuid (2.37.4-r0)
(5/5) Installing xfsprogs (5.13.0-r0)
Executing busybox-1.34.1-r7.trigger
OK: 269 MiB in 79 packages
```

Format and mount the spare drive:
```
# lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0    7:0    0 327.6M  1 loop /.modloop
sda      8:0    0 447.1G  0 disk
sdb      8:16   0 447.1G  0 disk
sdc      8:32   0 223.6G  0 disk
├─sdc1   8:33   0     2M  0 part
├─sdc2   8:34   0   1.9G  0 part
└─sdc3   8:35   0 221.7G  0 part
sdd      8:48   0 223.6G  0 disk
```

```
# mkfs.xfs /dev/sda
meta-data=/dev/sda               isize=512    agcount=4, agsize=29303222 blks
         =                       sectsz=4096  attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=0 inobtcount=0
data     =                       bsize=4096   blocks=117212886, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=57232, version=2
         =                       sectsz=4096  sunit=1 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
Discarding blocks...Done.
```


- `# mkdir /tmp/mount`
- `# mount -t xfs /dev/sda /tmp/mount`

If using SSH / SFTP to transfer, generate a new SSH key and add the public key to the instance hosting the image.

Copy the file to the destination instance:

```
localhost:~# scp dlotterman@139.178.87.218:image01-sv-sdc.dd.lz4  /tmp/mount/
The authenticity of host '139.178.87.218 (139.178.87.218)' can't be established.
ED25519 key fingerprint is SHA256:REDAC.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '139.178.87.218' (ED25519) to the list of known hosts.
image01-sv-sdc.dd.lz4                                                                  79% 1476MB  56.2MB/s   00:06 ETA
```

Use lsblk to identify which drive is marked as the boot drive, the Metal installed OS show us that `sdc` is marked as our boot drive.
```
# lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0    7:0    0 327.6M  1 loop /.modloop
sda      8:0    0 447.1G  0 disk /tmp/mount
sdb      8:16   0 447.1G  0 disk
sdc      8:32   0 223.6G  0 disk
├─sdc1   8:33   0     2M  0 part
├─sdc2   8:34   0   1.9G  0 part
└─sdc3   8:35   0 221.7G  0 part
sdd      8:48   0 223.6G  0 disk
```

Copy the disk image over the boot drive:
```
# dd if=/tmp/mount/image01-sv-sdc.dd bs=8M | pv | dd of=/dev/sdc bs=8M
5.04GiB 0:00:03 [1.52GiB/s] [     <=>                                                                                  ]
```

Mount the destination disk's filesystem:
```
localhost:~# mkdir /tmp/sdc
localhost:~# mount -t ext4 /dev/sdc3 /tmp/sdc
```

## Clean cloud-init and other cleanup


Chroot into the destination filesystem:
```
# chroot /tmp/sdc/ /bin/bash
basename: missing operand
Try 'basename --help' for more information.
```

```
Clean up cloud-init
`localhost:/# cloud-init clean --logs`
```

```
localhost:/# echo "image02dst-sv-clone" > /etc/hostname
```

Exit the container:
```
localhost:/# exit
exit
```

Reboot the instance out of Rescue mode:

## SSH into the destination instance

Because you SSH'ed into the Rescue Live-OS, your SSH client is likely already has an entry in it's `known_hosts` file that will need to be cleaned out.
```
> ssh root@139.178.91.19
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ECDSA key sent by the remote host is
SHA256:REDAC.
Please contact your system administrator.
Add correct host key in C:\\Users\\Daniel Lotterman/.ssh/known_hosts to get rid of this message.
Offending ECDSA key in C:\\Users\\Daniel Lotterman/.ssh/known_hosts:4
ECDSA host key for 139.178.91.19 has changed and you have requested strict checking.
Host key verification failed.
```

Once that is cleared, you can SSH into the destionation instance and then confirm that the destination host has the target hosts OS's by looking at the BEGINNING of the system log file:
```
# head /var/log/messages
Jun 29 17:15:12 image01-sv kernel: Linux version 5.14.0-284.11.1.el9_2.x86_64 (mockbuild@iad1-prod-build001.bld.equ.rockylinux.org) (gcc (GCC) 11.3.1 20221121 (Red Hat 11.3.1-4), GNU ld version 2.35.2-37.el9) #1 SMP PREEMPT_DYNAMIC Tue May 9 17:09:15 UTC 2023
Jun 29 17:15:12 image01-sv kernel: The list of certified hardware and cloud instances for Enterprise Linux 9 can be viewed at the Red Hat Ecosystem Catalog, https://catalog.redhat.com.
Jun 29 17:15:12 image01-sv kernel: Command line: BOOT_IMAGE=/boot/vmlinuz root=UUID=42dd77ab-0562-4d4d-9fed-ede48344a4cf ro console=tty0 console=ttyS1,115200n8 rd.auto rd.auto=1
Jun 29 17:15:12 image01-sv kernel: x86/fpu: Supporting XSAVE feature 0x001: 'x87 floating point registers'
Jun 29 17:15:12 image01-sv kernel: x86/fpu: Supporting XSAVE feature 0x002: 'SSE registers'
Jun 29 17:15:12 image01-sv kernel: x86/fpu: Supporting XSAVE feature 0x004: 'AVX registers'
Jun 29 17:15:12 image01-sv kernel: x86/fpu: xstate_offset[2]:  576, xstate_sizes[2]:  256
Jun 29 17:15:12 image01-sv kernel: x86/fpu: Enabled xstate features 0x7, context size is 832 bytes, using 'compacted' format.
Jun 29 17:15:12 image01-sv kernel: signal: max sigframe size: 1776
Jun 29 17:15:12 image01-sv kernel: BIOS-provided physical RAM map
```

You can then confirm that the destination host has hostname update and new instance's network configuration:

```
# tail /var/log/messages
Jun 29 20:55:20 image02dst-sv-clone sshd[1828]: main: sshd: ssh-rsa algorithm is disabled
Jun 29 20:55:27 image02dst-sv-clone sshd[1830]: main: sshd: ssh-rsa algorithm is disabled
Jun 29 20:55:31 image02dst-sv-clone sshd[1832]: main: sshd: ssh-rsa algorithm is disabled
Jun 29 20:55:32 image02dst-sv-clone sshd[1834]: main: sshd: ssh-rsa algorithm is disabled
Jun 29 20:55:44 image02dst-sv-clone sshd[1836]: main: sshd: ssh-rsa algorithm is disabled
```

```
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens3f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 40:a6:b7:74:c2:d0 brd ff:ff:ff:ff:ff:ff
    altname enp65s0f0
    inet 139.178.91.19/31 scope global dynamic noprefixroute ens3f0
       valid_lft 172350sec preferred_lft 172350sec
    inet6 fe80::681:4323:d809:2f21/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
3: ens3f1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 40:a6:b7:74:c2:d1 brd ff:ff:ff:ff:ff:ff
    altname enp65s0f1
4: bond0: <NO-CARRIER,BROADCAST,MULTICAST,MASTER,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether ca:aa:67:a9:c2:c7 brd ff:ff:ff:ff:ff:ff
    inet 139.178.91.219/31 scope global noprefixroute bond0
       valid_lft forever preferred_lft forever
    inet 10.67.63.3/31 scope global noprefixroute bond0:0
       valid_lft forever preferred_lft forever
    inet6 2604:1380:1000:1200::1/127 scope global tentative noprefixroute
       valid_lft forever preferred_lft forever
```
