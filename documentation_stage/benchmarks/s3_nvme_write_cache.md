```
fio --filename=data --direct=1 --rw=read --bs=4k --ioengine=libaio --iodepth=256 --numjobs=16 --group_reporting --name=iops-test-job --eta-newline=1 --size=1t
```

```
iops-test-job: (groupid=0, jobs=16): err= 0: pid=10759: Fri Oct 22 20:16:42 2021
  read: IOPS=352k, BW=1374MiB/s (1441MB/s)(16.0TiB/12208292msec)
    slat (nsec): min=1324, max=302999k, avg=11242.28, stdev=125503.59
    clat (usec): min=9, max=1221.2k, avg=11477.10, stdev=18482.35
     lat (usec): min=19, max=1221.2k, avg=11488.52, stdev=18483.28
    clat percentiles (usec):
     |  1.00th=[   318],  5.00th=[  1549], 10.00th=[  2212], 20.00th=[  3752],
     | 30.00th=[  6849], 40.00th=[ 10028], 50.00th=[ 11731], 60.00th=[ 12518],
     | 70.00th=[ 13173], 80.00th=[ 14091], 90.00th=[ 16712], 95.00th=[ 22414],
     | 99.00th=[ 40109], 99.50th=[ 55837], 99.90th=[316670], 99.95th=[442500],
     | 99.99th=[641729]
   bw (  MiB/s): min=   16, max= 9183, per=100.00%, avg=1395.17, stdev=50.26, samples=385487
   iops        : min= 4147, max=2350935, avg=357162.07, stdev=12867.09, samples=385487
  lat (usec)   : 10=0.01%, 20=0.01%, 50=0.02%, 100=0.07%, 250=0.62%
  lat (usec)   : 500=1.09%, 750=0.91%, 1000=0.75%
  lat (msec)   : 2=4.37%, 4=13.21%, 10=19.12%, 20=53.45%, 50=5.75%
  lat (msec)   : 100=0.36%, 250=0.13%, 500=0.10%, 750=0.03%, 1000=0.01%
  lat (msec)   : 2000=0.01%
  cpu          : usr=4.48%, sys=25.40%, ctx=1447704604, majf=0, minf=341489
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=4294967296,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=256

Run status group 0 (all jobs):
   READ: bw=1374MiB/s (1441MB/s), 1374MiB/s-1374MiB/s (1441MB/s-1441MB/s), io=16.0TiB (17.6TB), run=12208292-12208292msec
```

```
# lvs -a -o +devices
  LV                        VG    Attr       LSize   Pool                Origin        Data%  Meta%  Move Log Cpy%Sync Convert Devices
  lv_01                     vg_01 Cwi-aoC---  43.66t [lv_01_cache_cpool] [lv_01_corig] 99.98  0.27            0.00             lv_01_corig(0)
  [lv_01_cache_cpool]       vg_01 Cwi---C--- 429.25g                                   99.98  0.27            0.00             lv_01_cache_cpool_cdata(0)
  [lv_01_cache_cpool_cdata] vg_01 Cwi-ao---- 429.25g                                                                           /dev/nvme0n1(0)
  [lv_01_cache_cpool_cdata] vg_01 Cwi-ao---- 429.25g                                                                           /dev/nvme1n1(0)
  [lv_01_cache_cpool_cmeta] vg_01 ewi-ao----   3.81g                                                                           /dev/nvme1n1(48839)
  [lv_01_corig]             vg_01 rwi-aoC---  43.66t                                                          4.99             lv_01_corig_rimage_0(0),lv_01_corig_rimage_1(0),lv_01_corig_rimage_2(0),lv_01_corig_rimage_3(0),lv_01_corig_rimage_4(0),lv_01_corig_rimage_5(0),lv_01_corig_rimage_6(0),lv_01_corig_rimage_7(0),lv_01_corig_rimage_8(0),lv_01_corig_rimage_9(0),lv_01_corig_rimage_10(0),lv_01_corig_rimage_11(0)
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
  [lvol0_pmspare]           vg_01 ewi-------   3.81g                                                                           /dev/nvme1n1(49815)
