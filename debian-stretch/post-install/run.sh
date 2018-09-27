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

# Shell colors
norm="\033\[0m"
bold="\033\[1m"
grey="\033\[38;5;238m"
pink="\033\[38;5;162m"
white="\033\[38;5;255m"

# Default values for variables
ip_int=""
ip_ext=""
ip_mgt=""
mask_int=""
mask_ext=""
mask_mgt=""
mac_int=""
mac_ext=""
mac_mgt=""
proxy_ip=""
behind_proxy="yes"
routing="no"

# Prompt for required information
echo $bold
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo "  This script requires some information in order to setup networking on"
echo "  this server."
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo $norm
echo $pink"Internal Network MAC Address:"$norm
read mac_int

echo $pink"Internal Network IP Address:"$norm
read ip_int

echo $pink"Internal Network IP Mask:"$norm
read mask_int

echo $pink"Management Network MAC Address:"$norm
read mac_mgt

echo $pink"Management Network IP Address:"$norm
read ip_mgt

echo $pink"Management Network IP Mask:"$norm
read mask_mgt

echo $pink"Enable packet routing? (yes/no)"$norm
read routing

echo $pink"Is the server behind a proxy server? (yes/no)"$norm
read behind_proxy

if [ "$behind_proxy" == "yes" ]; then
  echo $pink"Proxy Server IP Address:"$norm
  read proxy_ip
fi

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Configure networking                                                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo $bold
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo "  Setting up the network interfaces"
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo $norm

# Find the management and internal interfaces
echo $bold$white">$pink Finding the management network interface"$norm
inet_mgt=$(ip -o -4 link show | grep "$mac_mgt" | awk '{print $4}' | cut -d/ -f1)
echo $bold$white">$pink Finding the internal network interface"$norm
inet_int=$(ip -o -4 link show | grep "$mac_int" | awk '{print $4}' | cut -d/ -f1)

# Replace network values in the interfaces file
echo $bold$white">$pink Building the interfaces file"$norm
sed -i "s/\${public_inet}/ens3/" ./network/interfaces
sed -i "s/\${mgmt_inet}/$inet_mgt/" ./network/interfaces
sed -i "s/\${mgmt_ip}/$ip_mgt/" ./network/interfaces
sed -i "s/\${mgmt_mask}/$mask_mgt/" ./network/interfaces
sed -i "s/\${priv_inet}/$inet_int/" ./network/interfaces
sed -i "s/\${priv_ip}/$ip_int/" ./network/interfaces
sed -i "s/\${priv_mask}/$mask_int/" ./network/interfaces

# Copy the interface details
echo $bold$white">$pink Copying the interfaces file to /etc/network/interfaces"$norm
cat ./network/interfaces | tee -a /etc/network/interfaces

# Boot the interfaces up
echo $bold$white">$pink Booting the network interfaces up"$norm
ifup ens3
ifup $inet_mgt
ifup $inet_int

if [ "$routing" == "yes" ]; then
  echo 1 > /proc/sys/net/ipv4/ip_forward
fi

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Install the dynamic MOTD                                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo $bold
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo "  Updating the dynamic MOTD"
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo $norm

# Remove the first-login script
echo $bold$white">$pink Removing the first-login script from /etc/update-motd.d/"$norm
rm -f /etc/update-motd.d/99-first-login && \
rm -f /var/run/motd.dynamic

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Apply network security                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo $bold
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo "  Setting up additional security rules"
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo $norm

# Temporarily stop Fail2Ban
echo $bold$white">$pink Temporarily stopping fail2ban.service"$norm
systemctl stop fail2ban

# Find the external IP address
echo $bold$white">$pink Finding the external IP address"$norm
ip_ext=$(ip -o -4 addr list ens3 | grep "inet " | awk '{print $4}' | cut -d/ -f1)

# Replace ip values in the iptables file
echo $bold$white">$pink Building the iptables files"$norm
sed -i "s/\${external_ip}/$ip_ext/" ./firewall/ip4*.sh
sed -i "s/\${internal_ip}/$ip_int/" ./firewall/ip4*.sh
sed -i "s/\${management_ip}/$ip_mgt/" ./firewall/ip4*.sh
sed -i "s/\${proxy_ip}/$proxy_ip/" ./firewall/ip4*.sh
sed -i "s/\${dns_ips}//" ./firewall/ip4*.sh
sed -i "s/\${external_cidr}//" ./firewall/ip4*.sh
sed -i "s/\${internal_cidr}/$ip_int\/24/" ./firewall/ip4*.sh
sed -i "s/\${management_cidr}/$ip_mgt\/24/" ./firewall/ip4*.sh
sed -i "s/\${external_inet}/ens3\/24/" ./firewall/ip4*.sh
sed -i "s/\${internal_inet}/$inet_int\/24/" ./firewall/ip4*.sh
sed -i "s/\${management_inet}/$inet_mgt\/24/" ./firewall/ip4*.sh

# Setup firewall rules (iptables)
echo $bold$white">$pink Copying the iptables scripts to /root/iptables"$norm
mkdir /root/iptables && cp ./firewall/*.sh /root/iptables/
chown root:root /root/iptables
chown root:root /root/iptables/*
chmod 700 /root/iptables
chmod 600 /root/iptables/*

echo $bold$white">$pink Applying iptables rules"$norm
if [ "$behind_proxy" == "yes" ]; then
  bash /root/iptables/ip4-proxy.sh
else
  bash /root/iptables/ip4.sh
fi
bash /root/iptables/ip6.sh

# Install iptables-persistent
echo $bold$white">$pink Making iptables rules persistent"$norm
apt install -y iptables-persistent
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

# Make sure rules are saved for persistence
iptables-save > /root/iptables/rules.v4
ip6tables-save > /root/iptables/rules.v6
mv /root/iptables/rules.v4 /etc/iptables/rules.v4
mv /root/iptables/rules.v6 /etc/iptables/rules.v6

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Install and configure Additional services                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

if [ "$behind_proxy" == "no" ]; then

  echo $bold
  echo "╔═══════════════════════════════════════════════════════════════════════════╝"
  echo "  Assuming we're installing a proxy, setting up Nginx"
  echo "╔═══════════════════════════════════════════════════════════════════════════╝"
  echo $norm

  # Install Nginx
  echo $bold$white">$pink Installing required packages"$norm
  apt install -y apt-transport-https ca-certificates curl
  curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
  add-apt-repository "deb http://nginx.org/packages/mainline/ubuntu/ stretch nginx"
  apt update
  apt install -y nginx

  echo $bold$white">$pink Starting the Nginx service"$norm
  systemctl start nginx
  systemctl enable nginx
fi

# Restart Fail2ban
echo $bold$white">$pink Restarting fail2ban.service"$norm
systemctl start faiL2ban

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Deactivate root login to TTY                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo $bold
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo "  Deactivating root login"
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo $norm

# Deactivate root login
usermod -s /bin/false root

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Terminate the post-install script                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo $bold
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo "  Done, enjoy your new system!"
echo "╔═══════════════════════════════════════════════════════════════════════════╝"
echo $norm

exit 0
