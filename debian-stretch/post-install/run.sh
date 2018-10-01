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
norm="\e[0m"
bold="\e[1m"
grey="\e[38;5;238m"
pink="\e[38;5;162m"
white="\e[38;5;255m"

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
echo -e $bold
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e "  This script requires some information in order to setup networking on"
echo -e "  this server."
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e $norm
echo -e $pink"Internal Network MAC Address:"$norm
read mac_int

echo -e $pink"Internal Network IP Address:"$norm
read ip_int

echo -e $pink"Internal Network IP Mask:"$norm
read mask_int

echo -e $pink"Management Network MAC Address:"$norm
read mac_mgt

echo -e $pink"Management Network IP Address:"$norm
read ip_mgt

echo -e $pink"Management Network IP Mask:"$norm
read mask_mgt

echo -e $pink"Enable packet routing? (yes/no)"$norm
read routing

echo -e $pink"Is the server behind a proxy server? (yes/no)"$norm
read behind_proxy

if [ "$behind_proxy" == "yes" ]; then
  echo -e $pink"Proxy Server IP Address:"$norm
  read proxy_ip
fi

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Configure networking                                                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo -e $bold
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e "  Setting up the network interfaces"
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e $norm

# Find the management and internal interfaces
echo -e $bold">$norm$pink Finding the management network interface"$norm
inet_mgt=$(ip -o -4 link show | grep "$mac_mgt" | awk '{print $2}' | cut -d: -f1)
echo -e $bold">$norm$pink Finding the internal network interface"$norm
inet_int=$(ip -o -4 link show | grep "$mac_int" | awk '{print $2}' | cut -d: -f1)

# Replace network values in the interfaces file
echo -e $bold">$norm$pink Building the interfaces file"$norm
sed -i "s/\${public_inet}/ens3/" ./network/interfaces
sed -i "s/\${mgmt_inet}/$inet_mgt/" ./network/interfaces
sed -i "s/\${mgmt_ip}/$ip_mgt/" ./network/interfaces
sed -i "s/\${mgmt_mask}/$mask_mgt/" ./network/interfaces
sed -i "s/\${priv_inet}/$inet_int/" ./network/interfaces
sed -i "s/\${priv_ip}/$ip_int/" ./network/interfaces
sed -i "s/\${priv_mask}/$mask_int/" ./network/interfaces

# Copy the interface details
echo -e $bold">$norm$pink Copying the interfaces file to /etc/network/interfaces"$norm
cat ./network/interfaces | tee /etc/network/interfaces

# Boot the interfaces up
echo -e $bold">$norm$pink Booting the network interfaces up"$norm
ifup ens3
ifup $inet_mgt
ifup $inet_int

# Setup IP routes
echo -e $bold">$norm$pink Creating new default route"$norm


if [ "$routing" == "yes" ]; then
  echo 1 > /proc/sys/net/ipv4/ip_forward
fi

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Install the dynamic MOTD                                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo -e $bold
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e "  Updating the dynamic MOTD"
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e $norm

# Remove the first-login script
echo -e $bold">$norm$pink Removing the first-login script from /etc/update-motd.d/"$norm
rm -f /etc/update-motd.d/99-first-login && \
rm -f /var/run/motd.dynamic

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Apply network security                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo -e $bold
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e "  Setting up additional security rules"
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e $norm

# Temporarily stop Fail2Ban
echo -e $bold">$norm$pink Temporarily stopping fail2ban.service"$norm
systemctl stop fail2ban

# Find the external IP address
echo -e $bold">$norm$pink Finding the external IP address"$norm
ip_ext=$(ip -o -4 addr list ens3 | grep "inet " | awk '{print $4}' | cut -d/ -f1)

