echo 8021q > /etc/modules-load.d/8021q.conf

nmcli connection add type vlan con-name bond0.64 ifname bond0.64 vlan.parent bond0 vlan.id 64

nmcli connection modify bond0.64 ipv4.addresses '192.168.100.11/24'
nmcli connection modify bond0.64 ipv4.gateway '192.168.100.1'
nmcli connection modify bond0.64 ipv4.method manual
nmcli con up bond0.64
