# Notes on the c3.small.x86 configuration

## SR-IOV on the c3.small.x86

* [SR-IOV Primer](https://s3.wasabisys.com/packetrepo/pci-sig-sr-iov-primer-sr-iov-technology-paper.pdf)

While the `c3.small.x86` is well purposed for a number of packet-pushing workloads, it has mildly-hidden limitations with SR-IOV configuration specific workloads.

The `c3.small.x86` is powered by a [Intel 2278G](https://ark.intel.com/content/www/us/en/ark/products/193745/intel-xeon-e-2278g-processor-16m-cache-3-40-ghz.html), socketed inside a either a [X11SCM-F](https://www.supermicro.com/en/products/motherboard/X11SCM-F) or [X11SCH-F](https://www.supermicro.com/en/products/motherboard/X11SCH-F) inside a SuperMicro chassis à la [SuperServer 5019C-MR](https://www.supermicro.com/products/system/1U/5019/SYS-5019C-MR.cfm). Finally it has a [Mellanox Connectx-4 LX](https://www.nvidia.com/en-us/networking/ethernet/connectx-4-lx/)

Both the `X11SCM-F` and `X11SHM-F` are based on an Intel C246 Chipset. When loaded into a host OS (Linux), tools such as `lspci` will indicate that the system has support capabilities things like `Alternative Routing-ID Interpretation (ARI)`, `Address Translation Services (ATS)` (Related to DMA), `Access Control Services (ACS)` etc. The system exposes the proper `sysfs` folder structures when `intel_iommu=on` and/or `iommu=pt` is added to `grub`.

However when certain non-trivial configuration tasks are attempted, for example adding an 7th `VF` to the first port, or adding a 1st `VF` to the second port, a system will return weird allocation errors in response to the call. Those errors may resemble:

```
echo 5 > /sys/class/net/enp1s0f0/device/sriov_numvfs
-bash: echo: write error: Numerical result out of range
```

```
# echo 3 > /sys/class/net/enp1s0f1/device/sriov_numvfs
-bash: echo: write error: Device or resource busy
```

```
localhost kernel: [ 1920.456335] pci 0000:01:01.2: [15b3:1016] type 7f class 0xffffff
```

```
localhost kernel: [ 1920.456489] pci 0000:01:01.2: unknown header type 7f, ignoring device
```


The cause of these errors comes from the underlying physical plumbing of the PCI lanes in the board of the chassis. It turns out that these underlying constraints place real limitations of the SR-IOV capability of the `c3.small.x86`.

From the manufacturer: *__"all the PCIe lanes on X11SCM, X11SCH are connected and supported by CPU, instead of C246 Chipset. Although the PCH supports SR-IOV, there are limitations of SR-IOV support thru CPU. Per Intel, “CPU PCIe does not officially support SR-IOV"."__*

The `PCI bridge: Intel Corporation Cannon Lake PCH PCI Express Root Port #17 (rev f0)` in the chassis makes the chassis look like a more SR-IOV capable box then it is. Because the PCI lanes the go directly into the CPU instead of the chipset root controller, non of the SR-IOV supporting capabilities are relevant. The ports / lanes that go directly into the CPU do not support PCIe ACS / ARI functionality.

This is why there is no `SR-IOV` `enabled / disabled`  toggle in the BIOS. In fact no code to enabled a toggle is provided by Intel for this CPU in this configuration. 

Similarly, this is why the "ACS disable" patches that are often spoken of have no impact with this limitation. Even though there is no ACS / ARI support due to the lanes going directly to the CPU, the simple IOMMU layout allows for simple SR-IOV creation, just not across PCIe boundaries that would normally require more advanced functionality. 

The most important limitation comes from the BIOS of the motherboard, which as a refresher on SR-IOV, the BIOS of the motherboard / CPU performs the following SR-IOV downstream dependant function. From the SR-IOV primer doc above:

```
The BIOS performs a role in partitioning Memory Mapped I/O and PCI Express Bus numbers 
between host bridges.
In many systems, mechanisms for allocating PCI resources to the host bridges are not 
standardized and software relies on the BIOS to configure these devices with sufficient 
memory space and bus ranges to support I/O devices in the hierarchy beneath each host 
bridge.
BIOS enumeration code needs to be enhanced to recognize SR-IOV devices so that enough 
MMIO (Memory Mapped IO) space is allocated to encompass the requirements of VFs. Refer 
to the PCI-SIG SR-IOV specification for details on how to parse PCI Config space and 
calculate the maximum amount of VF MMIO space required.
```

This is the imposing limitation of the `X11SCM-F` and `X11SHM-F` motherboards. They only allocate sufficient memory space for a very limited mapping of SR-IOV related enumerations. This is complicated by the fact that the configuration of the Mellanox card will influence the amount of memory consumed in that BIOS allocation. Some of that math can be [deduced from this bugrepot](https://www.mail-archive.com/search?l=kernel-packages@lists.launchpad.net&q=subject:%22%5C%5BKernel%5C-packages%5C%5D+%5C%5BBug+1821345%5C%5D+Re%5C%3A+Mellanox+MT27800+%5C%2F+mlx5_core+%5C%3A+cannot+bring+up+VFs+if+the+total+number+of+VFs+is+%3E%3D+64+%5C%3A+alloc+irq+vectors+failed%22&o=newest&f=1)

### Operational reality of SR-IOV on the c3.small

* The c3.small.x86 can only support ~7x `Virtual Functions` on it's Mellanox NICs
* In order to allocate a `VF` to the second port of the NIC, the number of `MSI`'s allocated per VF must be dropped
	* The reason why is that each enumeration of interuppt to `VF` consume space in our extremely limited enumeration allocation from the BIOS
* Example Mellanox configuration that allows for 3x SR-IOV `VF`'s per port:
	* `mlxconfig -d /dev/mst/mt4117_pciconf0 set SRIOV_EN=1 NUM_OF_VFS=4 NUM_VF_MSIX=4 NUM_PF_MSIX=15`
* The exact behavior will be heavily dependant on a combination of configuration factors. Exact mileage will vary. 


## Local hardware IPMI devices not exposed to host OS

Some `c3.small.x86` configurations are delivered via a unique hardware lifecycle package called [Open19](https://metal.equinix.com/blog/getting-servers-into-sydney/). Describing Open19 and its benifits are outside of the scope of this writeup 

The Open19 `c3.small.x86` is a different bundling of hardware parts from the "traditional" rack chassis `c3.small.x86`. That bundling means that with close inspection, there are differences between a deployed `c3.small.x86` depending on if it is a Open19 instance or a traditional rack chassis.

The Open19 instance does not expose it's local IPMI device as a traditional IPMI / BMC device through SMI/DMI to the host OS. In fact the Open19 instance doesnt expose any local IPMI device at all to the motherboard, the IPMI device only attached to the external Open19 "rack" infrastructure. 

In the BIOS menu of a rack chassis `c3.small.x86`, the IPMI section is clearly visible:

<p align="center">
  <img width="800" height="600" src="https://s3.wasabisys.com/packetrepo/http_assets/metal_c3small_ipmi_yes.png">
</p>

In the BIOS menu of an Open19 instance, no IPMI section is visible:

<p align="center">
  <img width="800" height="600" src="https://s3.wasabisys.com/packetrepo/http_assets/metal_c3small_ipmi_no.png">
</p>

When a rack chassis instance is booted into a vanilla linux environment, the IPMI device is visible and exposed to the host OS via the SMI/DMI interfaces as expected:
```
# dmidecode | grep -A7 "IPMI Device"
IPMI Device Information
        Interface Type: KCS (Keyboard Control Style)
        Specification Version: 2.0
        I2C Slave Address: 0x10
        NV Storage Device: Not Present
        Base Address: 0x0000000000000CA2 (I/O)
        Register Spacing: Successive Byte Boundaries
```

When a Open19 instance is booted into a vanilla linux environment, the IPMI device is not visible, as it is not exposed:
```
$ sudo dmidecode | grep -A7 "IPMI Device"
$
```

And when a package that depends on a `/dev/ipmi0` like device being instantiated, it will likely encounter the following error with anything that will look for that device:
```
# ipmitool
Could not open device at /dev/ipmi0 or /dev/ipmi/0 or /dev/ipmidev/0: No such file or directory
```

How to identify an Open19 instance:
```
# dmidecode | grep ASR
        Manufacturer: ASRockRack
```

## Local sensor data

Similar to the Open19 vs Rack Chassis IPMI device subject, the Open19 also does not expose some ACPI / SMI / lm-sensor data. This may cause some data gaps in software that looks for those sensors.

<p align="center">
  <img width="800" height="600" src="https://s3.wasabisys.com/packetrepo/http_assets/metal_c3small_ipmi_missing_sensor.png">
</p>