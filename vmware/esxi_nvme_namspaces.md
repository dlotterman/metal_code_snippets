# Splitting an NVMe disk into multiple namespaces with esxcli

This is intended to be used to get more drive layout options out of an Equinix Metal instance with NVMe, example use cases being vSAN.

- `esxcli nvme controller list`
```
[root@m3-large-x86-01:~] esxcli nvme controller list
Name                                                                                  Controller Number  Adapter  Transport Type  Is Online  Is VVOL
------------------------------------------------------------------------------------  -----------------  -------  --------------  ---------  -------
nqn.2014-08.org.nvmexpress_1344_Micron_9300_MTFDHAL3T8TDP_______________2145327D91DD                256  vmhba1   PCIe                 true    false
nqn.2014-08.org.nvmexpress_1344_Micron_9300_MTFDHAL3T8TDP_______________2145327D9246                257  vmhba0   PCIe                 true    false
```
        - In this case we are working off of `vmhba0`


- `esxcli nvme controller identify -c nqn.2014-08.org.nvmexpress_1344_Micron_9300_MTFDHAL3T8TDP_______________2145327D9246 | grep CNTLID`
```
[root@m3-large-x86-01:~] esxcli nvme controller identify -c nqn.2014-08.org.nvmexpress_1344_Micron_9300_MTFDHAL3T8TDP_______________2145327D9246 | grep CNTLID
CNTLID       0x1
```
    - So our controller ID is `1`
- `esxcli nvme device namespace detach --adapter vmhba0 -c 1 -n 1`
     - Detach the first / default namespace
- `esxcli nvme device namespace delete --adapter vmhba0 -n 1`
     - Delete that namespace
- `esxcli nvme device namespace create --adapter vmhba0 -c 1258291200 -p 0 -f 0 -m 0 -s 1258291200`
     - Create 600Gb namespace
- `esxcli nvme device namespace create --adapter vmhba0 -c 6243185328 -p 0 -f 0 -m 0 -s 6243185328`
     - Create 2.9TB namespace
- `esxcli nvme device namespace attach --adapter vmhba0 -c 1 -n 1`
     - Attach first namespace
- `esxcli nvme device namespace attach --adapter vmhba0 -c 1 -n 2`
     - Attach second namespace
