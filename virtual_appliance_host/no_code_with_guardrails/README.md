# "No Code" + "Safe" Virtual Appliance Host for Equinix Metal

When evaluating or working with Equinix Metal, operators often want a "fastest" path to running an application or device inside of the Equinix Metal platform, where the learning curve of the Equinix Metal platform may make that a "more toil involved" task than is desired.

The idea being an operator should be able to copy the cloud-init from this resource, and without having to modify anything, should receive a `rocky_9`, `alma_9` or `rhel_9` instance with these configurations applied and immediately ready for use.

This resource is intended to provide a documented "short but safe path" to running a "bastion" role on an Equinix Metal instance that provides:
- Management UI via Cockpit
- VM hosting via KVM
- Container hosting via podman
- Automatic Updates via dnf-Automatic
- Basic securitization (root -> adminuser, firewall, user-lockout etc)
- Mounts largest non-HDD disk to `/mnt/util/`
- Network Management and pre-plumbing
    - Maintains the Equinix Metal bond
    - DHCP in guest network
    - IP Configuration dynamic based on hostname, e.g a host launched as bn-am-22 will use `22` as it's inside IP for all networks
    - Forward DNS in guest network (via hijack of libvirt's dnsmasq)
    - Reverse DNS in guest network (via hijack of libvirt's dnsmasq)
        -
        ```
        dig -x 192.168.122.55 @192.168.122.1
        ...
        ;; ANSWER SECTION:
        55.122.168.192.in-addr.arpa. 0  IN      PTR     host-55.inside.em.com.
        ```
    - Automatic inclusion in pre-defined networks
- HTTP endpoint via NGINX
    - Public Internet exposed HTTP endpoint (port `80`)
    - Private (Backend Transfer + VLAN only, port `81`) exposed HTTP endpoint (Not open to internet)

## Quick Walkthrough

- [Provision an instance with](https://deploy.equinix.com/developers/docs/metal/server-metadata/user-data/) the [el9_no_code_safety_first_appliance.yaml](cloud-inits/el9_no_code_safety_first_appliance.yaml) in the `cloud-init` directory in this folder.
    - To provision an instance with the [Equinix Metal CLI](https://deploy.equinix.com/developers/docs/metal/libraries/cli/)
        -
        ```
        metal device create --hostname bn-gw-sv-11 --plan n2.xlarge.x86 --metro sv --operating-system alma_9 --userdata-file ~/metal_code_snippets/virtual_appliance_host/no_code_with_guardrails/cloud_inits/el9_no_code_safety_first_appliance_host.mime --project-id $YOURPROJID -t "metalcli"
        ```
- The instance will provision as normal
- `adminuser` will replace normal use of `root`, where `root`'s password and SSH keys are copied to `adminuser`
- The instance will update itself to current (equivalent of `dnf upgrade -y && reboot`
- The instance will install packages
- The instance will turnup the firewall
    - This includes watching port `22` for aggressive connection sources and blocking them
- The instance will begin to lockdown `SSH`
- The instance will configure user lockout
- The instance will apply automatic updates
- The instance will mount it's largest non-HHD drive to `/mnt/util/`
- The instance will tear down the pre-configured networking
- The instance will re-build network with a traditional linux bridge on the bond
    - This is done before applying addressing, allowing the bond + bridge to expose native + VLANs
    - The instance will apply pre-configured networking according to the EM SA Network Schema (below)
- The instance will mangle some `libvirt` configuration to make it ready to consume
    - This includes Forward / Reverse DNS
- The instance will configure NGINX for public and private endpoints

## EM SA Network Schema:
| Purpose      | VLAN      | Default Layer-3    |
|--------------|-----------|--------------------|
| `mgmt_a`     | `3880`    | `172.16.100.0/24`  |
| `mgmt_b`     | `3780`    | `192.168.101.0/24` |
| `storage_a`  | `3870`    | `172.16.253.0/24`  |
| `storage_b`  | `3770`    | `192.168.252.0/24` |
| `local_a`    | `3860`    | `172.16.251.0/24`  |
| `local_b`    | `3760`    | `192.168.250.0/24` |
| `inter_a`    | `3850`    | `172.16.249.0/24`  |
| `inter_b`    | `3750`    | `192.168.248.0/24` |
