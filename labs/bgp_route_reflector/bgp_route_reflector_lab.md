# Route reflector lab

This spins up 3x instances, 2x as BGP routers that peer against 1x BGP *"reflector"*.

## Requirements

This guide assumes a modern `bash` shell with [metal-cli](https://deploy.equinix.com/developers/docs/metal/libraries/cli/), and `jq` installed. It assumes ssh with [Metal SSHK-eys](https://deploy.equinix.com/developers/docs/metal/accounts/ssh-keys/)

A checkout of this repo, where that step is included below.

- Networks taken from [GTST Network Schema](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/em_sa_network_schema.md)

## Route Reflector

```
git clone https://github.com/dlotterman/metal_code_snippets.git
cd metal_code_snippets/
```

```
INSTANCE_INT=239
INSTANCE_HOSTNAME=rr-$METAL_METRO-$METAL_INT
METAL_METRO=SV
METAL_PROJ_ID=
PEER_1=111
PEER_2=222
source shell/gtst.env
source shell/labs/txlab.env
source shell/labs/txlab.sh
```


```
metal device create --hostname $INSTANCE_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system ubuntu_22_04 --project-id $METAL_PROJ_ID -t "metalcli,rr,txlab" --userdata-file boiler_plate_cloud_inits/ubuntu_22_04_v1.mime
```

```
metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $GTST_INTR_A_VLAN
```


```
INSTANCE_ID=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg INSTANCE_HOSTNAME "$INSTANCE_HOSTNAME" -r '.[] | select(.hostname==$INSTANCE_HOSTNAME) | .id')

INSTANCE_BOND0=$(metal -p $METAL_PROJ_ID device list -o json | jq  --arg INSTANCE_HOSTNAME "$INSTANCE_HOSTNAME" -r '.[] | select(.hostname==$INSTANCE_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id')

INSTANCE_PIP0=$(metal device get -i $INSTANCE_ID -o json | jq -r '.ip_addresses[] | select((.public==true) and .address_family==4) | .address')
```


```
metal port vlan -i $INSTANCE_BOND0 -a $GTST_INTR_A_VLAN
```

```
ssh adminuser@$INSTANCE_PIP0 "sudo apt-get update && sudo apt-get upgrade -y && sudo reboot"
```

```
ssh adminuser@$INSTANCE_PIP0 "sudo apt-get install frr frr-doc -y && sudo systemctl stop frr"
ssh adminuser@$INSTANCE_PIP0 "echo "bonding" | sudo tee /etc/modules"
ssh adminuser@$INSTANCE_PIP0 "modprobe 8021q && echo "8021q" | sudo tee -a /etc/modules"
```

```
ssh adminuser@$INSTANCE_PIP0 "sudo ip link add link bond0 name bond0.$GTST_INTR_A_VLAN type vlan id $GTST_INTR_A_VLAN && sudo ip addr add $INSTANCE_IP_GTST_INTR_A dev bond0.$GTST_INTR_A_VLAN && sudo ip link set dev bond0.$GTST_INTR_A_VLAN up"

ssh adminuser@$INSTANCE_PIP0 "sudo ip link set bond0 mtu 9000 && sudo ufw allow in on bond0.$GTST_INTR_A_VLAN && sudo ufw allow from $GTST_INTR_A_NET"
```


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
" | ssh adminuser@$INSTANCE_PIP0 "sudo tee /etc/frr/daemons"
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
ip router-id $INSTANCE_IP_GTST_INTR_A
!
router bgp $TX_AS
 bgp router-id $INSTANCE_IP_GTST_INTR_A
 bgp log-neighbor-changes
 bgp cluster-id $INSTANCE_IP_GTST_INTR_A
 coalesce-time 1000

 neighbor txlab_neighbors peer-group

 neighbor $PEER_1_IP remote-as 65"$PEER_1"
 neighbor $PEER_1_IP password  Equinixmetal0%
 neighbor $PEER_2_IP remote-as 65"$PEER_2"
 neighbor $PEER_2_IP password  Equinixmetal0%
 !
 address-family ipv4 unicast
  redistribute connected
  neighbor $PEER_1_IP activate
  neighbor $PEER_1_IP route-reflector-client
  neighbor $PEER_2_IP activate
  neighbor $PEER_2_IP route-reflector-client
 exit-address-family
 !
!
line vty
!
end

" | ssh adminuser@$INSTANCE_PIP0 "sudo tee /etc/frr/frr.conf"
```

```
ssh adminuser@$INSTANCE_PIP0 "sudo systemctl start frr"
```


## Client a/b

```
INSTANCE_INT=111
INSTANCE_HOSTNAME=a_client-$METAL_METRO-$METAL_INT
METAL_METRO=SV
METAL_PROJ_ID=
PEER_1=239
PEER_2=222
source shell/gtst.env
source shell/labs/txlab.env
source shell/labs/txlab.sh
```
```
INSTANCE_INT=222
INSTANCE_HOSTNAME=b_client-$METAL_METRO-$METAL_INT
METAL_METRO=SV
METAL_PROJ_ID=
PEER_1=239
PEER_2=222
source shell/gtst.env
source shell/labs/txlab.env
source shell/labs/txlab.sh
```

```
metal device create --hostname $INSTANCE_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system ubuntu_22_04 --project-id $METAL_PROJ_ID -t "metalcli,rr,txlab" --userdata-file boiler_plate_cloud_inits/ubuntu_22_04_v1.mime
```

```
metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $GTST_INTR_A_VLAN
```


```
INSTANCE_ID=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg INSTANCE_HOSTNAME "$INSTANCE_HOSTNAME" -r '.[] | select(.hostname==$INSTANCE_HOSTNAME) | .id')

