## Using LVM + dm-cache with the Equinix Metal s3.xlarge.x86 instance

This document is meant for supplementary use only. Anything in this subject matter is considered the jurisdiction of the end operator. This document is not supported by Equinix Metal.

The Equinix Metal [s3.xlarge.x86](https://metal.equinix.com/product/servers/s3-xlarge/) is a storage focused instance configuration that leverages three seperate tiers of storage, with the intent to provide a flexible platform for featureful and thoughtful storage deployments.

This guide will cover a high level approach to leveraging these disk tiers with Linux's native [Logical Volume Manager](https://en.wikipedia.org/wiki/Logical_Volume_Manager_(Linux)) and it's built in [dm-cache](https://en.wikipedia.org/wiki/Dm-cache) integration.

A couple of clarifications before beginning:

### dm-cache vs dm-writecache

In the early 2010's, there were (and still are) two different "fast disk to cache slow disk" projects, *dm-cache* and *dm-writecache*. 

* dm-cache is intended to be bi-directional (read / write) cache device not dissimilar in role from a RAID controllers cache functionality or a combination of ZFS's L2Arc / ZIL / SLOG functionality for Device Mapper devices
* dm-writecache is focused exclusively and specifically on providing a write cache in front of a Device Mapper device

The scope of choosing one path or the other falls outside of this document. Both have their purpose but for the purpose of this document it's worth being explicity, we will be levering the *dm-cache* functionality brought via LVM's `lvmcache` integration with that package.

### Documentation references

Redhat is a primary sponsor of the LVM ecosystem, and as such Redhat LVM / storage documentation should be considered the starting place and authoratative source for LVM / dm-cache related subjects
* [RHEL 7 Storage Administration Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/storage_administration_guide/)
* [RHEL 8 managing logical volumes](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_logical_volumes)
* [dm-cache presentation from RH](https://people.redhat.com/mskinner/rhug/q1.2016/dm-cache.pdf)
* [Linux Kernel dm-cache documentation](https://www.kernel.org/doc/Documentation/device-mapper/cache.txt)
* [LVM lvmcache documentation](https://www.systutorials.com/docs/linux/man/7-lvmcache/)
* [dm-cache blog](https://blog.delouw.ch/2020/01/29/using-lvm-cache-for-storage-tiering/)
* [ahammer blog - very useful](http://www.ahammer.ch/141)
* [cache policies](https://mjmwired.net/kernel/Documentation/device-mapper/cache-policies.txt)

### Tuning not discussed
Tuning of a tiered storage design is uniquely complex. This document will intetionally not cover it. Modern sane defaults mean tuning should not be necessary for most workloads.
* Underlying drive readahead is probably the only 80/20 ROI tuneable for most users

### Discard / TRIM
The use of Discard / TRIM with Linux storage devices and designs is also complex, in particular with LVM. This specific design, with minimal / no use of consumer SATA based SSDs, should be "plug and play" safe with Discard / TRIM

### (Lack of) High Availability
For simplicities sake, this document assumed **NO** redundancy of the cache drive. This means the cache drive / caching function **IS** implicitly a Single Point of Failure.

There are a number of ways to design availability into this tier, just the number of options fall beyond the scope of this doc. 

### Storage inside the *s3.xlarge.x86*
The three tiers of storage inside the*s3* are:
* SSD: 2x ~900GB drives intended for boot and boot parity
* NVMe: 2x ~220GB drives that should [resemble something like this or older](https://business.kioxia.com/en-ca/ssd/client-ssd/xg6.html)
* HDD: 12x 8TB 7.2k drives that should be [resemble some like this or older](https://www.storagereview.com/review/hgst-ultrastar-helium-he8-8tb-enterprise-hard-drive-review)

In our design, the SSD's will be left for boot / utility, 1x NVMe drive will be used as a read / write data cache, the other 1x NVMe drive will be used as the metadata storage drive, and the 12x 8TB will be placed into a LVM managed RAID10, fronted by the NVMe drives.

### Working with Device Mapper / LVM to build the DM structure

`/dev/sda` and `/dev/sdb` will almost certainly be the two SATA attached SSDs, they will be ignored

#### Create PVs

```
pvcreate /dev/sdk
pvcreate /dev/sdg
pvcreate /dev/sdn
pvcreate /dev/sde
pvcreate /dev/sdh
pvcreate /dev/sdf
pvcreate /dev/sdi
pvcreate /dev/sdj
pvcreate /dev/sdc
pvcreate /dev/sdm
pvcreate /dev/sdl
pvcreate /dev/sdd
pvcreate /dev/nvme0n1
pvcreate /dev/nvme1n1
```

Untrusted one-liner:

```
# for DRIVE in $(lsblk  | grep "7.3" | awk '{print$1}' ); do pvcreate /dev/$DRIVE ; done
  Physical volume "/dev/sda" successfully created.
  Physical volume "/dev/sdb" successfully created.
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.
  Physical volume "/dev/sde" successfully created.
  Physical volume "/dev/sdf" successfully created.
  Physical volume "/dev/sdg" successfully created.
  Physical volume "/dev/sdh" successfully created.
  Physical volume "/dev/sdi" successfully created.
  Physical volume "/dev/sdj" successfully created.
  Physical volume "/dev/sdk" successfully created.
  Physical volume "/dev/sdl" successfully created.
```

#### Create Volume Group of PV's

```
vgcreate vg_01 /dev/sdk /dev/sdg /dev/sdn /dev/sde /dev/sdh /dev/sdf /dev/sdi /dev/sdj /dev/sdc /dev/sdm /dev/sdl /dev/sdd /dev/nvme0n1 /dev/nvme1n1
```

#### Create LV's from PV

The first Logical Volume to create is the RAID10 Device Mapper of the HDDs. Note that to leverage each HDD, we need the number of stripes (`6`) multiplied  by the mirror (1 mirror for 2 drives) to equal the number of drives (`12`)
```
lvcreate --type raid10 -l 95%FREE -i 6 -m 1 -n lv_01 vg_01 /dev/sdk /dev/sdg /dev/sdn /dev/sde /dev/sdh /dev/sdf /dev/sdi /dev/sdj /dev/sdc /dev/sdm /dev/sdl /dev/sdd
```
```
lvcreate -l 90%FREE -n lv_01_cache vg_01 /dev/nvme0n1 /dev/nvme1n1
```
```
lvcreate -l 5%FREE -n lv_01_cache_meta vg_01 /dev/nvme0n1 /dev/nvme1n1
```

The second two LV's are Note that the `90%FREE` for the second NVMe drive is to maintain some free extents within the PV for Device Mapper overhead

#### Convert the RAID LV to a Cached LV

Note the use of *cachepool* / *cache-pool*, this implies *dm-cache* vs the *cachevol* which would imply *dm-writecache*.

Also note this is where the second NVMe drive is attached as a metadata target for the first NVMe disk, which is then attached to the RAID Logical Volume as a data cache.

```
lvconvert --type cache-pool --cachemode writeback --poolmetadata vg_01/lv_01_cache_meta vg_01/lv_01_cache
```

```
lvconvert --type cache --cachepool vg_01/lv_01_cache vg_01/lv_01
```

#### Confirm 
The `lvs -a -o +devices` command can be used to get a quick sense of a complete configuration:

```
# lvs -a -o +devices
  LV                        VG    Attr       LSize   Pool                Origin        Data%  Meta%  Move Log Cpy%Sync Convert Devices                                                                                                          
  lv_01                     vg_01 Cwi-a-C---  43.66t [lv_01_cache_cpool] [lv_01_corig] 0.01   16.07           0.00             lv_01_corig(0)                                                                                                   
  [lv_01_cache_cpool]       vg_01 Cwi---C--- 238.47g                                   0.01   16.07           0.00             lv_01_cache_cpool_cdata(0)                                                                                       
  [lv_01_cache_cpool_cdata] vg_01 Cwi-ao---- 238.47g                                                                           /dev/nvme0n1(0)                                                                                                  
  [lv_01_cache_cpool_cmeta] vg_01 ewi-ao----  48.00m                                                                           /dev/nvme1n1(54944)                                                                                              
  lv_01_cache_meta          vg_01 -wi------- 214.62g                                                                           /dev/nvme1n1(0)                                                                                                  
  [lv_01_corig]             vg_01 rwi-aoC---  43.66t                                                          0.02             lv_01_corig_rimage_0(0),lv_01_corig_rimage_1(0),lv_01_corig_rimage_2(0),lv_01_corig_rimage_3(0),lv_01_corig_rimage_4(0),lv_01_corig_rimage_5(0),lv_01_corig_rimage_6(0),lv_01_corig_rimage_7(0),lv_01_corig_rimage_8(0),lv_01_corig_rimage_9(0),lv_01_corig_rimage_10(0),lv_01_corig_rimage_11(0)
  [lv_01_corig_rimage_0]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdk(1)                                                                                                      
  [lv_01_corig_rimage_1]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdg(1)                                                                                                      
  [lv_01_corig_rimage_10]   vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdl(1)                                                                                                      
  [lv_01_corig_rimage_11]   vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdd(1)                                                                                                      
  [lv_01_corig_rimage_2]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdn(1)                                                                                                      
  [lv_01_corig_rimage_3]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sde(1)                                                                                                      
  [lv_01_corig_rimage_4]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdh(1)                                                                                                      
  [lv_01_corig_rimage_5]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdf(1)                                                                                                      
  [lv_01_corig_rimage_6]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdi(1)                                                                                                      
  [lv_01_corig_rimage_7]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdj(1)                                                                                                      
  [lv_01_corig_rimage_8]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdc(1)                                                                                                      
  [lv_01_corig_rimage_9]    vg_01 Iwi-aor---  <7.28t                                                                           /dev/sdm(1)                                                                                                      
  [lv_01_corig_rmeta_0]     vg_01 ewi-aor---   4.00m                                                                           /dev/sdk(0)                                                                                                      
  [lv_01_corig_rmeta_1]     vg_01 ewi-aor---   4.00m                                                                           /dev/sdg(0)                                                                                                      
  [lv_01_corig_rmeta_10]    vg_01 ewi-aor---   4.00m                                                                           /dev/sdl(0)                                                                                                      
  [lv_01_corig_rmeta_11]    vg_01 ewi-aor---   4.00m                                                                           /dev/sdd(0)                                                                                                      
  [lv_01_corig_rmeta_2]     vg_01 ewi-aor---   4.00m                                                                           /dev/sdn(0)                                                                                                      
  [lv_01_corig_rmeta_3]     vg_01 ewi-aor---   4.00m                                                                           /dev/sde(0)                                                                                                      
  [lv_01_corig_rmeta_4]     vg_01 ewi-aor---   4.00m                                                                           /dev/sdh(0)                                                                                                      
  [lv_01_corig_rmeta_5]     vg_01 ewi-aor---   4.00m                                                                           /dev/sdf(0)                                                                                                      
  [lv_01_corig_rmeta_6]     vg_01 ewi-aor---   4.00m                                                                           /dev/sdi(0)                                                                                                      
  [lv_01_corig_rmeta_7]     vg_01 ewi-aor---   4.00m                                                                           /dev/sdj(0)                                                                                                      
  [lv_01_corig_rmeta_8]     vg_01 ewi-aor---   4.00m                                                                           /dev/sdc(0)                                                                                                      
  [lv_01_corig_rmeta_9]     vg_01 ewi-aor---   4.00m                                                                           /dev/sdm(0)                                                                                                      
  [lvol0_pmspare]           vg_01 ewi-------  48.00m                                                                           /dev/nvme1n1(54956)    ```
```


#### Enable Writeback
"writeback" on a disk cache generally, and in this case, refers to the possible dangerous act of acknowledging a succesful write to a client when a write I/O lands on the cache device, but not necissarily the underlying non-volitile device (our RAID10), with the expectation it will reach the underlying device eventually. 

This can significantly enhance performance, but it is extremely important to understand the consequences to data availability.

```
lvchange --cachemode writeback vg_01/lv_01
```




#### Quick operational hints / cheats

Watching the different caches can be complicated.  The "ahammer" blog from above provides a great script that can be found here: [lvmcache-statistics.sh](http://www.ahammer.ch/manuals/linux/lvm/lvmcache-statistics.sh)

When trying to understand the cache, the presented statistics can be confusing, especially around state of the write cache. The `Cpy%Sync` column of the `lvs -a` output will show 2x different hints. 

* For the HDD / RAID DM, it will show the current state / percentage complete in building or the state of the RAID Device Mapper. So if just created, it is expected to be at ~0%. In a healthy / idle state, it should be at 100%.
* For the Cache enabled volume, this column will show what percentage of the "data" cache is considered dirty, or needs to be written from NVMe down to HDD.

Similarly the `Data%` &  `Meta%` columns can be confusing. Both of these, in particular the `Data%` will naturally fill up as the cache device operates. The % *includes* read cached data, this means that the drive being 100% full is *fine*. What needs to be observed for write cache health is the amount of data reported in `Cpy%Sync` as well as the cache hit rates for Read / Write and "Dirty Pages", which can most easily be observed via the `lvmcache-statistics.sh` script from above.

The speed of the migration from data in the NVMe write cache to HDD is controlled by the  `migration_threshold`  variable of the dm-cache device. This is arbitrarily low for most deployments. It can be adjusted with `lvchange --cachesettings 'migration_threshold=512000 random_threshold=1' $VG_NAME/LV_NAME`. It is important to note that the migration threshold is coupled with dm-cache chunk size, they may overlap or block each other.  Note that this setting can have real impact on performance. The decision making criteria for this is quite dumb, and the system will absolutely swamp I/O trying to tier vs servicing active I/O.

It can also be useful to adjust the cache policy, in particular for the `cleaner` cache policy which can actively push data in the write cache down more aggressively.

* `lvchange --cachepolicy cleaner vg_01/lv_01`
* `lvchange --cachepolicy smq vg_01/lv_01`

Other useful commands stashed here with no reference:

* `lvs -o cache_dirty_blocks,cache_policy`
* `lvs -o name,cache_policy,cache_settings,chunk_size,cache_used_blocks,cache_dirty_blocks`
* `lvs -o+chunksize` 
* `sync; echo 3 > /proc/sys/vm/drop_caches`
* `dmsetup ls --tree`
