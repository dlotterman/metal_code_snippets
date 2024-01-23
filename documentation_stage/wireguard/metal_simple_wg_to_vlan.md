# Connecting two Metal sites together via Wireguard

Really just a stand-in for connecting Metal to other sites (non-Metal) via Internet.

We will be launching 1x instance in 2x metros. We will plumb inter-site or site-to-site Wireguard between those instances, and allow local LAN VLAN traffic to cross the Wireguard tunnel.

##  Requirements
This guide assumes a modern `bash` shell with [metal-cli](https://deploy.equinix.com/developers/docs/metal/libraries/cli/), and `jq` installed. It assumes ssh with [Metal SSHK-eys](https://deploy.equinix.com/developers/docs/metal/accounts/ssh-keys/)

Optional checkout of this repo for [cloud-init](https://github.com/dlotterman/metal_code_snippets/tree/main/boiler_plate_cloud_inits) an extra choice.

## Links
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_networking/assembly_setting-up-a-wireguard-vpn_configuring-and-managing-networking#proc_configuring-a-wireguard-server-by-using-the-wg-quick-service_assembly_setting-up-a-wireguard-vpn
- https://github.com/pirate/wireguard-docs/blob/master/example-lan-briding/montreal/wg0.conf


###  ENVs / Configuration

An easy guide for workflow, maintain two open terminal windows, each with one of the below stanzas of ENV configuration or representing the work of one instance.
Copy and paste commands below and enter them into the correct terminal.

In this case, `10.88.99.0/24` is the private local network in SV, `10.88.100.0/24` in DA, which are intended to live inside VLAN `3880`.


```
METAL_INT=44
METAL_PROJ_ID=###YOUR_PROJ
METAL_HOSTNAME=ncb-$METAL_INT
METAL_MGMT_A_VLAN=3880
METAL_METRO=sv
INSIDE_NETWORK= 10.88.99.0/24
```

```
METAL_INT=55
METAL_PROJ_ID=###YOUR_PROJ
METAL_HOSTNAME=ncb-$METAL_INT
METAL_MGMT_A_VLAN=3880
METAL_METRO=da
INSIDE_NETWORK=10.88.100.0/24
```

### Launch instances and VLAN

```
metal device create --hostname $METAL_HOSTNAME --plan c3.medium.x86 --metro $METAL_METRO --operating-system alma_9 --userdata-file ~/code/github/metal_code_snippets/virtual_appliance_host/no_code_with_guardrails/cloud_inits/el9_no_code_safety_first_appliance_host.mime --project-id $METAL_PROJ_ID -t "metalcli,ncb,wireguard"
```

```
metal virtual-network create -p $METAL_PROJ_ID -m $METAL_METRO --vxlan $METAL_MGMT_A_VLAN
```

### Build meta-data
```
HOSTNAME_ID=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id')

HOSTNAME_BOND0=$(metal -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .network_ports[] | select(.name=="bond0") | .id')

HOSTNAME_PIP0=$(metal device get -i $HOSTNAME_ID -o json | jq -r '.ip_addresses[] | select((.public==true) and .address_family==4) | .address')
```

### Attach VLANs
```
metal port vlan -i $HOSTNAME_BOND0 -a $METAL_MGMT_A_VLAN
```

### Hostwork

```
ssh adminuser@$HOSTNAME_PIP0 "wg genkey | sudo tee /etc/wireguard/$(hostname).key"
```
```
ssh adminuser@$HOSTNAME_PIP0 "cat /etc/wireguard/$(hostname).key | wg pubkey | sudo tee /etc/wireguard/$(hostname).pub"
```
```
ssh adminuser@$HOSTNAME_PIP0 "firewall-cmd --permanent --add-port=51820/udp --zone=public &&
sudo firewall-cmd --reload"
```

### Not Copy / Pasteable:

Add a local network subnet to each instance, must be different on each side. Must add / replace the correct keys in the `wg0` files manually.


**1st instance:**
```
ssh adminuser@$HOSTNAME_PIP0 "sudo ip addr add 10.88.99.0/24 dev lo"
```
```
echo "
Address = 10.0.6.10/24
ListenPort = 51820
PrivateKey = YOURPRIVATEKEY
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = sysctl -w net.ipv6.conf.all.forwarding=1

[Peer]
PublicKey = YOURPUBLICKEY
AllowedIPs = 10.88.100.0/24, 10.0.6.21/32
PersistentKeepalive = 20
Endpoint = 147.28.187.209:51820
"| ssh adminuser@$HOSTNAME_PIP0 "sudo tee /etc/wireguard/wg0.conf
```

**2nd instance:**
```
ssh adminuser@$HOSTNAME_PIP0 "sudo ip addr add 10.88.100.0/24 dev lo"
```
```
echo "
[Interface]
Address = 10.0.6.21/24
ListenPort = 51820
PrivateKey = YOURPRIVATEKEY
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = sysctl -w net.ipv6.conf.all.forwarding=1

[Peer]
PublicKey = YOURPUBLICKEY
Endpoint = 145.40.67.89:51820
AllowedIPs = 10.88.99.0/24, 10.0.6.10/32
PersistentKeepalive = 20
"| ssh adminuser@$HOSTNAME_PIP0 "sudo tee /etc/wireguard/wg0.conf
```

###
Turnup
```
ssh adminuser@$HOSTNAME_PIP0 "sudo systemctl enable --now wg-quick@wg0`
```

### Ping
```
ping 10.88.100.1
PING 10.88.100.1 (10.88.100.1) 56(84) bytes of data.
64 bytes from 10.88.100.1: icmp_seq=1 ttl=64 time=42.6 ms
```
