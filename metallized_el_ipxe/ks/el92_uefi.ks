#version=RHEL9
reboot
text
%packages
@^server-product-environment

%end
url --url http://yourinfradomain.com
keyboard --xlayouts='us'
lang en_US.UTF-8
services --disabled=sshd,iscsid
firstboot --enable
skipx
clearpart --all --initlabel

%pre

lsblk --bytes | grep -v -E "nvme|zram" | grep disk | awk '{print$4,$1}' | sort -n  | head -2 | awk '{print$2}' | tr '\n' ',' | awk '{print"ignoredisk --only-use="$1}'| sed 's/,$/\n/' > /tmp/part-include

DRIVES=$(lsblk --bytes | grep -v -E "nvme|zram" | grep disk | awk '{print$4,$1}' | sort -n  | head -2 | awk '{print$2}')

DRIVE_LEN=$(echo $DRIVES | wc -c)

# Handle n3 case with only nvme
if [ "$DRIVE_LEN" != 2 ]; then
    DRIVES=$(lsblk --bytes | grep -v -E "zram" | grep disk | awk '{print$4,$1}' | sort -n  | head -2 | awk '{print$2}')
fi

echo "bootloader --location=mbr --boot-drive=$(echo $DRIVES | tr ' ' '\n' | head -1) --driveorder=$(echo $DRIVES | tr ' ' ',')" >> /tmp/part-include

for DRIVE in $DRIVES
do
        echo "part raid.1$DRIVE --fstype="mdmember" --ondisk=$DRIVE --size=576 --asprimary" >> /tmp/part-include
        echo "part raid.2$DRIVE --fstype="mdmember" --ondisk=$DRIVE --size=1024 --asprimary" >> /tmp/part-include
        echo "part raid.3$DRIVE --fstype="mdmember" --ondisk=$DRIVE --size=2048" >> /tmp/part-include
        echo "part raid.4$DRIVE --fstype="mdmember" --ondisk=$DRIVE --size=106560" --grow >> /tmp/part-include
done

echo $DRIVES | awk '{print"raid /boot/efi --device=boot_efi --fstype=\"efi\" --level=RAID1 --fsoptions=\"umask=0077,shortname=winnt\" --label=boot_efi raid.1"$1" raid.1"$2}' >> /tmp/part-include

echo $DRIVES | awk '{print"raid swap --device=swap --fstype=\"swap\" --level=RAID1 raid.3"$1" raid.3"$2}' >> /tmp/part-include

echo $DRIVES | awk '{print"raid /boot --device=boot --fstype=\"ext3\" --level=RAID1 --label=boot raid.2"$1" raid.2"$2}' >> /tmp/part-include

echo $DRIVES | awk '{print"raid / --device=root --fstype=\"xfs\" --level=RAID1 raid.4"$1" raid.4"$2}' >> /tmp/part-include

%end

# === include partitioning scheme generated in pre ===
%include /tmp/part-include
# ====================================================

timezone Etc/UTC --utc

# https://ma.ttias.be/how-to-generate-a-passwd-password-hash-via-the-command-line-on-linux/
rootpw --iscrypted "$YOURPASSWDHASH"
user --groups=wheel --name=adminuser --password="$YOURPASSWDHASH

%addon com_redhat_kdump --disable --reserve-mb='auto'

%end

%packages
jq
dnf-automatic
%end

%post --log=/root/metal_ks_post.log

curl -s https://metadata.platformequinix.com/metadata -o /tmp/metadata

echo "alias bond0 bonding" > /etc/modprobe.d/bonding.conf
echo "options bond0 mode=4 miimon=100 uupdelay=50000 xmit_hash_policy=layer3+4 lacp_rate=slow" >> /etc/modprobe.d/bonding.conf

NUM_INTERFACES=$(ip link list up | grep BROADCAST | wc -l)

# Handle n3 case with only nvme
if [[ "$NUM_INTERFACES" == 4 ]]; then
    FIRST_INTERFACE=$(ip link list up | grep BROADCAST | grep -v "enp0s20f0u9" | awk 'NR==1' | awk '{print$2}' | tr -d "\:")
    SECOND_INTERFACE=$(ip link list up | grep BROADCAST | grep -v "enp0s20f0u9" | awk 'NR==3' | awk '{print$2}' | tr -d "\:")
else
    FIRST_INTERFACE=$(ip link | grep BROADCAST | grep "state UP" | grep -v "enp0s20f0u9" | awk 'NR==1' | awk '{print$2}' | tr -d "\:")
    SECOND_INTERFACE=$(ip link | grep BROADCAST | grep "state UP" | grep -v "enp0s20f0u9" | awk 'NR==2' | awk '{print$2}' | tr -d "\:")
