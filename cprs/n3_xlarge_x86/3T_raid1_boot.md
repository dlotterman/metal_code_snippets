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
