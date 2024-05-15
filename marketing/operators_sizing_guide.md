# An Operator's guide to sizing Equinix Metal instances

Sizing a workload for Equinix Metal is generally a simple endeavor, given the primitives (CPU, RAM, Disk) involved. This document is supposed to be an informal potholes and practices review of the exercise of sizing a workload for Equinix Metal.

Table of Contents:
- Disk
	- [RTO / RPO](https://github.com/dlotterman/metal_code_snippets/blob/main/marketing/operators_sizing_guide.md#key-rto--rpo-considerations)
	- [Storage Appliance Minimums](https://github.com/dlotterman/metal_code_snippets/blob/main/marketing/operators_sizing_guide.md#minimum-sizes-for-storage-appliances)
	- [Disk Performance](https://github.com/dlotterman/metal_code_snippets/blob/main/marketing/operators_sizing_guide.md#disk-performance)
- CPU
	- [Core vs vCPU vs Thread](https://github.com/dlotterman/metal_code_snippets/blob/main/marketing/operators_sizing_guide.md#disk-performance)
    - [Single vs Dual Socket (Licensing)](https://github.com/dlotterman/metal_code_snippets/blob/main/marketing/operators_sizing_guide.md#single-vs-dual-socket-licensing)
- [RVTools](https://github.com/dlotterman/metal_code_snippets/blob/main/marketing/operators_sizing_guide.md#rvtools)
- [VMWare is VCF only!](https://github.com/dlotterman/metal_code_snippets/blob/main/marketing/operators_sizing_guide.md#rvtools)
- [Specific Hardware / HCL](https://github.com/dlotterman/metal_code_snippets/blob/main/marketing/operators_sizing_guide.md#specifying-hardware-and-hcls)

## Equinix Metal instances are Dedicated Server Chassis, not virtualized instances

It is worth repeating: Equinix Metal instances are single tenant, Dedicated Servers (chassis) that are orchestrated in a way to behave similarly to **cloudy** instances, but they are **NOT** Virtual Machines. They are just Bare Metal Servers (chassis), the kind you have seen in data center racks for decades.

# Instance Sizing

## Disk

Often, the easiest place to start is at the end. Do you need to recover from a failure in 5 minutes or 5 hours? Can you loose 20 minutes of data or is no data loss tolerable?

### Key RTO / RPO considerations

- Equinix Metal provides no backup as a Service. Backups must be configured and operated by the customer or their delegated management partner
	- This is because Equinix Metal deliberately inserts no management vector into the customer's side of the environment. We want customers to trust the demarcation border between their of the dedicated environment and ares is strong and persisted.
- The disks inside an instance are local, they are not network attached or automagicked.
	- They must also be monitored by the customer, where for reserved instances, coordination of replacements in conjunction with support is available.
		- On-demand customers should rely on being able to provision capacity to accomadate failure.
- Equinix Metal provides few, if any, instances with a hardware RAID controller.
	- In accordance with Cloud Best Practices and Principles, data parity and protection are best considered an solution level design challenge, leveraging either Software Defined Storage (Ceph, vSAN, Nutanix), software RAID ([CPR](https://deploy.equinix.com/developers/docs/metal/storage/custom-partitioning-raid/), [LVM](https://github.com/dlotterman/metal_code_snippets/blob/main/documentation_stage/s3_tiered_storage.md)), or storage appliances ([Pure](https://deploy.equinix.com/solutions/equinix-operated/pure-storage/), [Netapp](https://deploy.equinix.com/solutions/equinix-operated/netapp-storage/) and [Dell](https://deploy.equinix.com/developers/docs/metal/storage/dell-powerstore/)).
		- Equinix Metal suggests considering an entire chassis as the primary fault domain of concern, not individual disks
- Equinix Metal's native internet connectivity and also access to Fabric unlock unique data transmission schemes
   - An Equinix Metal instance with 2x 25Gbps NICs can in fact do ~22Gbps backup / restores to Wasabi
   - Equinix Fabric provides fixed rate (no consumption aware) private connectivity options, allowing performant connectivity to both storage partners, but also storage that may already exist within a customers colocation or on-prem footprint
- Equinix Metal provides no guarantee about availability of on-demand instances, if capacity is 100% required (say for recovery bootstrap), that capacity must be reserved, presumably ahead of time
	- Equinix Metal is uniquely transparent about it's inventory and stocking levels, providing both [dashboards](https://deploy.equinix.com/developers/capacity-dashboard/) and [APIs](https://deploy.equinix.com/developers/api/metal#tag/Capacity/operation/findOrganizationCapacityPerFacility) for capacity transperancy.

### Software Defined Storage

Software Defined Storage generally speaking is used to cover technologies like Ceph, vSAN or Nutanix HCI that distribute and manage application from as an application down, consuming hard drives as raw primitives and layering performance and availability features.

SDS is generally well aligned with Equinix Metal, particularly [Ceph (Rook for Kubernetes)](https://deploy.equinix.com/developers/guides/choosing-a-csi-for-kubernetes/) or [MiNIO](https://deploy.equinix.com/developers/guides/minio-terraform/), which can consume the leverage internal to the chassis. It is up to the end operator to configure, monitor and operate their SDS implementation.

[Harvester](https://deploy.equinix.com/solutions/customer-operated/suse-harvester/) deserves a special callout for it's ability to consume Metal at it's most native and transform it into immediately consumeable [HCI](https://harvesterhci.io/).

The math behind most SDS will be more or less the same, erasure coding is erasure coding. This [vSAN oriented tool](https://kauteetech.github.io/vsancapacity/allflash) can be helpful for napkin math

#### vSAN

See VMWare section below.

### Storage Appliances

#### Deduplication Apples to Oranges

When evaluating current consumption vs offered storage solutions, be sure to understand which numbers may include magic features like Deduplication. For example, the local storage that is represented as instance storage, is a **"raw"** or un-deduped number, where as a number from a storage vendor **may** include Deduplication as part of their calculation.

#### Appliance Minimum Sizes

The storage appliances from partners that can be delivered into Equinix Metal generally start with a vendor specific minimum implementation size. Because there can be so much upfront cost in a dedicated hardware model, those minimums often just define financial minimums where each party in the deal benefits.

Generally speaking, the smallest minimum is 25TB or more likely 50TB, where below that, a solution design should leverage either:

1. Local disk to the instance chassis
	- Leverage SDS (Ceph, Nutanix etc)
2. Leverage external storage solutions
	- Wasabi, Elephantsql, Aiven etc
3. Interconnect storage in
	- Either via Dedicated Port of Fabric Virtual Connection, it can often be performant, cost effective and easy to bring in outside storage to Equinix Metal

### Disk Performance

- Equinix Metal prioritizes NVMe for it's performant tier of storage. The NVMe sourced by Equinix Metal is always best of breed, and for configurations like the [m3.large.x86](https://deploy.equinix.com/product/servers/m3-large/), can be assumed as 100k IOP+ capable drives each.
- The 8TB drives in the s3.xlarge.x86 are `7200RPM` HBA attached SAS/SATA drives

## CPU
### vCPU vs Core vs Thread

When Equinix Metal states the "Core count" of an instance, so for example when the marketing details page for the [m3.large.x86](https://deploy.equinix.com/product/servers/m3-large/) says "32 Cores", Metal means:

- This is a single socket instance
- That socket has a AMD 7502P (or better) CPU in it
- That CPU has 32 physical cores on it
- Those physical cores will likely be enabled for [SMT](https://en.wikipedia.org/wiki/Simultaneous_multithreading) (config / architecture support)
	- This means an m3.large.x86 will likely see 64 "threads of CPU" available to its host operating system

This can be tricky when trying to compare "Apples to Apples" with other adjacent kinds of automated hosting. What Equinix Metal presents, by the nature of being Bare Metal, is a full and real CPU, where many other vendors may present merely a "thread" as a "vCPU", or may even run multiple tenants on a single thread of a single core.

### Single vs Dual Socket (Licensing)

Equinix Metal has a natural alignment with modern, single socket design, and features predominantly single socket designs, with the [a3.large.x86](https://deploy.equinix.com/product/servers/a3-large/) and [s3.xlarge.x86](https://deploy.equinix.com/product/servers/s3-xlarge/) as noteable exemptions.

This is important to take into consideration with licensing costs, where Equinix Metal is predominantly a customer BYOL ecosystem.

## Network

It is assumed that customers can and will consume the full availalble throughput of any instance a customer provisions. If a customer provisions an m3.large with 2x 25Gbps NICs, the customer will be able to do 50Gbps of throughput through that instance for it's entire lifecycle.

Equinix Metal has a **STRONG** affinity for [LACP between an instance and it's Top of Rack switches](https://deploy.equinix.com/developers/docs/metal/networking/server-level-networking/#your-servers-lacp-bonding), and also has [significant limitations](https://deploy.equinix.com/developers/docs/metal/layer2-networking/layer2-unbonded-mode/) on how it can deliver networks if that bond is broken.

Multiple networks can be delivered to a single bond or interface of an Equinix instance via [VLANs](https://deploy.equinix.com/developers/docs/metal/layer2-networking/vlans/) and other [widgets](https://deploy.equinix.com/developers/docs/metal/bgp/bgp-on-equinix-metal/).

Most Equinix Metal instances are by default 2x port instances, with the n3.large and a3.large being the exceptions with 4x ports.

SR-IOV and DPDK dependant workloads are absolutely viable, but may align with a preference for the 4x port instance configuration, which allows an instance to preserve an LACP bond for control plane on the first two ports, but allowing individual, SR-IOV/DKPK addressable allocation to the remaining 2x interfaces.

### Port Speed

While an Equuinix Metal instance with 4x 25Gbps NICs as expected and allowed to do its full throughput facing the network, it should still be noted that the common rules of networking apply, no invidual data stream will be able to scale past the port speed of the instance.

That is to say, an `n3.xlarge.x86` can do 4x streams of 25Gbps, or 8x streams of 12.5Gbps, but it cannot do a single stream of 100Gbps.
# RVTools

When using an [RVTools](https://www.rvtools.net/about.html) export as a starting place for a sizing exercise, the below is how it would likely be broken down by a Equinix DTS Solutions Architect.

**Note** generally speaking, Metal SA's will try to match a vCPU to an actual, logical Core (Socket -> Core -> Thread) per instance, that is to say, oversubscription will generally be avoided, unless heavy oversubscription is noticed in the environment, in which case an ratio may be assumed and communicated.

- The guest vCPU, RAM and Total Disk columns in each sheet will be summed at the bottom of the column
- Starting with storage:
	- If customer has stated SDS (non vSAN) preference:
		- All Metal NVMe is currently based on a 3.8TB size, so divide number of aggregate GB of storage by 3800 for number of NVMe drives needed to meet raw capacity, then double for a sane parity starting place.
		- If you can tier off to the s3.xlarge.x86, that will decrease cost for storage dense footprints.
	- If customer states prefence for SAN, job done.
- The SA divide the summed RAM by summed vCPU to get the ratio of vCPU to RAM and find alignment with instance catalog:
	- For example, the c3.medium is a 2.6:1 GB or RAM to Core config
	- The m3.large is a an 8:1 ratio
	- The n3.large is 16:1
	- The a3.large is also 16:1
- Having a shortlist based on CPU ratio, the SA will then likely divide both:
	- Aggregate RAM by RAM of shortlisted instance
	- Aggregate CPU by RAM of shortisted instance
	- Use whichever of the two is higher (as a minimum), and add 1x or more to the quantity to ensure capacity for minimal host failure
	- A first choice option from the shortlist will likely be chosen. If not, a shortlist of options may also be chosen
- Double check customer processor preference (Intel vs AMD)
	- If best from shortlist is different from stated customer preference, show both options with closest other vendor based match.
- Double check the size of the larger VMs in the RVtools report to ensure we are covering off the smallest host sizing possible to host a whole VM
	- For example, we don't want to propose `128GB` instances if they have VMs that are `384GB` big.

# VMWare

As of `04/2024`, there is only one supported way to run VMWare at Equinix Metal, and that is [via VCF](https://deploy.equinix.com/solutions/customer-operated/vmware-cloud-foundation-vcf-on-equinix-metal/). Any previous documentation referencing any other path is wrong and out of date.

There is currently one SKU that is supported and approved for use with VCF, and that is the [n3-xlarge-opt-m4s2](https://deploy.equinix.com/product/servers/n3-xlarge-opt-m4s2/).

You must account for the [management domain](https://docs.vmware.com/en/VMware-Cloud-Foundation/4.5/vcf-getting-started/GUID-C68FD810-D270-43F2-AEBF-D522BA1F402B.html) in VCF. If it is not run on Metal than it must be run somewhere.

# Nutanix
As of `04/2024`, the [m3.large.x86](https://deploy.equinix.com/product/servers/m3-large/) and it's [WO Variants](https://deploy.equinix.com/developers/docs/metal/hardware/workload-optimized-plans/#m3large-variants) are the best starting places for Nutanix workloads.

It's possible other configurations such as the [WO a3.xlarge.x86](https://deploy.equinix.com/developers/docs/metal/hardware/workload-optimized-plans/#a3large-variants) variants may get certified as well.

# Specifying Hardware and HCLs

Equinix Metal, does not by default guarantee specific parts, models, or HCL validation for any of it's listed parts for on-demand instances. That is to say, an c3.medium will always have it's listed processor, but in some cases, may come with an Intel `ice` based NIC, and in others `bnx2`.

The only way to guarantee a specific model, version, or any fine grain detail of chassis configuration is by working with Equinix Metal Sales on a [reserved configuration](https://deploy.equinix.com/developers/docs/metal/deploy/reserved/).
