# Disabling the Serial port enalbling the SOS feature on Linux instances

For a variety of reasons, Operators may want to disable the ability to log into their services via the [Equinix Metal SOS](https://deploy.equinix.com/developers/docs/metal/resilience-recovery/serial-over-ssh/).

This guide uses the stock Metal `ubuntu_22_04` image:

## /etc/default/grub

The original should look like:

```
# cat /etc/default/grub
GRUB_CMDLINE_LINUX='console=tty0 console=ttyS1,115200n8 modprobe.blacklist=igb modprobe.blacklist=rndis_host'
GRUB_SERIAL_COMMAND='serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1'
```

Edit this so it looks like:

```
GRUB_CMDLINE_LINUX='modprobe.blacklist=igb modprobe.blacklist=rndis_host'
```

Run:

```
update-grub
```

Reboot

```
reboot
```

And console output from the instance should stop once it gets past the hardware POST, as in when the host OS loads.
