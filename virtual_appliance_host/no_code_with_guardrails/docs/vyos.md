# VyOS ISO creation

`NCB` can create VyOS installation media for you. This includes building the ISO from source, and unpacking and hosting the assets by public http.

Simply add the tag `ncb_vyos` to the NCB instance in the Metal portal, and the `NCB` instance will built it automatically, and expose the assets via the `http://$M_PUBL_IP:90/vyos/` and an iPXE script via `http://$M_PUBL_IP:90/vyos/vyos.ipxe`, where `$M_PUBL_IP` is the Public IP of the `NCB` instance.

The steps `NCB` follows are based of [this guide](https://blog.vyos.io/introducing-the-image-build-flavor-system?utm_medium=email&_hsenc=p2ANqtz--cwWxln0yduVs8XGZ0QP_g1DO49i0YblM15ka7g35JEQrFQ3bE7k5OQIDq-zNUFY2b5tsoDIffOLvCxgxEsMITk2acUQ&_hsmi=306480568&utm_content=306480568&utm_source=hs_email#cb5-1).


## Provisioning an instance with the built iPXE

Just enter the `http://$M_PUBL_IP:90/vyos/vyos.ipxe` as the iPXE URL in the `custom_ipxe` field when provisioning an instance.

Once the provisioning is initiated, hop on the [SOS console](https://deploy.equinix.com/developers/docs/metal/resilience-recovery/serial-over-ssh/) and watch the instance boot into the VyOS installer.

Sometimes the SOS console needs the instance to reboot to catchup with the serial output. Just enable ["Always PXE option"](https://deploy.equinix.com/developers/docs/metal/operating-systems/custom-ipxe/#persisting-pxe) and reboot the instance. Wait 3-5ish minutes for the RAM collection to clear and you should see the instance proceed through it's POST, catch the iPXE hook and boot into the VyOS installer.

Remeber to disable the ["Always iPXE"](https://deploy.equinix.com/developers/docs/metal/operating-systems/custom-ipxe/#persisting-pxe) flag afterwards.
## Fixing 1.5-rolling serial issues

It seems that regardless of build options, the 1.5-rolling installer is fixated on specifying `ttyS0` as the serial interface for the console, where it should be `ttyS1`. This can be hacked over by doing the following AFTER the `image install` is complete, but before you issue the `reboot` command to reboot into the installed VyOS environment.

1. Find the mirrored device (if you installed to a RAID-1 mirror, otherwise just choose your `/dev/sda`)
```
Welcome to VyOS - vyos ttyS1

vyos login: vyos
Password:
Welcome to VyOS!

   ┌── ┐
   . VyOS 1.5-rolling-202405142151
   └ ──┘  current

 * Documentation:  https://docs.vyos.io/en/latest
 * Project news:   https://blog.vyos.io
 * Bug reports:    https://vyos.dev

You can change this banner using "set system login banner post-login" command.

VyOS is a free software distribution that includes multiple components,
you can check individual component licenses under /usr/share/doc/*/copyright
```
```
vyos@vyos:~$ install image
Welcome to VyOS installation!
This command will install VyOS to your permanent storage.
Would you like to continue? [y/N] y
What would you like to name this image? (Default: 1.5-rolling-202405142151)
Please enter a password for the "vyos" user:
Please confirm password for the "vyos" user:
What console should be used by default? (K: KVM, S: Serial)? (Default: K) S
Probing disks
4 disk(s) found
Would you like to configure RAID-1 mirroring? [Y/n] y
The following disks were found:
        /dev/sda (223.6 GB)
        /dev/sdb (447.1 GB)
Would you like to configure RAID-1 mirroring on them? [Y/n] n
Would you like to choose two disks for RAID-1 mirroring? [Y/n] y
Disks available:
        1: /dev/sda     (223.6 GB)
        2: /dev/sdb     (447.1 GB)
        3: /dev/sdc     (223.6 GB)
        4: /dev/sdd     (447.1 GB)
Select first disk: 1
Remaining disks:
        1: /dev/sdb     (447.1 GB)
        2: /dev/sdc     (223.6 GB)
        3: /dev/sdd     (447.1 GB)
Select second disk: 2
Installation will delete all data on both drives. Continue? [y/N] y
Searching for data from previous installations
No previous installation found
Creating partitions on /dev/sda
Creating partition table...
Creating partitions on /dev/sdc
Creating partition table...
Creating RAID array
Updating initramfs
Creating filesystem on RAID array
The following config files are available for boot:
        1: /opt/vyatta/etc/config/config.boot
        2: /opt/vyatta/etc/config.boot.default
Which file would you like as boot config? (Default: 1) 1
Creating temporary directories
Mounting new partitions
Creating a configuration file
Copying system image files
Installing GRUB configuration files
Installing GRUB to the drives
Cleaning up
Unmounting target filesystems
Removing temporary files
The image installed successfully; please reboot now.
```
```
vyos@vyos:~$ cat /proc/mdstat
Personalities : [raid0] [raid1] [raid10] [raid6] [raid5] [raid4]
md0 : active raid1 sdc3[1] sda3[0]
      234165696 blocks super 1.0 [2/2] [UU]
      [==>..................]  resync = 10.6% (24943424/234165696) finish=17.5min speed=198720K/sec
      bitmap: 2/2 pages [8KB], 65536KB chunk

unused devices: <none>
vyos@vyos:~$ mkdir /tmp/md
vyos@vyos:~$ sudo mount /dev/md0 /tmp/md
vyos@vyos:~$ sudo vim /tmp/md/boot/grub/grub.cfg.d/20-vyos-defaults-autoload.cfg
```
	a. Change the `set console_num="0"` to `set console_num="1"`:
```
set console_type="ttyS"
export console_type
set console_num="1"
export console_num
```
2. Reboot
