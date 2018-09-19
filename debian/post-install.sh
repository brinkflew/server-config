#!/bin/bash

echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║                Debian 9.4 Stretch Post-Installation Script                ║
echo ║      for building, preparing and configuring newly installed servers      ║
echo ╠═══════════════════════════════════════════════════════════════════════════╣
echo ║ Version: ... 0.0.0                                                        ║
echo ║ Author: .... Antoine Van Serveyt <avanserv@brinkflew.com>                 ║
echo ║ Created: ... Mon 18th, June 2018 at 10:15 by Antoine Van Serveyt          ║
echo ║ License: ... MIT License                                                  ║
echo ║                                                                           ║
echo ║ Updated: ...                                                              ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝

# Default values for varibales
user=brinkflew
color="\033\[38;5;162m"

# Get variables from command line
while getopts uc option; do
  case "${option}" in
    u) user=${OPTARG};;
    c) color=${OPTARG};;
  esac
done

echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║ Install Required Packages                                                ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝

apt update
apt upgrade
apt install -y git sudo

echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║ Update default .bashrc and .profile                                       ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝

# Update the skel folder
cp -r ./skel /etc/skel

echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║ Create the base admin user                                                ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝

# Create the user
useradd -G sudo -m -k /etc/skel $username

# Move the pre-installed SSH key to the newly created user
mkdir /home/$username/.ssh
mv /root/.ssh/authorized_keys /home/$username/.ssh/authorized_keys && \
rm -Rf /root/.ssh && \
chown $username:$username /home/$username/.ssh && \
chmod 600 /home/$username/.ssh

echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║ Configure the SSH daemon                                                  ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝

# Setup the SSHD config
cp ./config/sshd_config /etc/ssh/sshd_config && \
chown root:root /etc/ssh/sshd_config && \
chmod 600 /etc/ssh/sshd_config

# Install the SSH banner
cp ./banner/issue.net /etc/issue.net && \
chown root:root /etc/issue.net && \
chmod 644 /etc/issue.net

# Restart the SSH daemon
systemctl restart ssh

echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║ Install the dynamic MOTD                                                  ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝

cp ./motd/* /etc/update-motd.d/ && \
chown root:root /etc/update-motd.d/* && \
chmod 700 /etc/update-motd.d/*

echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║ Apply network security                                                    ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝

# Configure Hosts files
echo "sshd: ALL" | tee -a /etc/hosts.allow
echo "ALL: ALL" | tee -a /etc/hosts.deny

# Setup firewall rules (iptables)
mkdir /root/iptables && cp ./firewall/* /root/iptables
chown root:root /root/iptables
chown root:root /root/iptables/*
chmod 600 /root/iptables
chmod 700 /root/iptables/*
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

echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║ Apply system hardening                                                    ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝

# Check system hardening and apply modifications if needed
location=${pwd}
cd /root && git clone https://github.com/ovh/debian-cis && cd debian-cis/
mkdir -p /etc/default
sed -i "s/disabled/enabled/" ./etc/conf.d/*
sed -i "s#CIS_ROOT_DIR=.*#CIS_ROOT_DIR='$(pwd)'#" /etc/default/cis-hardening
cp debian/default /etc/default/cis-hardening
./bin/hardening.sh --apply
cd $location

echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║ Deactivate root login to TTY                                              ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝

# Deactivate root login
usermod -s /bin/false root
