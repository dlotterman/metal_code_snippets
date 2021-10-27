#/bin/bash

cd /tmp/
sudo echo 'deb https://linux.dell.com/repo/community/openmanage/950/focal focal main' | sudo tee -a /etc/apt/sources.list.d/linux.dell.com.sources.list
sudo wget https://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc
sudo apt-key add 0x1285491434D8786F.asc
sudo apt-get update

sudo apt install -y srvadmin-server-cli

# credit to: https://askubuntu.com/questions/1363450/how-to-install-dell-command-and-configure-tool-on-dell-inspiron-5520-running-ubu
sudo rm /var/lib/dpkg/info/srvadmin-hapi.postinst

echo "#!/bin/bash" | sudo tee /var/lib/dpkg/info/srvadmin-hapi.postinst
echo "/bin/true" | sudo tee -a /var/lib/dpkg/info/srvadmin-hapi.postinst

sudo dpkg --configure -a
sudo apt install -y srvadmin-hapi

sudo systemctl stop instsvcdrv
sudo systemctl disable instsvcdrv

sudo /opt/dell/srvadmin/sbin/srvadmin-services.sh start
