# Using keepalived's vmac feature with Equinix Metal

Intro / boilerplate yada yada to follow

The guide is meant to be copy paste-able if you follow the spirit of it. Each `code` block should be an entirely copy paste-able chunk of code if done in sequence. The only modification needed should be the first three env variables noted below.

## Random links

- https://github.com/acassen/keepalived/issues/1424
- https://github.com/acassen/keepalived/issues/1969
    - Great recent config references
- https://github.com/acassen/keepalived/issues/364
- https://github.com/acassen/keepalived/blob/master/doc/NOTE_vrrp_vmac.txt
- https://blog.kintone.io/entry/bird
- https://erunix.wordpress.com/2021/11/11/bird2-config-filter/
- https://github.com/acassen/keepalived/issues/1743
- https://www.linode.com/docs/products/compute/compute-instances/guides/failover-bgp-with-keepalived/
- https://www.claudiokuenzler.com/blog/994/how-to-keepalived-execute-scripts-non-root-user
- https://bsdrp.net/documentation/examples/bgp_route_reflector_and_confederation_using_quagga_and_bird

## Requirements

This guide assumes a modern `bash` shell with [metal-cli](https://deploy.equinix.com/developers/docs/metal/libraries/cli/), and `jq` installed. It assumes ssh with [Metal SSHK-eys](https://deploy.equinix.com/developers/docs/metal/accounts/ssh-keys/)

Optional checkout of this repo for [cloud-init](https://github.com/dlotterman/metal_code_snippets/tree/main/boiler_plate_cloud_inits) an extra choice.

- Networks taken from [GTST Network Schema](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/em_sa_network_schema.md)

## Routers

These will be out standing "routers" that will speak `BGP` via a `keepalived` VIP.

### ENVs / Configuration
You really only need to set the first three envs (`METAL_INT`, `METAL_PROJ_ID` and `OBSERVER_IP`, `INSTANCE_PAIR`), the rest will assume / build from those inputs presuming `metal` is installed correct (see `metal-cli` above).

This document presumes you will launch 3x instances, where 2x of those instances, the *"router"* will be based of the below environment variables.

Copy the below to a scratch pad and edit them appropriately. The *"observer"* instance will be launched later (below)


```
METAL_INT=###YOUR_INT_HERE
METAL_PROJ_ID=####YOUR_PROJ_ID_HERE
OBSERVER_IP=##YOUR_OBSERVER_INT_HERE
INSTANCE_PAIR=##THE INT OF THE OTHER INSTANCE, so if the other router's "int" is 10, put ten here.
METAL_HOSTNAME=router-$METAL_INT
METAL_MGMT_A_VLAN=3880
METAL_INTER_A_VLAN=3850
METAL_METRO=sv
MGMT_A_IP=172.16.100
INTER_A_IP=172.17.16
INTER_A_VIP=172.17.16.230/32
SIDE_A_NETWORK=172.16.20.0/24
SIDE_Z_NETWORK=172.16.40.0/24

```

### Launch the Metal instances

**With** *cloud-init*:
```
metal device create --hostname $METAL_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system ubuntu_22_04 --project-id $METAL_PROJ_ID -t "metalcli,keepalived,bird" --userdata-file ~/code/github/metal_code_snippets/boiler_plate_cloud_inits/ubuntu_22_04_v1.mime
```

**Without** *cloud-init*:
```
metal device create --hostname $METAL_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system ubuntu_22_04 --project-id $METAL_PROJ_ID -t "metalcli,keepalived,bird"
```

### Create VLANS
```
metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $METAL_MGMT_A_VLAN
metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $METAL_INTER_A_VLAN
```

### Build environment metadata

```
HOSTNAME_ID=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id')

HOSTNAME_BOND0=$(metal -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id')

HOSTNAME_PIP0=$(metal device get -i $HOSTNAME_ID -o json | jq -r '.ip_addresses[] | select((.public==true) and .address_family==4) | .address')
```

#### Optional, look at Metal instances (jq required)
```
metal device list -p $METAL_PROJ_ID -o json | jq -r '.[] | .id + "\t" + .plan.slug + "\t" + .facility.code + "\t" + (.ip_addresses[]| select((.public==true) and .address_family==4) | .address|tostring) + "\t" + (.ip_addresses[]| select((.public==false) and .address_family==4) | .address|tostring) + "\t" + .hostname[0:15] + "\t\t" + .state[0:6] + "\t" +  .operating_system.slug[0:8]'
```

### Attach VLANs to Metal instance's ports
```
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_MGMT_A_VLAN && \
sleep 10 && \
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_INTER_A_VLAN
```

### Prepare Metal instances

```
ssh adminuser@$HOSTNAME_PIP0 "sudo apt-get update && sudo apt-get upgrade -y && sudo reboot"
```

Wait for reboot:

```
ssh adminuser@$HOSTNAME_PIP0 "sudo apt-get install keepalived frr frr-doc -y && sudo systemctl stop frr"
```
```
ssh adminuser@$HOSTNAME_PIP0 "sudo systemctl stop frr"

ssh adminuser@$HOSTNAME_PIP0 "modprobe 8021q && echo "8021q" | sudo tee -a /etc/modules"
```

```
ssh adminuser@$HOSTNAME_PIP0 "sudo ip link add link bond0 name bond0.$METAL_MGMT_A_VLAN type vlan id $METAL_MGMT_A_VLAN && sudo ip addr add $MGMT_A_IP.$METAL_INT/24 dev bond0.$METAL_MGMT_A_VLAN && sudo ip link set dev bond0.$METAL_MGMT_A_VLAN up"

ssh adminuser@$HOSTNAME_PIP0 "sudo ip link add link bond0 name bond0.$METAL_INTER_A_VLAN type vlan id $METAL_INTER_A_VLAN && sudo ip addr add $INTER_A_IP.$METAL_INT/24 dev bond0.$METAL_INTER_A_VLAN && sudo ip link set dev bond0.$METAL_INTER_A_VLAN up"

ssh adminuser@$HOSTNAME_PIP0 "sudo ip link set bond0 mtu 9000 && sudo ufw allow in on bond0.$METAL_MGMT_A_VLAN && sudo ufw allow in on bond0.$METAL_INTER_A_VLAN && sudo ufw allow from $INTER_A_IP.0/24"
```
### Template keepalived
```
echo "
global_defs {
    log_unknown_vrids
    enable_script_security
    script_user adminuser
    max_auto_priority 40
	nftables
	nftables_counters
}

vrrp_instance VC_1_VI_1 {
    interface bond0.$METAL_INTER_A_VLAN
    state MASTER
    priority $METAL_INT
    advert_int 1

    use_vmac
    vmac_xmit_base

    virtual_router_id 10
    unicast_src_ip $INTER_A_IP.$METAL_INT
    unicast_peer {
        $INTER_A_IP.$INSTANCE_PAIR
    }

    authentication {
        auth_type PASS
        auth_pass EVKD
    }
    virtual_ipaddress {
        $INTER_A_VIP
    }

    notify_stop \"/var/tmp/notify_keepalived.sh Fault\"
    notify_backup \"/var/tmp/notify_keepalived.sh Backup\"
    notify_master \"/var/tmp/notify_keepalived.sh Master\"

}
" | ssh adminuser@$HOSTNAME_PIP0 "sudo tee /etc/keepalived/keepalived.conf"
```

### Template keepalived / frr script

Credit to linode link at top for this.
```
echo '#!/bin/bash

logger "notify_keepalived: starting keepalived notify script, state: $1"

function check_state {

        if [[ "$state" == "Master" ]]; then
                logger "notify_keepalived: attempting to start frr via keepalived notify script"
                sudo systemctl restart frr
        else
                logger "notify_keepalived: attempting to stop frr via keepalived notify script"
                sudo systemctl stop frr
        fi
}

function main {
        local state=$1
        case $state in
        Master)
                check_state Master;;
        Backup)
                check_state Backup;;
        Fault)
                check_state Fault;;
        *)
                echo "[ERR] Provided arguement is invalid"
        esac
}
main "$1"
' | ssh adminuser@$HOSTNAME_PIP0 "tee /var/tmp/notify_keepalived.sh"
```

```
ssh adminuser@$HOSTNAME_PIP0 "sudo chmod 0755 /var/tmp/notify_keepalived.sh"
```


### Add local Network
```
ssh adminuser@$HOSTNAME_PIP0 "sudo ip addr add $SIDE_A_NETWORK dev lo:0"
```

### Template frr
```
echo "
bgpd=yes
zebra=yes
ospfd=no
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
bfdd=no
fabricd=no
vrrpd=no
pathd=no
vtysh_enable=yes
zebra_options="  -A 127.0.0.1 -s 90000000"
bgpd_options="   -A 127.0.0.1"
staticd_options="-A 127.0.0.1"
bfdd_options="   -A 127.0.0.1"
pathd_options="  -A 127.0.0.1"
" | ssh adminuser@$HOSTNAME_PIP0 "sudo tee /etc/frr/daemons"
```

```
echo "
log syslog debug
frr defaults traditional
service integrated-vtysh-config
debug bgp neighbor-events
debug bgp updates
debug bgp zebra
debug bgp updates in
debug bgp updates out
!
ip router-id $(echo $INTER_A_VIP | awk -F "/" '{print$1}')
!
router bgp 65202
 bgp log-neighbor-changes
 bgp router-id $(echo $INTER_A_VIP | awk -F "/" '{print$1}')
 no bgp network import-check
 no bgp ebgp-requires-policy
 neighbor MRouters peer-group
 neighbor MRouters remote-as 65001
 neighbor MRouters ebgp-multihop 5
 neighbor MRouters password Equinixmetal05
 neighbor $OBSERVER_IP peer-group MRouters
 neighbor $OBSERVER_IP remote-as 65001
 !
 address-family ipv4 unicast
  redistribute connected
  neighbor $OBSERVER_IP activate
  no neighbor MRouters send-community
  neighbor MRouters route-map ALLOW-ALL in
  neighbor MRouters route-map A_SIDE_ALLOW_MAP out
  no neighbor $OBSERVER_IP send-community
 exit-address-family
 !
!
ip prefix-list A_SIDE_ALLOW_LIST seq 5 permit $SIDE_A_NETWORK
!
route-map ALLOW-ALL permit 100
!
route-map A_SIDE_ALLOW_MAP permit 100
    match ip address prefix-list A_SIDE_ALLOW_LIST
!
line vty
!
end

" | ssh adminuser@$HOSTNAME_PIP0 "sudo tee /etc/frr/frr.conf"
```

### Start keepalived
```
ssh adminuser@$HOSTNAME_PIP0 "sudo systemctl start keepalived"
```

```
ssh adminuser@$HOSTNAME_PIP0 "sudo systemctl start frr"
```

## Observer
```
METAL_INT=###
METAL_PROJ_ID=###
METAL_HOSTNAME=observer-$METAL_INT
METAL_MGMT_A_VLAN=3880
METAL_INTER_A_VLAN=3850
METAL_METRO=sv
MGMT_A_IP=172.16.100
INTER_A_IP=172.17.16
INTER_A_VIP=172.17.16.230/32
SIDE_Z_NETWORK=172.16.40.0/24
```

With `cloud-init`:
```
metal device create --hostname $METAL_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system ubuntu_22_04 --project-id $METAL_PROJ_ID -t "metalcli,frr" --userdata-file ~/code/github/metal_code_snippets/boiler_plate_cloud_inits/ubuntu_22_04_v1.mime
```

or without `cloud-init`:
```
metal device create --hostname $METAL_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system ubuntu_22_04 --project-id $METAL_PROJ_ID -t "metalcli,frr"
```

### Create VLANs

```
metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $METAL_MGMT_A_VLAN
metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $METAL_INTER_A_VLAN
```

#### Build environment metadata
```
HOSTNAME_ID=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id')

HOSTNAME_BOND0=$(metal -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id')

HOSTNAME_PIP0=$(metal device get -i $HOSTNAME_ID -o json | jq -r '.ip_addresses[] | select((.public==true) and .address_family==4) | .address')
```

#### Optional list
```
metal device list -p $METAL_PROJ_ID -o json | jq -r '.[] | .id + "\t" + .plan.slug + "\t" + .facility.code + "\t" + (.ip_addresses[]| select((.public==true) and .address_family==4) | .address|tostring) + "\t" + (.ip_addresses[]| select((.public==false) and .address_family==4) | .address|tostring) + "\t" + .hostname[0:15] + "\t\t" + .state[0:6] + "\t" +  .operating_system.slug[0:8]'
```

### VLAN
```
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_MGMT_A_VLAN && \
sleep 10 && \
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_INTER_A_VLAN
```

### Stuff
```
ssh adminuser@$HOSTNAME_PIP0 "sudo apt-get update && sudo apt-get upgrade -y && sudo reboot"
```

```
ssh adminuser@$HOSTNAME_PIP0 "modprobe 8021q && echo "8021q" | sudo tee -a /etc/modules"

ssh adminuser@$HOSTNAME_PIP0 "sudo apt-get install -y frr frr-doc && sudo systemctl stop frr"
```
```
ssh adminuser@$HOSTNAME_PIP0 "sudo ip link add link bond0 name bond0.$METAL_MGMT_A_VLAN type vlan id $METAL_MGMT_A_VLAN && sudo ip addr add $MGMT_A_IP.$METAL_INT/24 dev bond0.$METAL_MGMT_A_VLAN && sudo ip link set dev bond0.$METAL_MGMT_A_VLAN up"

ssh adminuser@$HOSTNAME_PIP0 "sudo ip link add link bond0 name bond0.$METAL_INTER_A_VLAN type vlan id $METAL_INTER_A_VLAN && sudo ip addr add $INTER_A_IP.$METAL_INT/24 dev bond0.$METAL_INTER_A_VLAN && sudo ip link set dev bond0.$METAL_INTER_A_VLAN up"

ssh adminuser@$HOSTNAME_PIP0 "sudo ip link set bond0 mtu 9000 && sudo ufw allow in on bond0.$METAL_MGMT_A_VLAN && sudo ufw allow in on bond0.$METAL_INTER_A_VLAN && sudo ufw allow from $INTER_A_IP.0/24"

ssh adminuser@$HOSTNAME_PIP0 "sudo ip addr add $SIDE_Z_NETWORK dev lo:0"
```
### Template confs
```
echo "
bgpd=yes
zebra=yes
ospfd=no
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
bfdd=no
fabricd=no
vrrpd=no
pathd=no
vtysh_enable=yes
zebra_options="  -A 127.0.0.1 -s 90000000"
bgpd_options="   -A 127.0.0.1"
staticd_options="-A 127.0.0.1"
bfdd_options="   -A 127.0.0.1"
pathd_options="  -A 127.0.0.1"
" | ssh adminuser@$HOSTNAME_PIP0 "sudo tee /etc/frr/daemons"
```

```
echo "
log syslog debug
frr defaults traditional
service integrated-vtysh-config
debug bgp neighbor-events
debug bgp updates
debug bgp zebra
debug bgp updates in
debug bgp updates out
!
ip router-id $MGMT_A_IP.$METAL_INT
!
router bgp 65001
 bgp log-neighbor-changes
 bgp router-id $MGMT_A_IP.$METAL_INT
 no bgp network import-check
 no bgp ebgp-requires-policy
 neighbor MRouters peer-group
 neighbor MRouters remote-as 65202
 neighbor MRouters ebgp-multihop 5
 neighbor MRouters password Equinixmetal05
 neighbor $(echo $INTER_A_VIP | awk -F '/' '{print$1}') peer-group MRouters
 neighbor $(echo $INTER_A_VIP | awk -F '/' '{print$1}') remote-as 65202
 !
 address-family ipv4 unicast
  redistribute connected
  neighbor $(echo $INTER_A_VIP | awk -F '/' '{print$1}') activate
  no neighbor MRouters send-community
  neighbor MRouters route-map ALLOW-ALL in
  neighbor MRouters route-map Z_SIDE_ALLOW_MAP out
  no neighbor $(echo $INTER_A_VIP | awk -F '/' '{print$1}') send-community
 exit-address-family
 !
!
ip prefix-list Z_SIDE_ALLOW_LIST seq 5 permit $SIDE_Z_NETWORK
!
route-map ALLOW-ALL permit 100
!
route-map Z_SIDE_ALLOW_MAP permit 100
    match ip address prefix-list Z_SIDE_ALLOW_LIST
!
line vty
!
end
" | ssh adminuser@$HOSTNAME_PIP0 "sudo tee /etc/frr/frr.conf"
```

```
ssh adminuser@$HOSTNAME_PIP0 "sudo systemctl start frr"
```




#### Troubleshooting

- Firewalls correct?
    - Router to observer on `179/tcp` should succeed
    - Observer to router on `179/tcp` like will not work because of VMAC / macvlan stuff on keepalived VIP

- Double, tripple check your addressing in your `ENV` builds. Are the right IPs getting rendered to the right spots of each file?

- Double tripple check your network specification
