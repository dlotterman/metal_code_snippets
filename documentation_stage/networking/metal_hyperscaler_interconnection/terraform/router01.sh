export INTERCONNECT_HOST_LOCAL_VLAN01=1001
ip link add link bond0 name bond0.$INTERCONNECT_HOST_LOCAL_VLAN01 type vlan id $INTERCONNECT_HOST_LOCAL_VLAN01 && \
ip addr add 172.16.80.10/24 dev bond0.$INTERCONNECT_HOST_LOCAL_VLAN01 && \
ip link set dev bond0.$INTERCONNECT_HOST_LOCAL_VLAN01 up && \
ip link set mtu 9000 bond0 && \
ufw allow from 172.16.80.0/24

curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add - && \
export FRRVER="frr-stable" && \
echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | sudo tee -a /etc/apt/sources.list.d/frr.list && \
sudo apt update && sudo apt install -y frr frr-pythontools

sudo sed -i "s/^bgpd=no/bgpd=yes/" /etc/frr/daemons && \
sudo sed -i "s/^bfdd=no/bfdd=yes/" /etc/frr/daemons && \
systemctl restart frr

export INTERCONNECT_TRAFFIC_LOCAL_VLAN01=1000
ip link add link bond0 name bond0.$INTERCONNECT_TRAFFIC_LOCAL_VLAN01 type vlan id $INTERCONNECT_TRAFFIC_LOCAL_VLAN01 && \
ip addr add 172.16.220.10/24 dev bond0.$INTERCONNECT_TRAFFIC_LOCAL_VLAN01 && \
ip addr add 172.16.220.1/24 dev bond0.$INTERCONNECT_TRAFFIC_LOCAL_VLAN01 && \
ip link set dev bond0.$INTERCONNECT_TRAFFIC_LOCAL_VLAN01 up && \
ufw allow from 172.16.220.0/24
