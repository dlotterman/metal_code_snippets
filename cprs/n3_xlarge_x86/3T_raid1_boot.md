Desired output:

```
root@cprtest-api-04:~# df                                                                                               Filesystem      1K-blocks    Used  Available Use% Mounted on                                                            tmpfs            52775436    2272   52773164   1% /run                                                                  /dev/md126     3685949992 3378132 3495261152   1% /                                                                     tmpfs           263877180       0  263877180   0% /dev/shm                                                              tmpfs                5120       0       5120   0% /run/lock                                                             /dev/nvme2n1p1     523248    6220     517028   2% /boot/efi                                                             tmpfs            52775436       4   52775432   1% /run/user/0                                                           root@cprtest-api-04:~# df -h                                                                                            Filesystem      Size  Used Avail Use% Mounted on                                                                        tmpfs            51G  2.3M   51G   1% /run                                                                              /dev/md126      3.5T  3.3G  3.3T   1% /                                                                                 tmpfs           252G     0  252G   0% /dev/shm                                                                          tmpfs           5.0M     0  5.0M   0% /run/lock                                                                         /dev/nvme2n1p1  511M  6.1M  505M   2% /boot/efi                                                                         tmpfs            51G  4.0K   51G   1% /run/user/0                                                                       root@cprtest-api-04:~# cat /proc/mdstat                                                                                 Personalities : [raid1] [linear] [multipath] [raid0] [raid6] [raid5] [raid4] [raid10]                                   md126 : active raid1 nvme2n1p3[0] nvme3n1p3[1]                                                                                3745886528 blocks super 1.2 [2/2] [UU]                                                                                  [=>...................]  resync =  9.4% (353182208/3745886528) finish=282.7min speed=200017K/sec                        bitmap: 26/28 pages [104KB], 65536KB chunk                                                                                                                                                                                                md127 : active (auto-read-only) raid1 nvme2n1p2[0] nvme3n1p2[1]                                                               4189184 blocks super 1.2 [2/2] [UU]                                                                                                                                                                                                       unused devices: <none>                                                                                                  root@cprtest-api-04:~# lsblk                                                                                            NAME        MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS                                                                      loop0         7:0    0  63.9M  1 loop  /snap/core20/2105                                                                loop1         7:1    0 114.4M  1 loop  /snap/lxd/26741                                                                  loop2         7:2    0  40.4M  1 loop  /snap/snapd/20671                                                                nvme0n1     259:0    0 238.5G  0 disk                                                                                   nvme1n1     259:1    0 238.5G  0 disk                                                                                   nvme2n1     259:2    0   3.5T  0 disk                                                                                   ├─nvme2n1p1 259:3    0   512M  0 part  /boot/efi                                                                        ├─nvme2n1p2 259:4    0     4G  0 part                                                                                   │ └─md127     9:127  0     4G  0 raid1 [SWAP]                                                                           └─nvme2n1p3 259:5    0   3.5T  0 part                                                                                     └─md126     9:126  0   3.5T  0 raid1 /                                                                                nvme3n1     259:6    0   3.5T  0 disk                                                                                   ├─nvme3n1p1 259:7    0   512M  0 part                                                                                   ├─nvme3n1p2 259:8    0     4G  0 part                                                                                   │ └─md127     9:127  0     4G  0 raid1 [SWAP]                                                                           └─nvme3n1p3 259:9    0   3.5T  0 part                                                                                     └─md126     9:126  0   3.5T  0 raid1
```

```
curl -vv -X POST \
-H "Content-Type: application/json" \
-H "X-Auth-Token: $YOUR_API_TOKEN" \
"https://api.equinix.com/metal/v1/projects/$YOUR_PROJECT_ID/devices" \
-d '{
  "hardware_reservation_id":"$YOUR_RESERVATION_ID",
  "hostname": "cprtest-api-04",
  "operating_system": "ubuntu_22_04",
  "storage": {
  "disks": [
    {
      "device": "/dev/nvme2n1",
      "wipeTable": true,
      "partitions": [
        {
          "label": "BIOS",
          "number": 1,
          "size": "512M"
        },
        {
          "label": "SWAP",
          "number": 2,
          "size": "4G"
        },
        {
          "label": "ROOT",
          "number": 3,
          "size": "0"
        }
      ]
    },
    {
      "device": "/dev/nvme3n1",
      "wipeTable": true,
      "partitions": [
        {
          "label": "BIOS",
          "number": 1,
          "size": "512M"
        },
        {
          "label": "SWAP",
          "number": 2,
          "size": "4G"
        },
        {
          "label": "ROOT",
          "number": 3,
          "size": "0"
        }
      ]
    }
  ],
  "raid": [
    {
      "devices": [
        "/dev/nvme2n1p2",
        "/dev/nvme3n1p2"
      ],
      "level": "1",
      "name": "/dev/md/SWAP"
    },
    {
      "devices": [
        "/dev/nvme2n1p3",
        "/dev/nvme3n1p3"
      ],
      "level": "1",
      "name": "/dev/md/ROOT"
    }
  ],
  "filesystems": [
    {
      "mount": {
        "device": "/dev/nvme2n1p1",
        "format": "vfat",
        "point": "/boot/efi",
        "create": {
          "options": [
            "32",
            "-n",
            "EFI"
          ]
        }
      }
    },
    {
      "mount": {
        "device": "/dev/md/ROOT",
        "format": "ext4",
        "point": "/",
        "create": {
          "options": [
            "-L",
            "ROOT"
          ]
        }
      }
    },
    {
      "mount": {
        "device": "/dev/md/SWAP",
        "format": "swap",
        "point": "none",
        "create": {
          "options": [
            "-L",
            "SWAP"
          ]
        }
      }
    }
  ]
}
  }'
```
```
{
  "disks": [
    {
      "device": "/dev/nvme2n1",
      "wipeTable": true,
      "partitions": [
        {
          "label": "BIOS",
          "number": 1,
          "size": "512M"
        },
        {
          "label": "SWAP",
          "number": 2,
          "size": "4G"
        },
        {
          "label": "ROOT",
          "number": 3,
          "size": "0"
        }
      ]
    },
    {
      "device": "/dev/nvme3n1",
      "wipeTable": true,
      "partitions": [
        {
          "label": "BIOS",
          "number": 1,
          "size": "512M"
        },
        {
          "label": "SWAP",
          "number": 2,
          "size": "4G"
        },
        {
          "label": "ROOT",
          "number": 3,
          "size": "0"
        }
      ]
    }
  ],
  "raid": [
    {
      "devices": [
        "/dev/nvme2n1p2",
        "/dev/nvme3n1p2"
      ],
      "level": "1",
      "name": "/dev/md/SWAP"
    },
    {
      "devices": [
        "/dev/nvme2n1p3",
        "/dev/nvme3n1p3"
      ],
      "level": "1",
      "name": "/dev/md/ROOT"
    }
  ],
  "filesystems": [
    {
      "mount": {
        "device": "/dev/nvme2n1p1",
        "format": "vfat",
        "point": "/boot/efi",
        "create": {
          "options": [
            "32",
            "-n",
            "EFI"
          ]
        }
      }
    },
    {
      "mount": {
        "device": "/dev/md/ROOT",
        "format": "ext4",
        "point": "/",
        "create": {
          "options": [
            "-L",
            "ROOT"
          ]
        }
      }
    },
    {
      "mount": {
        "device": "/dev/md/SWAP",
        "format": "swap",
        "point": "none",
        "create": {
          "options": [
            "-L",
            "SWAP"
          ]
        }
      }
    }
  ]
}
```
