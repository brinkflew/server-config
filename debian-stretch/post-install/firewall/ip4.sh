#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                 Debian 9.4 Stretch Firewall Configuration                 ║
# ║                               for IPv4 only                               ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║ Version: ... 0.0.0                                                        ║
# ║ Author: .... Antoine Van Serveyt <avanserv@brinkflew.com>                 ║
# ║ Created: ... Mon 18th, June 2018 at 14:05 by Antoine Van Serveyt          ║
# ║ License: ... MIT License                                                  ║
# ║                                                                           ║
# ║ Updated: ... Wed 19th, September 2018 at 16:41 by Antoine Van Serveyt     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Setup                                                                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Path to executable
IPT="/sbin/iptables"

# Shortcuts
LOG="-j LOG --log-level info --log-prefix"
LOG_WARN="-j LOG --log-level warning --log-prefix"
DROP="-j DROP"
ACCEPT="-j ACCEPT"
STATE="-m state --state"

# IPs configuration
EXT_IP="${external_ip}}"
INT_IP="${internal_ip}"
MGT_IP="${management_ip}"
PRX_IP="${proxy_ip}"
DNS_IPS="${dns_ips}"

# Networks CIDR
EXT_CIDR="${external_cidr}"
INT_CIDR="${internal_cidr}"
MGT_CIDR="${management_cidr}"

# Network cards configuration
EXT_INET="${external_inet}"
INT_INET="${internal_inet}"
MGT_INET="${management_inet}"

# Flush all existing rules
$IPT -F INPUT
$IPT -F FORWARD
$IPT -F OUTPUT
$IPT -F -t nat

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Default Policies                                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Configure default policies, applicable if no more specific rule below is
# applicable.  Default is to drop anything except for specifically authorized
# services and servers.
$IPT -P INPUT   DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT  DROP

# Allow traffic on the local interface
$IPT -A INPUT  -i lo $ACCEPT
$IPT -A OUTPUT -o lo $ACCEPT

# Allow traffic that is part of an established connection.
# Note, in the following rule, a connection becomes ESTABLISHED in the
# iptables PREROUTING chain upon receipt of a SYNACK packet that is a
# response to a previously sent SYN packet. The SYNACK packet itself is
# considered to be part of the established connection, so no special
# rule is needed to allow the SYNACK packet itself.
$IPT -A INPUT -i $INT_IP $STATE ESTABLISHED,RELATED $ACCEPT
$IPT -A INPUT -i $MGT_IP $STATE ESTABLISHED,RELATED $ACCEPT

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Management Rules                                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Allow SSH inbound connections from proxy server
$IPT -A INPUT -s $PRX_IP -d $INT_IP -p tcp --dport 9122 $LOG_WARN "[Allow SSH IN]"
$IPT -A INPUT -s $PRX_IP -d $INT_IP -p tcp --dport 9122 $ACCEPT

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Monitoring Rules                                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ICMP: Allow being pinged
$IPT -A INPUT  -p icmp -d $HOST_IP --icmp-type  8/0 $LOG "[Allow ICMP IN] "
$IPT -A INPUT  -p icmp -d $HOST_IP --icmp-type  8/0 $ACCEPT

# ICMP: Allow pinging
$IPT -A OUTPUT -p icmp -s $HOST_IP --icmp-type  8/0 $LOG "[Allow ICMP OUT] "
$IPT -A OUTPUT -p icmp -s $HOST_IP --icmp-type  8/0 $ACCEPT

# ICMP: Allow receiving ping timeouts
$IPT -A INPUT  -p icmp -d $HOST_IP --icmp-type 11/0 $LOG "[Allow ICMP Timeout IN] "
$IPT -A INPUT  -p icmp -d $HOST_IP --icmp-type 11/0 $ACCEPT

# ICMP: Allow sending ping timeouts
$IPT -A OUTPUT -p icmp -s $HOST_IP --icmp-type 11/0 $LOG "[Allow ICMP Timeout OUT] "
$IPT -A OUTPUT -p icmp -s $HOST_IP --icmp-type 11/0 $ACCEPT

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Kubernetes rules                                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Allow unrestricted outbound connections to internal network
$IPT -A OUTPUT -p tcp  -o $INT_INET -d $INT_CIDR $STATE NEW,ESTABLISHED $LOG "[Allow Internal OUT]"
$IPT -A OUTPUT -p tcp  -o $INT_INET -d $INT_CIDR $STATE NEW,ESTABLISHED $ACCEPT

# Allow unrestricted inbound connections from internal network
$IPT -A INPUT  -p tcp  -i $INT_INET -s $INT_CIDR $STATE NEW,ESTABLISHED $LOG "[Allow Internal IN]"
$IPT -A INPUT  -p tcp  -i $INT_INET -s $INT_CIDR $STATE NEW,ESTABLISHED $ACCEPT

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Internal traffic rules                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Allow unrestricted outbound connections to internal network
$IPT -A OUTPUT -o $INT_INET -m --multiport --dports 20,21,53,80,123,443 $STATE NEW,ESTABLISHED $LOG "[Allow Internal OUT] "
$IPT -A OUTPUT -o $INT_INET -m --multiport --dports 20,21,53,80,123,443 $STATE NEW,ESTABLISHED $ACCEPT

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Default Deny Rules                                                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Output
$IPT -A OUTPUT $LOG "[IPv4 Deny OUT] "
$IPT -A OUTPUT $DROP

# Input
$IPT -A INPUT  $LOG "[IPv4 Deny IN] "
$IPT -A INPUT  $DROP
