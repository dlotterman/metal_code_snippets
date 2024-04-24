# Setting Real Time Kernel Settings with Equinix Metal Linux (Ubuntu)

## Update `defaul/grub`

As of the time of writing (04/2024), the `/etc/default/grub` file included with Ubuntu and other Equinix managed linux Images has minor incorrections / bugs. These are known and being tracked internally, hopefully to be fixed soon.

It should look like:

```
$ cat /etc/default/grub
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=3
GRUB_TERMINAL="serial console"
GRUB_CMDLINE_LINUX='console=tty0 console=ttyS1,115200n8 modprobe.blacklist=igb modprobe.blacklist=rndis_host isolcpus=3,4 nohz=on nohz_full=3,4 rcu_nocbs=3,4 rcu_nocb_poll=3,4'
GRUB_SERIAL_COMMAND='serial --unit=1 --speed=115200 --word=8 --parity=no --stop=1'
```

From the Metal default (as of 04/2024), note the `--unit=1` change as well as the addition of `GRUB_TERMINAL` and above lines.

## Update grub
```
$ sudo update-grub
Sourcing file `/etc/default/grub'
Sourcing file `/etc/default/grub.d/init-select.cfg'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-5.15.0-105-generic
Found initrd image: /boot/initrd.img-5.15.0-105-generic
Found linux image: /boot/vmlinuz-5.15.0-101-generic
Found initrd image: /boot/initrd.img-5.15.0-101-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
```

## Reboot
```
$ sudo reboot
```

## Confirm
```
$ cat /sys/devices/system/cpu/isolated
3-4
```
```
$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-5.15.0-105-generic root=UUID=2851390d-76a1-40f8-9ebe-869a516bb8f5 ro console=tty0 console=ttyS1,115200n8 modprobe.blacklist=igb modprobe.blacklist=rndis_host isolcpus=3,4 nohz=on nohz_full=3,4 rcu_nocbs=3,4 rcu_nocb_poll=3,4
```