# Replace ip values in the iptables file
echo -e $bold">$norm$pink Building the iptables files"$norm
sed -i "s/\${external_ip}/$ip_ext/" ./firewall/ip4*.sh
sed -i "s/\${internal_ip}/$ip_int/" ./firewall/ip4*.sh
sed -i "s/\${management_ip}/$ip_mgt/" ./firewall/ip4*.sh
sed -i "s/\${proxy_ip}/$proxy_ip/" ./firewall/ip4*.sh
sed -i "s/\${dns_ips}//" ./firewall/ip4*.sh
sed -i "s/\${external_cidr}//" ./firewall/ip4*.sh
sed -i "s/\${internal_cidr}/$ip_int\/24/" ./firewall/ip4*.sh
sed -i "s/\${management_cidr}/$ip_mgt\/24/" ./firewall/ip4*.sh
sed -i "s/\${external_inet}/ens3/" ./firewall/ip4*.sh
sed -i "s/\${internal_inet}/$inet_int/" ./firewall/ip4*.sh
sed -i "s/\${management_inet}/$inet_mgt/" ./firewall/ip4*.sh

# Setup firewall rules (iptables)
echo -e $bold">$norm$pink Copying the iptables scripts to /root/iptables"$norm
mkdir /root/iptables && cp ./firewall/*.sh /root/iptables/
chown root:root /root/iptables
chown root:root /root/iptables/*
chmod 700 /root/iptables
chmod 600 /root/iptables/*

echo -e $bold">$norm$pink Applying iptables rules"$norm
if [ "$behind_proxy" == "no" ]; then
  echo -e $bold">$norm$pink Reading iptables file /root/iptables/ip4-proxy.sh"$norm
  bash /root/iptables/ip4-proxy.sh
else
  echo -e $bold">$norm$pink Reading iptables file /root/iptables/ip4.sh"$norm
  bash /root/iptables/ip4.sh
fi
bash /root/iptables/ip6.sh

# Install iptables-persistent
echo -e $bold">$norm$pink Making iptables rules persistent"$norm
apt install -y iptables-persistent
echo -e iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo -e iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

# Make sure rules are saved for persistence
iptables-save > /root/iptables/rules.v4
ip6tables-save > /root/iptables/rules.v6
mv /root/iptables/rules.v4 /etc/iptables/rules.v4
mv /root/iptables/rules.v6 /etc/iptables/rules.v6

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Install and configure Additional services                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

if [ "$behind_proxy" == "no" ]; then

  echo -e $bold
  echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
  echo -e "  Assuming we're installing a proxy, setting up Nginx"
  echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
  echo -e $norm

  # Install Nginx
  echo -e $bold">$norm$pink Installing required packages"$norm
  apt install -y apt-transport-https ca-certificates curl
  curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
  add-apt-repository "deb http://nginx.org/packages/mainline/ubuntu/ stretch nginx"
  apt update
  apt install -y nginx

  echo -e $bold">$norm$pink Starting the Nginx service"$norm
  systemctl start nginx
  systemctl enable nginx
else

  echo -e $bold
  echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
  echo -e "  Are we setting up Kubernetes?"
  echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
  echo -e $norm

  echo -e $pink"Is this server member of a Kubernetes cluster? (yes/no):"$norm
  read k8s_member

  if [ "$k8k8s_member" == "yes" ]; then

    echo -e $bold
    echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "  Installing Kubernetes"
    echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
    echo -e $norm

    # Install Docker
    echo -e $bold">$norm$pink Installing Docker"$norm
    apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian stretch stable"
    apt update
    apt install -y docker-ce

    echo -e $bold">$norm$pink Installing Kubernetes"$norm
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    add-apt-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
    apt update
    apt install -y kubelet kubeadm kubectl

    echo -e $pink"Is this server a master or a worker node? (master/worker)"$norm
    read k8s_type

    if [ "$k8s_type" == "master" ]; then

      # Initialize kubeadm
      echo -e $bold">$norm$pink Initializing Kubeadm"$norm
      kubeadm init --pod-network-cidr=172.16.0.0/16

    fi
  fi
fi

# Restart Fail2ban
echo -e $bold">$norm$pink Restarting fail2ban.service"$norm
systemctl start faiL2ban

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Deactivate root login to TTY                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo -e $bold
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e "  Deactivating root login"
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e $norm

# Deactivate root login
echo -e $bold">$norm$pink Setting root terminal to /bin/false"$norm
usermod -s /bin/false root

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Terminate the post-install script                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

echo -e $bold
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e "  All done, enjoy your new system!"
echo -e "╔═══════════════════════════════════════════════════════════════════════════╝"
echo -e $norm

exit 0
