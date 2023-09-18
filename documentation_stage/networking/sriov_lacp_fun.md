This example tears down a Metal instance's networking, adds SR-IOV VFs, uses one VF for LACP, and another VF for the same hosts networking but on a different bonded interface, here in active-backup.

The intent of this being that the LACP talker of a Metal instance can be moved from the host itself, into a VM / VNF, without loosing host level networking / access to Metal Layer-3. 

Note that current testing via this method discovered difficulty with `balance-alb` / `tlb` though that still needs to be poked with.

While `active-backup` looses the throughput benifit of LACP during normal scenarios, it maintains it's survival characteristics. Mode 0/2 may also work. 

```
echo 4 > /sys/class/net/enp65s0f0/device/sriov_numvfs
echo 4 > /sys/class/net/enp65s0f1/device/sriov_numvfs

systemctl stop NetworkManager
ip link del bond0 && \
ip link set nomaster enp65s0f0 && \
ip link set nomaster enp65s0f1 && \
ip link set enp65s0f0 down && \
ip link set enp65s0f1 down

ip link add vfbond1 type bond
ip link set vfbond1 type bond miimon 100 mode 802.3ad
ip link set ens3f0v3 down
ip link set ens3f0v3 master vfbond1
ip link set vfbond1 up
ip addr add 139.178.90.119/31 dev vfbond1
ip route add default via 139.178.90.118
ip link set enp65s0f0 up
ping 139.178.90.118

ip link set ens3f0v1 nomaster
ip link set ens3f0v1 down
ip link add pbond2 type bond
ip link set pbond2 type bond miimon 100 mode active-backup
ip link set ens3f0v1 master pbond2
ip link set pbond2 up
ip addr add 10.67.63.5/31 dev pbond2
ip route add 10.0.0.0/8 via 10.67.63.4

ip link add link pbond2 name pbond2.3880 type vlan id 3880
ip addr add 172.16.100.100/24 dev pbond2.3880
ip link set pbond2.3880 up

# now add the other interface, this ordering of first to second interface is for human sanity only
ip link set ens3f1v3 down
ip link set ens3f1v3 master vfbond1
ip link set enp65s0f1 up

ip link set ens3f1v3 down
ip link set ens3f1v3 master vfbond1
ip link set enp65s0f1 up

ip link set ens3f1v1 down
ip link set ens3f1v1 master pbond2
```