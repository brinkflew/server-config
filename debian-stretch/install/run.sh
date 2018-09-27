#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                Debian 9.4 Stretch Post-Installation Script                ║
# ║      for building, preparing and configuring newly installed servers      ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║ Version: ... 0.0.1                                                        ║
# ║ Author: .... Antoine Van Serveyt <antoine.van.serveyt@avanserv.com>       ║
# ║ Created: ... Tue 25th, Sep. 2018 at 20:50 by Antoine Van Serveyt          ║
# ║ License: ... MIT License                                                  ║
# ║                                                                           ║
# ║ Updated: ...                                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Default values for using this script
username="avanserv"
userpass="GGc^7y248EJJE8r@"
usercolor="pink"

# Get variables from command line, if any
while getopts u:p:c:m:i:e: option; do
  case "${option}"
  in
    u) username=${OPTARG};;
    p) userpass=${OPTARG};;
    c) case "$OPTARG"
       in
         "pink") usercolor="\033\[38;5;162m";;
         "blue") usercolor="\033\[38;5;032m";;
         "green") usercolor="\033\[38;5;034m";;
         "yellow") usercolor="\033\[38;5;184m";;
         "orange") usercolor="\033\[38;5;214m";;
         "red") usercolor="\033\[38;5;196m";;
         "violet") usercolor="\033\[38;5;134m";;
         "white") usercolor="\033\[38;5;255m";;
       esac;;
  esac
done

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Install updates and required packages                                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Upgrade the new installation
apt update && apt upgrade -y

# Install packages util to the installation
apt install -y git sudo bc

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Update the default .bashrc                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Update the skel folder
cp ./skel/.bashrc /etc/skel/.bashrc

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Create the base admin user                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Create the user
useradd -G sudo -m -s /bin/bash $username
echo "$username:$userpass" | chpasswd
chage -d 0 $username

# Move the pre-installed SSH key to the newly created user
mkdir -p /home/$username/.ssh
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
cp ./ssh/sshd_config /etc/ssh/sshd_config && \
chown root:root /etc/ssh/sshd_config && \
chmod 600 /etc/ssh/sshd_config && \
sed -i "s/DefaultUserToBeOverriden/$username/" /etc/ssh/sshd_config

# Install the SSH banner
cp ./banner/issue.net /etc/issue.net && \
chown root:root /etc/issue.net && \
chmod 644 /etc/issue.net

# Install Fail2Ban to tighten SSH security
apt install -y fail2ban
cp ./fail2ban/jail.local /etc/fail2ban/jail.local
systemctl start fail2ban
systemctl enable fail2ban

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

# Ensure MOTD is displayed on first logon
ln -s /run/motd.dynamic.new /run/motd.dynamic

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Apply network security                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Configure Hosts files
echo "sshd: ALL" | tee -a /etc/hosts.allow
echo "ALL: ALL" | tee -a /etc/hosts.deny

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Install and configure Nginx                                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Install Nginx
# apt install -y apt-transport-https ca-certificates curl
# curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
# add-apt-repository "deb http://nginx.org/packages/mainline/ubuntu/ stretch nginx"
# apt update
# apt install -y nginx
# systemctl start nginx
# systemctl enable nginx

# Install Certbot for automatic renewal of SSL certificates
# apt install software-properties-common && \
# add-apt-repository ppa:certbot/certbot && \
# apt update && \
# apt install certbot

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Apply system hardening                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Check system hardening and apply modifications if needed
cd cis/
mkdir -p /etc/default
sed -i "s/disabled/enabled/" ./etc/conf.d/*
cp debian/default /etc/default/cis-hardening
sed -i "s#CIS_ROOT_DIR=.*#CIS_ROOT_DIR='$(pwd)'#" /etc/default/cis-hardening
chmod u+x ./bin/hardening.sh
chmod u+x ./bin/hardening/*.sh
./bin/hardening.sh --apply
cd ..

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Copy the post-install folder to the new user                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Move the post-install folder
cp -r ../post-install /home/$username
chown -R root:root /home/$username/post-install/* /home/$username/post-install/**/*
chmod u+x /home/$username/post-install/run.sh

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Terminate the install script                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

exit 0
