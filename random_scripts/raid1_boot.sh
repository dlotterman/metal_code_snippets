#!/bin/bash

# License: WTFPL

# WARNING: THIS SCRIPT WILL HAPPILY DESTROY DATA

# This script will take a "vanilla" Equinix Metal instance
# Where that instance was provisioned with a stock Rocky 8.5 image
# And that instance is booted off of 1x of 2x internal drives,
# It will take the unused drive, put that into a linux software raid
# copy the partition and filesytem over to that single disk raid
# update grub and the bootables to boot from the single disk raid
# So the instance can be reboot, and the old disk wiped and 
# added to the raid array.
# This allows for a software RAID1 of an Equinix Metal Rocky instance's 
# internal drives. 

# Support / Warning / Disclaimer: This script is PoC ONLY
# It it meant to demonstrate the concept of moving to RAID 
# for a live Metal instance
# It is NOT production ready, it should be read and understood
# and re-written entirely to not be as terrible as it currently is

# After script is run, reboot so server is standing on RAID leg
# and add old drive in

# To easily secure a Alma/Rocky/CentOS 8 Metal instance, please see:
# https://github.com/dlotterman/metal_code_snippets/blob/main/boiler_plate_cloud_inits/alma_linux_8_5.yaml


# Adjust this to the size of the drive as listed in lsblk
# for the drive that is used as the boot drive by the Metal
# image
TARGETDRIVESIZE=447.1G



DRIVESTORAID=""
TMPDIR="/tmp/raidtmp"


# This stanza just finds the disk thats current running root
# and finds the other drive of the same size, puts them in a listed
# of drives and assigns the booted drive to target variable
# and empty drive to destination
for DRIVE in $(lsblk | grep $TARGETDRIVESIZE | awk '{print$1}'); do
	echo $DRIVE
	DRIVESTORAID="$DRIVESTORAID $DRIVE"
done

echo $DRIVESTORAID

for DRIVE in $DRIVESTORAID; do
	if grep --quiet $DRIVE /proc/mounts; then
		TARGETDRIVE=$DRIVE
		echo "Target drive is $DRIVE"
	else
		DESTDRIVE=$DRIVE
		echo "Destination drive is $DRIVE"
	fi
done


yum install -y mdadm grub2-efi-modules binutils

# cleanup from previous failds
# this will have verbose but ignoreable output

mdadm --stop /dev/md0
mdadm --stop /dev/md1
mdadm --remove /dev/md0
mdadm --remove /dev/md1
mdadm --fail /dev/md0 /dev/"$DESTDRIVE"2 
mdadm --remove /dev/md0 /dev/"$DESTDRIVE"2 
mdadm --fail /dev/md1 /dev/"$DESTDRIVE"3
mdadm --remove /dev/md1 /dev/"$DESTDRIVE"3
mdadm --zero-superblock /dev/$DESTDRIVE > /dev/null 2>&1

sgdisk --zap-all /dev/$DESTDRIVE 


partprobe
sleep 5

# copy partition table to get bios_grub parition
# build other partitions as a little diff than Metal default
# The reason we take this approach is to protect the 1MB 
# bios_grub legacy boot partition used by Equinix Metal
sgdisk -R /dev/$DESTDRIVE /dev/$TARGETDRIVE
sgdisk -G /dev/$DESTDRIVE
sgdisk -d 2 /dev/$DESTDRIVE
sgdisk -d 3 /dev/$DESTDRIVE
sgdisk -n 2:6144:+2G -c 2:SWAP -t 2:fd00 /dev/$DESTDRIVE
sgdisk -n 3:0:0 -c 3:ROOT -t 3:fd00 /dev/$DESTDRIVE
partprobe

sleep 5


# build raid array shell with dest drive
mdadm --create /dev/md0 --force --level 1 --raid-devices 2 /dev/"$DESTDRIVE"2 missing --metadata=1.2
mdadm --create /dev/md1 --force --level 1 --raid-devices 2 /dev/"$DESTDRIVE"3 missing --metadata=1.2

# lay swap and filesystem on drives
mkswap -L SWAP /dev/md0
mkfs.ext4 -F -L ROOT /dev/md1

# mount array 
mkdir -p $TMPDIR
mount /dev/md1 $TMPDIR

# copy root filesystem
rsync -auxHAXS --exclude=/run/* --exclude=/dev/* --exclude=/proc/* --exclude=/sys/* --exclude=/tmp/* --exclude=/mnt/* /* $TMPDIR

# meta for chroot
for mount in dev sys proc; do
	mount -o bind /$mount $TMPDIR/$mount
done

# new fstab / grub useable ID's
MD0UUID=$(mdadm --detail /dev/md0 | grep UUID | awk '{print$3}')
MD1UUID=$(mdadm --detail /dev/md1 | grep UUID | awk '{print$3}')
ROOTUUID=$(ls -al /dev/disk/by-uuid/ | grep md1 | awk '{print$9}')
SWAPUUID=$(ls -al /dev/disk/by-uuid/ | grep md0 | awk '{print$9}')


# This is key to getting grub to rebuild correctly to include MD data needed to boot
cat > $TMPDIR/etc/default/grub << EOL
GRUB_SERIAL_COMMAND='serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1'
GRUB_TERMINAL="serial console"
GRUB_CMDLINE_LINUX="resume=UUID=$ROOTUUID rd.md.uuid=$MD0UUID rd.md.uuid=$MD1UUID net.naming-scheme=rhel-8.4 console=tty0 console=ttyS1,115200n8"
GRUB_DEFAULT=saved
GRUB_ENABLE_BLSCFG=true
GRUB_PRELOAD_MODULES="mdraidlx"
EOL

# build script for inside of chroot 
cat > $TMPDIR/tmp/raidchroot.sh << EOL
#/bin/bash
mdadm --detail --scan >> /etc/mdadm.conf
echo raid1 >> /etc/modules-load.d/raid.conf
echo "UUID=$ROOTUUID   /   ext4    errors=remount-ro    0    1" >  /etc/fstab
echo "UUID=$SWAPUUID   none   swap    none    0    0" >>  /etc/fstab
dracut --regenerate-all -f --mdadmconf --fstab --add=mdraid --add-driver="raid1" >> /tmp/raidchroot.log 2>&1
grub2-mkconfig -o /boot/grub2/grub.cfg >> /tmp/raidchroot.log 2>&1
dracut --regenerate-all -f --mdadmconf --fstab --add=mdraid --add-driver="raid1" >> /tmp/raidchroot.log 2>&1
grub2-install  /dev/$DESTDRIVE >> /tmp/raidchroot.log 2>&1
grub2-install  /dev/$TARGETDRIVE >> /tmp/raidchroot.log 2>&1
exit
EOL

chmod 755 $TMPDIR/tmp/raidchroot.sh

# chroot and exec work from ^^

chroot $TMPDIR /tmp/raidchroot.sh

# start cleanup

for mount in dev sys proc; do
	umount $TMPDIR/$mount
done

rm $TMPDIR/tmp/raidchroot.sh

umount /dev/md1

echo "done, reboot when ready"

# After reboot, wipe old drive, copy parition table, add to raid array

# sgdisk -R /dev/sda /dev/sdb # drive that was boot is sda, drive that is now in raid is sdb, update to your needs
# sgdisk -G /dev/sda reset disks partition table UUID
#mdadm --manage /dev/md0 --add /dev/sda2
#mdadm --manage /dev/md1 --add /dev/sda3
