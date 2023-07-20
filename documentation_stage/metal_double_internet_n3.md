# Provising an n3 with "double" internet service

This guide walks through the provisioning of an [n3.xlarge.x86](https://deploy.equinix.com/product/servers/n3-xlarge/) and assocaited networking needed to plumb the second bond interface (`bond1`) with Internet access in a way that a single daemon can service requests out of both interfaces to achieve 100Gbps of throughput via the Public Internet.

**Assumptions**

This document assumes the operator has a working:
- [metalcli](https://deploy.equinix.com/developers/docs/metal/libraries/cli/)
- bash shell environment
- [jq](https://jqlang.github.io/jq/download/)
- [Metal SSH Keys setup](https://deploy.equinix.com/developers/docs/metal/accounts/ssh-keys/)

All operations could also be performend via the UI, simply break down the instructions as described in the `metal` commands into relevant UI actions.

## Prepare the working shell environment

These variables should be the only manual entry needed. The only mandatory field is `METAL_PROJ_ID`, the rest *SHOULD* be updated to your needs but can be left as is.

After this, you should be able to follow the guide simply copy pasting, everything will reference these environment variables.

**IMPORTANT**
If you loose your shell (ssh timeout), you will need to reset these variables every login, and you will need to rebuild the metadata gathering steps if your work is broken midstream.

- Create the necessary shell env variable
```
METAL_PROJ_ID="YOURUUIDHERE" \
METAL_HOSTNAME="fe04" \
METAL_VLAN=231 \
METAL_METRO="sv"
```

## Provision the n3 and networking

- Provision the n3
```
metal device create --hostname $METAL_HOSTNAME --plan n3.xlarge.x86 --metro $METAL_METRO --operating-system ubuntu_22_04 --project-id $METAL_PROJ_ID -t "metalcli,$METAL_HOSTNAME"
```

- Provision the ElasticIP block, minimum of a /28
```
metal ip request --project-id $METAL_PROJ_ID -m $METAL_METRO --tags $METAL_HOSTNAME -q 8 -t public_ipv4
```

- Provision the VLAN for the Metal Gateway
```
metal virtual-network create --project-id $METAL_PROJ_ID -m $METAL_METRO --vxlan $METAL_VLAN
```

### Retrieve needed platform metadata

- Get the UUID of the Elastic IP block from the platform
```
EIP_ID=$(metal ip get -p $METAL_PROJ_ID -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.tags[]? | contains($METAL_HOSTNAME)) | .id')
```

- Get the UUID of the VLAN from the platform
```
VLAN_ID=$(metal virtual-network get -o json | jq --argjson METAL_VLAN "$METAL_VLAN" -r '.virtual_networks[] | select (.vxlan==$METAL_VLAN) | .id')
```

### Provision the Gateway

- Using the VLAN and ElasticIP UUID information we gather
```
metal gateway create -p $METAL_PROJ_ID --ip-reservation-id $EIP_ID --virtual-network $VLAN_ID
```

## Retrive more needed platform metadata
- Since we need metadata about provisioned things, collect it
```
HOSTNAME_ID=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .id') && \
HOSTNAME_BOND1=$(metal -p $METAL_PROJ_ID device list -o json | jq  --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .network_ports[] | select(.name=="bond1") | .id')
```
- Moar
```
HOSTNAME_IP=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .ip_addresses[] | select ((.address_family==4) and .public==true) | .address') &&  \
HOSTNAME_GATEWAY=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .ip_addresses[] | select ((.address_family==4) and .public==true) | .gateway')
```
- Moar
```
HOSTNAME_PRIVATE_IP=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .ip_addresses[] | select ((.address_family==4) and .public==false) | .address') && \
HOSTNAME_PRIVATE_GATEWAY=$(metal -p $METAL_PROJ_ID device list -o json | jq --arg METAL_HOSTNAME "$METAL_HOSTNAME" -r '.[] | select(.hostname==$METAL_HOSTNAME) | .ip_addresses[] | select ((.address_family==4) and .public==false) | .gateway')
```

- Moar Moar
```
GATEWAY_ID=$(metal gateway get -p $METAL_PROJ_ID -o json | jq --arg METAL_VLAN "$METAL_VLAN" -r '.[] | select(any(.virtual_network[]|tostring; test($METAL_VLAN))) | .id') && \
GATEWAY_NETWORK=$(metal gateway get -p $METAL_PROJ_ID -o json | jq --arg METAL_VLAN "$METAL_VLAN" -r '.[] | select(any(.virtual_network[]|tostring; test($METAL_VLAN))) | .ip_reservation.network') && \
GATEWAY_IP=$(metal gateway get -p $METAL_PROJ_ID -o json | jq --arg METAL_VLAN "$METAL_VLAN" -r '.[] | select(any(.virtual_network[]|tostring; test($METAL_VLAN))) | .ip_reservation.gateway') && \
GATEWAY_CIDR=$(metal gateway get -p $METAL_PROJ_ID -o json | jq --arg METAL_VLAN "$METAL_VLAN" -r '.[] | select(any(.virtual_network[]|tostring; test($METAL_VLAN))) | .ip_reservation.cidr') && \
BOND1_IP=$(nmap -sL -n "$GATEWAY_NETWORK/$GATEWAY_CIDR" | sed -n 4p | awk '{print$NF}')
```


- It may take a few minutes for the n3 to provision, wait untill that instance status changes to `active`
```
watch -n 10 metal device get -i $HOSTNAME_ID
```

## Add Metal instance to VLAN

- by adding VLAN to instance's bond1
```
metal port vlan -i $HOSTNAME_BOND1 -a $METAL_VLAN
```


## SSH in the needed config

Note this requires the use of working Metal SSH keys. If your SSH setup is different, make necessary changes.

- Apt update
```
ssh root@$HOSTNAME_IP "apt-get -y update && apt-get -o Dpkg::Options::="--force-confold" --allow-change-held-packages  -y upgrade"
```

- Force kernel upgrade
```
ssh root@$HOSTNAME_IP "apt-get upgrade linux-headers-generic linux-headers-virtual linux-image-virtual linux-virtual -y -o Dpkg::Options::="--force-confold""
```

- Interfaces file:
```
ssh root@$HOSTNAME_IP "cat <<EOT > /etc/network/interfaces
auto lo
iface lo inet loopback

auto ens6f0
iface ens6f0 inet manual
    bond-master bond0

auto ens6f2
iface ens6f2 inet manual
    pre-up sleep 4
    bond-master bond0

auto bond0
iface bond0 inet static
    address $HOSTNAME_IP
    netmask 255.255.255.254
    gateway $HOSTNAME_GATEWAY
    bond-downdelay 200
    bond-miimon 100
    bond-mode 4
    bond-updelay 200
    bond-xmit_hash_policy layer3+4
    bond-lacp-rate 1
    bond-slaves ens6f0 ens6f2
    dns-nameservers 147.75.207.207 147.75.207.208

auto bond0:0
iface bond0:0 inet static
    address $HOSTNAME_PRIVATE_IP
    netmask 255.255.255.254
    post-up route add -net 10.0.0.0/8 gw $HOSTNAME_PRIVATE_GATEWAY
    post-down route del -net 10.0.0.0/8 gw $HOSTNAME_PRIVATE_GATEWAY

auto ens6f1
iface ens6f1 inet manual
    bond-master bond1

auto ens6f3
iface ens6f3 inet manual
    pre-up sleep 4
    bond-master bond1

auto bond1
iface bond1 inet static
    address $BOND1_IP/$GATEWAY_CIDR
    gateway $GATEWAY_IP
    bond-downdelay 200
    bond-miimon 100
    bond-mode 4
    bond-updelay 200
    bond-xmit_hash_policy layer2+3
    bond-lacp-rate 0
    bond-slaves ens6f1 ens6f3
EOT"
```

- Add split network script
```
ssh root@$HOSTNAME_IP "cat <<EOT > /usr/local/bin/split_route_script.sh
if grep -q -F "200 bond1_table" "/etc/iproute2/rt_tables"; then
    touch /tmp/touch_rt_table
else
    echo '200 bond1_table' >> /etc/iproute2/rt_tables
fi
ip rule add from $BOND1_IP table bond1_table priority 900
ip route add default via $GATEWAY_IP dev bond1 table bond1_table
ip route add $GATEWAY_NETWORK/$GATEWAY_CIDR dev bond1 proto static scope link src $BOND1_IP table bond1_table
EOT"
```

- Add split network systemd script
```
ssh root@$HOSTNAME_IP "cat <<EOT > /etc/systemd/system/split_route_script.service
[Unit]
Description=split_route_for_ocp
Wants=network-online.target
After=network.target network-online.target

[Service]
Type=simple
ExecStart=/bin/bash /usr/local/bin/split_route_script.sh

[Install]
WantedBy=multi-user.target
EOT"
```

- Reload systemd
```
ssh root@$HOSTNAME_IP "systemctl daemon-reload && systemctl enable --now split_route_script.service"
```

## Reboot the system

- It will come back in the correct config:
```
ssh root@$HOSTNAME_IP "reboot"
```

#### Optional Easy Enhancements

- Enable automatic updates for easy-ops security
```
ssh root@$HOSTNAME_IP "cat <<EOT > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
"${distro_id}:${distro_codename}";
"${distro_id}:${distro_codename}-updates";
"${distro_id}:${distro_codename}-security";
"${distro_id}ESMApps:${distro_codename}-apps-security";
"${distro_id}ESM:${distro_codename}-infra-security";
};
EOT"
```
```
ssh root@$HOSTNAME_IP "cat <<EOT > /etc/apt/apt.conf.d/21auto-upgrades_on
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOT"
```
```
ssh root@$HOSTNAME_IP "cat <<EOT >> /etc/crontab
05 * * * * root /usr/bin/unattended-upgrade -v
05 11 * * * root systemctl restart sshd
15 11 * * * root systemctl restart serial-getty@ttyS1.service
20 11 * * * root systemctl restart getty@tty1.service
EOT"
```

- Enable firewall (requires adding your own hole punches), allows 22 (ssh) with rate limit
```
ssh root@$HOSTNAME_IP "ufw default allow outgoing && ufw default deny incoming && ufw allow ssh && ufw allow from 10.0.0.1/8 && ufw limit ssh && ufw enable"
```

### Validation

How do I validate this?

You should be able to (first install) `iperf3` and then run it with the default `-s`. `iperf3` clients should be able to connect in on both the regular metal IP address, as well as the boxes ElasticIP, at the same time, pushing north of 60Gbps by default, 80-90Gbps with minor tuning. Parralelism is needed.

The ElasticIP of the box can be found with

```
ssh root@$HOSTNAME_IP "ip a show bond1"
```