fi

PUB_IP=$(jq -r '.network.addresses[] | select((.public==true) and .address_family==4) | .address' /tmp/metadata)
PUB_CIDR=$(jq -r '.network.addresses[] | select((.public==true) and .address_family==4) | "\/"+(.cidr|tostring)' /tmp/metadata)
PUB_GW=$(jq -r '.network.addresses[] | select((.public==true) and .address_family==4) | .gateway' /tmp/metadata)
PRI_IP=$(jq -r '.network.addresses[] | select((.public==false) and .address_family==4) | .address' /tmp/metadata)
PRI_CIDR=$(jq -r '.network.addresses[] | select((.public==false) and .address_family==4) | "\/"+(.cidr|tostring)' /tmp/metadata)
PRI_GW=$(jq -r '.network.addresses[] | select((.public==false) and .address_family==4) | .gateway' /tmp/metadata)

mkdir -p /var/tmp/unified_el_init
cat > /var/tmp/unified_el_init/unified_el_init.sh << EOL
if test -f /var/tmp/unified_el_init/unified_el_init_1.lock; then
    logger -s "unified_el_init: upgrade from install -> current should be done"
        if test -f /var/tmp/unified_el_init/unified_el_init_2.lock; then
            logger -s "unified_el_init: init should be complete, exiting"
            exit 0
        else
            logger -s "unified_el_init: finizaling initialization"
            nmcli connection down '$FIRST_INTERFACE'
            nmcli connection delete '$FIRST_INTERFACE'
            nmcli connection down enp0s20f0u9u2c2
            nmcli connection delete bond0-port1
            nmcli connection delete bond0-port2
            sync
            sleep 1
            nmcli connection add type bond con-name bond0 ifname bond0 bond.options "mode=802.3ad,miimon=100,lacp_rate=slow,updelay=5000,xmit_hash_policy=layer3+4"
            nmcli connection add type ethernet slave-type bond con-name bond0-port1 ifname $FIRST_INTERFACE master bond0
            nmcli connection add type ethernet slave-type bond con-name bond0-port2 ifname $SECOND_INTERFACE master bond0
            nmcli connection modify bond0 ipv4.addresses '$PUB_IP$PUB_CIDR' ipv4.gateway '$PUB_GW' ipv4.dns '147.75.207.207,147.75.207.208' ipv4.method manual
            nmcli con mod bond0 +ipv4.addresses '$PRI_IP$PRI_CIDR'
            nmcli con mod bond0 +ipv4.routes '$PRI_GW$PRI_CIDR $PRI_GW'
            nmcli con mod bond0 +ipv4.routes '10.0.0.0/8 $PRI_GW'
            nmcli connection up bond0
            systemctl enable --now sshd
            systemctl enable --now dnf-automatic.timer
            systemctl disable unified_el_init.service
            touch /var/tmp/unified_el_init/unified_el_init_2.lock
            chmod -R 0400 /var/tmp/unified_el_init/
        fi

else
    logger -s "unified_el_init: applying configuration, upgrading and rebooting instance"
    echo "AllowAgentForwarding no" >> /etc/ssh/sshd_config
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    sed -i -e '/^#MaxAuthTries/s/^.*$/MaxAuthTries 5/' /etc/ssh/sshd_confi
    sed -i -e '/^X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
    echo "fastestmirror=True" >> /etc/dnf/dnf.conf
    echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
    sleep 5
    dnf upgrade -y --refresh
    sync
    sleep 20
    touch /var/tmp/unified_el_init/unified_el_init_1.lock
    reboot
    exit 0

fi
EOL

cat > /etc/systemd/system/unified_el_init.service << EOL
[Unit]
Description="unified_el_init"
Requires=NetworkManager.service

[Service]
Type=oneshot
TimeoutStartSec=900s
ExecStart=bash /var/tmp/unified_el_init/unified_el_init.sh

[Install]
WantedBy=multi-user.target
EOL

mkdir -p /home/adminuser/.ssh
jq -r '.ssh_keys[]' /tmp/metadata > /home/adminuser/.ssh/authorized_keys
chown -R adminuser /home/adminuser/
chmod 0600 /home/adminuser/.ssh/authorized_keys

hostnamectl set-hostname $(jq -r '.hostname' /tmp/metadata)

%end

%post --log /root/metal_systemd_ks.log
systemctl enable unified_el_init
%end

%post --nochroot
hostnamectl set-hostname $(jq -r '.hostname' /tmp/metadata)
hostnamectl --pretty set-hostname $(jq -r '.hostname' /tmp/metadata)
cp /etc/hostname /mnt/sysimage/etc/hostname
cp /etc/machine-info /mnt/sysimage/etc/machine-info
%end
