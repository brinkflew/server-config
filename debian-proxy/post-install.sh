#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                Debian 9.4 Stretch Post-Installation Script                ║
# ║      for building, preparing and configuring newly installed servers      ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║ Version: ... 0.0.0                                                        ║
# ║ Author: .... Antoine Van Serveyt <antoine.van.serveyt@avanserv.com>       ║
# ║ Created: ... Mon 18th, June 2018 at 10:15 by Antoine Van Serveyt          ║
# ║ License: ... MIT License                                                  ║
# ║                                                                           ║
# ║ Updated: ... Fri 21st, September 2018 at 08:15 by Antoine Van Serveyt     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Default values for variables
username="avanserv"
color="\033\[38;5;162m"

# Get variables from command line
while getopts u:c: option; do
  case "${option}"
  in
    u) username=${OPTARG};;
    c) color=${OPTARG};;
  esac
done

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Install Required Packages                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

apt update && apt upgrade -y
apt install -y git sudo bc

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Update default .bashrc                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Update the skel folder
cp ./skel/.bashrc /etc/skel/.bashrc

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Create the base admin user                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Create the user
useradd -G sudo -m -s /bin/bash $username
echo "$username:GGc^7y248EJJE8r@" | chpasswd
chage -d 0 $username

# Move the pre-installed SSH key to the newly created user
mkdir /home/$username/.ssh
mv /root/.ssh/authorized_keys /home/$username/.ssh/authorized_keys && \
rm -Rf /root/.ssh && \
chown $username:$username /home/$username/.ssh && \
chown $username:$username /home/$username/.ssh/authorized_keys && \
chmod 700 /home/$username/.ssh && \
chmod 644 /home/$username/.ssh/authorized_keys

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Configure the SSH daemon                                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Setup SSHD configuration
cp ./config/sshd_config /etc/ssh/sshd_config && \
chown root:root /etc/ssh/sshd_config && \
chmod 600 /etc/ssh/sshd_config && \
sed -i "s/DefaultUserToBeOverriden/$username/" /etc/ssh/sshd_config

# Install the SSH banner
cp ./banner/issue.net /etc/issue.net && \
chown root:root /etc/issue.net && \
chmod 644 /etc/issue.net

# Restart the SSH daemon
systemctl restart ssh

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Install the dynamic MOTD                                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Install the TCL shell
apt install -y tclsh

# Disable the basic MOTD
systemctl disable motd

# Clean up the old MOTD files
rm -f /etc/motd && \
rm -f /var/run/motd.dynamic && \
rm -f /etc/update-motd.d/*

# Install the new MOTD scripts
cp ./motd/* /etc/update-motd.d/ && \
chown root:root /etc/update-motd.d/* && \
chmod 700 /etc/update-motd.d/* && \
chmod a+x /etc/update-motd.d/*

ln -s /run/motd.dynamic.new /run/motd.dynamic
#cp /run/motd.dynamic.new /run/motd.dynamic

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Apply network security                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Configure Hosts files
echo "sshd: ALL" | tee -a /etc/hosts.allow
echo "ALL: ALL" | tee -a /etc/hosts.deny

# Setup firewall rules (iptables)
mkdir /root/iptables && cp ./firewall/*.sh /root/iptables/
chown root:root /root/iptables
chown root:root /root/iptables/*
chmod 700 /root/iptables
chmod 600 /root/iptables/*
bash /root/iptables/*

# Install iptables-persistent
apt install -y iptables-persistent
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

# Make sure rules are saved for persistence
iptables-save > /root/iptables/rules.v4
ip6tables-save > /root/iptables/rules.v6
mv /root/iptables/rules.v4 /etc/iptables/rules.v4
mv /root/iptables/rules.v6 /etc/iptables/rules.v6

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Apply system hardening                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Check system hardening and apply modifications if needed
location=${pwd}
cd cis/
mkdir -p /etc/default
sed -i "s/disabled/enabled/" ./etc/conf.d/*
cp debian/default /etc/default/cis-hardening
sed -i "s#CIS_ROOT_DIR=.*#CIS_ROOT_DIR='$(pwd)'#" /etc/default/cis-hardening
chmod u+x ./bin/hardening.sh
chmod u+x ./bin/hardening/*.sh
./bin/hardening.sh --apply
cd $location

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Deactivate root login to TTY                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Deactivate root login
usermod -s /bin/false root

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Install and configure Nginx                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Install Nginx
echo "deb http://nginx.org/packages/mainline/ubuntu/ stretch nginx" >> /etc/apt/sources.list
mkdir -p /root/apt-keys
cd /root/apt-keys
wget http://nginx.org/keys/nginx_signing.key && \
apt-key add nginx_signing.key
apt install -y nginx
systemctl start nginx
systemctl enable nginx
