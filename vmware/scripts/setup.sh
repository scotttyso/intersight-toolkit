#!/usr/bin/bash

# Prepares a Ubuntu Server guest operating system.

### Create a cleanup script. ###
echo '> Creating cleanup script ...'
sudo cat <<EOF > /tmp/cleanup.sh
#!/bin/bash

# Cleans all audit logs.
echo '> Cleaning all audit logs ...'
if [ -f /var/log/audit/audit.log ]; then
cat /dev/null > /var/log/audit/audit.log
fi
if [ -f /var/log/wtmp ]; then
cat /dev/null > /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
cat /dev/null > /var/log/lastlog
fi

# Cleans persistent udev rules.
echo '> Cleaning persistent udev rules ...'
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
rm /etc/udev/rules.d/70-persistent-net.rules
fi

# Cleans /tmp directories.
echo '> Cleaning /tmp directories ...'
rm -rf /tmp/*
rm -rf /var/tmp/*

# Cleans SSH keys.
echo '> Cleaning SSH keys ...'
rm -f /etc/ssh/ssh_host_*

# Sets hostname to localhost.
echo '> Setting hostname to localhost ...'
cat /dev/null > /etc/hostname
hostnamectl set-hostname localhost

# Cleans apt-get.
echo '> Cleaning apt-get ...'
apt-get clean
apt-get autoremove

# Cleans the machine-id.
echo '> Cleaning the machine-id ...'
truncate -s 0 /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# Cleans shell history.
echo '> Cleaning shell history ...'
unset HISTFILE
history -cw
echo > ~/.bash_history
rm -fr /root/.bash_history

# Cloud Init Nuclear Option
rm -rf /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg
rm -rf /etc/cloud/cloud.cfg.d/99-installer.cfg
echo "disable_vmware_customization: false" >> /etc/cloud/cloud.cfg
echo "# to update this file, run dpkg-reconfigure cloud-init
datasource_list: [ VMware, OVF, None ]" > /etc/cloud/cloud.cfg.d/90_dpkg.cfg

# Set boot options to not override what we are sending in cloud-init
echo `> modifying grub`
sed -i -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/" /etc/default/grub
update-grub
EOF

### Change script permissions for execution. ### 
echo '> Changeing script permissions for execution ...'
sudo chmod +x /tmp/cleanup.sh

### Setup Directories - Install intersight-tools ###
mkdir Downloads
mkdir Logs
mkdir github
cd github/
git clone https://github.com/scotttyso/intersight-tools
cd intersight-tools
sudo pip install -r requirements.txt
sudo ln -s $(readlink -f ezimm.py) /usr/bin/ezimm.py
sudo ln -s $(readlink -f ezci.py) /usr/bin/ezci.py
sudo ln -s $(readlink -f ezazure.ps1) /usr/bin/ezazure.ps1
sudo ln -s $(readlink -f ezpure_login.ps1) /usr/bin/ezpure_login.ps1
sudo ln -s $(readlink -f ezvcenter.ps1) /usr/bin/ezvcenter.ps1
cd ~
sudo pip install intersight

### Install Ansible ###
ansible-galaxy collection install cisco.intersight

### Install PowerShell ###
sudo snap install powershell --classic
pwsh -Command Install-Module -Name Intersight.PowerShell -Force
pwsh -Command Install-Module -Name VMware.PowerCLI -Force

### Install Terraform ###
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update -y
sudo apt-get install terraform -y
terraform -install-autocomplete

### Install ISDK ###
LOCATION=$(curl -s https://api.github.com/repos/cgascoig/isctl/releases/latest \
| grep "tag_name" \
| awk '{print "https://github.com/cgascoig/isctl/releases/download/" substr($2, 2, length($2)-3) \
"/isctl_" substr($2, 2, length($2)-3) "_Linux_x86_64.tar.gz"}' \
| sed 's/isctl_v/isctl_/'); curl -L -o isctl.tar.gz $LOCATION
tar -xvf isctl.tar.gz
rm isctl.tar.gz
sudo mv isctl /usr/local/bin/
sudo chmod +x /usr/local/bin/isctl

### Copy OVF Template Setup Files ###
wget https://raw.githubusercontent.com/scotttyso/intersight-toolkit/main/ovf_network_config.sh
wget https://raw.githubusercontent.com/scotttyso/intersight-toolkit/main/ovf-network-config.service
sudo chmod 744 ovf_network_config.sh
sudo chmod 664 ovf-network-config.service
sudo mv ovf_network_config.sh /usr/local/bin/ovf_network_config.sh
sudo mv ovf-network-config.service /etc/systemd/system/ovf-network-config.service
sudo systemctl daemon-reload
sudo systemctl enable ovf-network-config.service

## Executes the cleauup script. ### 
echo '> Executing the cleanup script ...'
sudo /tmp/cleanup.sh

## All done. ### 
echo '> Done.'  
