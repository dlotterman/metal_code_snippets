#### Equinix Metal iPXE OS Checklist

This is a quick checklist of the easy to forget "shoulds" of an OS install via iPXE to an Equinix Metal instance, where those "shoulds" fall  in line with Equinix Metal image expectations or best practices.

* bonding
    * lacp mode
    * fast rate, miimon
    * dynamic from Metadata
* networking
    * DNS
    * private 10.0.0.0/8 routing
    * IPv6
* serial output to com2 / ttsyS1
* cloud-init
    * userdata
    * ssh-keys
* disk install target
    * install to smallest disks
    * linux disk ordering?
    * ignore nvme (for s3.xlarge.x86)
    * software RAID boot disks if reasonably possible
