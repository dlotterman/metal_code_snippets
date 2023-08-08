# Metallized Enterprise Linux Installchain for iPXE

This folder is an attempt to collect a variety of [resources](https://gitlab.com/dlotterman/unified_el_ipxe) in one place to provide a single, as simple place to start a production ready Installchain for installing [Enterprise Linux](https://en.wikipedia.org/wiki/Category:Enterprise_Linux_distributions) to [Equinix Metal](https://deploy.equinix.com/product/bare-metal/) on-demand instances via it's [custom_ipxe](https://deploy.equinix.com/developers/docs/metal/operating-systems/custom-ipxe/) feature with a strong enough opinion to illustrate what is possible.

This folder is not a supported resource, it has no official association with Enterprise Linux or Equinix Metal, it is for reference only.

This documentation expects to be pointed at an unpacked EL ISO (please include hidden files like `.treeinfo` files) that is hosted on a public HTTP endpoint, with hosted iPXE files. The aim is to reduce and document this burden over time. When closer to complete, this folder may move into it's own repo at some point.

Put simply, this should give you one URL to use with the `custom_ipxe` feature that will install to any Metal instance in any hardware state and return a production-like ready instance. The natural starting place is [unified-el.ipxe](ipxe/unified-el.ipxe), where following the referenced files should paint the picture for a capable operator.

**Similarities to Metal EL images**
- Metal `layer-3` [bonded mode supported](https://deploy.equinix.com/developers/docs/metal/networking/server-level-networking/)
    - [Public IPv4](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#public-ipv4-subnet)
    - [Private IPv4](https://deploy.equinix.com/developers/docs/metal/networking/ip-addresses/#private-ipv4-management-subnets)
    - (Missing!) No IPv6
    - Metal ["4x port" configurations](https://deploy.equinix.com/product/servers/n3-xlarge/) supported
- UEFI+BIOS Support in a single iPXE URL
- Zero touch EL install to Equinix Metal (once Installchain is deployed)
- Metal [SOS / OOB](https://deploy.equinix.com/developers/docs/metal/resilience-recovery/serial-over-ssh/) output configured
- Pulls configuration from `https://metadata.platformequinix.com/metadata`
- Broad hardware coverage

**Differences from Metal EL images**
- RAID-1 Boot (via mdadm)
    - For NVMe only instances (n3.xlarge.x86), RAID smallest NVMe
    - For tiered systems (like s3.xlarge.x86), smallest SSD is chosen
    - All disks are cleared of previous partition data
        - Non-boot disks are otherwise left alone
- Metal [SSH Keys](https://deploy.equinix.com/developers/docs/metal/accounts/ssh-keys/) for `adminuser`
    - `root` responsibilities and *SSH Keys* moved to `adminuser` with global `sudo` access
- Instead of `Userdata` or `Cloud-init`, implements a [unified_el_ipxe model](https://gitlab.com/dlotterman/unified_el_ipxe) model
    - Networking configuration is done as late-stage as possible, AKA after fresh `dnf update -y && reboot`
        - Avoids as many complicated problems as possible through the simplest, most actrively tested path which is current from vendor in userland

## Provision Time and validating the install

This depends heavily on the Metal configuration and the network speed of the hosted assets, but install time will likely be between "8 to 20 minutes". This could be shorterned with work, OS install times of ""~3 minutes"" are possible plus Bare Metal reboot loop time.

The provision is considered complete when the `unified_el_init` *systemd* service is completeted, which will enable SSH, when the operator can then ssh in as `adminuser`. It should be highlighted that no listen port is open on the server in this lifecycle untill SSH is enabled

### TODO
- Write real documentation
- Normalize kickstart
    - Should start with UEFI v BIOS and re-join a single KS afterwards
- Clean shellisms
- Write a container file that provided an ISO file, unpacks and glues this repo together for a targetable endpoint