INSTANCE_BOND0=$(metal -p $METAL_PROJ_ID device list -o json | jq  --arg INSTANCE_HOSTNAME "$INSTANCE_HOSTNAME" -r '.[] | select(.hostname==$INSTANCE_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id')

INSTANCE_PIP0=$(metal device get -i $INSTANCE_ID -o json | jq -r '.ip_addresses[] | select((.public==true) and .address_family==4) | .address')
```

```
metal port vlan -i $INSTANCE_BOND0 -a $GTST_INTR_A_VLAN
```

```
ssh adminuser@$INSTANCE_PIP0 "sudo apt-get update && sudo apt-get upgrade -y && sudo reboot"
```

```
ssh adminuser@$INSTANCE_PIP0 "sudo apt-get install frr frr-doc -y && sudo systemctl stop frr"
ssh adminuser@$INSTANCE_PIP0 "echo "bonding" | sudo tee /etc/modules"
ssh adminuser@$INSTANCE_PIP0 "modprobe 8021q && echo "8021q" | sudo tee -a /etc/modules"
```

```
ssh adminuser@$INSTANCE_PIP0 "sudo ip link add link bond0 name bond0.$GTST_INTR_A_VLAN type vlan id $GTST_INTR_A_VLAN && sudo ip addr add "$INSTANCE_IP_GTST_INTR_A""$GTST_INTR_A_NET_CIDR" dev bond0.$GTST_INTR_A_VLAN && sudo ip link set dev bond0.$GTST_INTR_A_VLAN up"

ssh adminuser@$INSTANCE_PIP0 "sudo ip link set bond0 mtu 9000 && sudo ufw allow in on bond0.$GTST_INTR_A_VLAN && sudo ufw allow from $GTST_INTR_A_NET"

ssh adminuser@$INSTANCE_PIP0 "sudo ip addr add $A_SIDE_NETWORK dev lo:0"
```

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
" | ssh adminuser@$INSTANCE_PIP0 "sudo tee /etc/frr/daemons"
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
ip router-id $INSTANCE_IP_GTST_INTR_A
!
router bgp $TX_AS
 bgp router-id $INSTANCE_IP_GTST_INTR_A
 bgp log-neighbor-changes

 neighbor $RR_IP remote-as 65"$RR_INT"
 neighbor $RR_IP password  Equinixmetal0%

 !
 address-family ipv4 unicast
  redistribute connected
  neighbor $RR_IP activate
  neighbor $RR_IP route-map ALLOW-ALL in
  neighbor $RR_IP route-map A_SIDE_ALLOW_MAP out

 exit-address-family
 !
!
ip prefix-list A_SIDE_ALLOW_LIST seq 5 permit $A_SIDE_NETWORK
!
route-map ALLOW-ALL permit 100
!
route-map A_SIDE_ALLOW_MAP permit 100
    match ip address prefix-list A_SIDE_ALLOW_LIST
!
line vty
!
end

" | ssh adminuser@$INSTANCE_PIP0 "sudo tee /etc/frr/frr.conf"
```

```
ssh adminuser@$INSTANCE_PIP0 "sudo systemctl start frr"
```
