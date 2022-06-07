#!/bin/bash
DRIVE_SIZE=$(lsblk --bytes | grep -v nvme | grep disk | awk '{print$4}' | sort -nr | head -1)
RAID_DRIVES=$(lsblk --bytes | grep $DRIVE_SIZE | awk '{print"/dev/"$1}' | tr '\n' ' ')
NUM_DRIVES=$(echo $RAID_DRIVES | wc -w)
for DRIVE in $RAID_DRIVES ; do
    mdadm --zero-superblock $DRIVE > /dev/null 2>&1
done
mdadm --create --verbose --level=6 --raid-devices=$NUM_DRIVES /dev/md0 $RAID_DRIVES
