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
HOST_IP="$(hostname -I)"
INTERN_IP="10.0.0.0"
DNS_IP="0.0.0.0"
PROXY_IP="10.21.0.0"

# Network cards configuration
INET="ens3"

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
$IPT -A INPUT  $STATE ESTABLISHED,RELATED $ACCEPT
$IPT -A OUTPUT $STATE ESTABLISHED,RELATED $ACCEPT

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Management Rules                                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Allow SSH traffic
$IPT -A OUTPUT -s $HOST_IP -p tcp --dport 9122 $LOG_WARN "[IPv4 Allow SSH OUT] "
$IPT -A OUTPUT -s $HOST_IP -p tcp --dport 9122 $ACCEPT
$IPT -A INPUT  -d $HOST_IP -p tcp --dport 9122 $LOG_WARN "[IPv4 Allow SSH IN] "
$IPT -A INPUT  -d $HOST_IP -p tcp --dport 9122 $ACCEPT

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Monitoring Rules                                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ICMP: Allow being pinged
$IPT -A INPUT  -p icmp -d $HOST_IP --icmp-type  8/0 $LOG "[IPv4 Allow ICMP IN] "
$IPT -A INPUT  -p icmp -d $HOST_IP --icmp-type  8/0 $ACCEPT

# ICMP: Allow pinging
$IPT -A OUTPUT -p icmp -s $HOST_IP --icmp-type  8/0 $LOG "[IPv4 Allow ICMP OUT] "
$IPT -A OUTPUT -p icmp -s $HOST_IP --icmp-type  8/0 $ACCEPT

# ICMP: Allow receiving ping timeouts
$IPT -A INPUT  -p icmp -d $HOST_IP --icmp-type 11/0 $LOG "[IPv4 ICMP Timeout IN] "
$IPT -A INPUT  -p icmp -d $HOST_IP --icmp-type 11/0 $ACCEPT

# ICMP: Allow sending ping timeouts
$IPT -A OUTPUT -p icmp -s $HOST_IP --icmp-type 11/0 $LOG "[IPv4 ICMP Timeout OUT] "
$IPT -A OUTPUT -p icmp -s $HOST_IP --icmp-type 11/0 $ACCEPT

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Per-Service Rules                                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Allow DNS requests
$IPT -A OUTPUT -p udp -s $HOST_IP -o $INET --dport 53 $LOG "[IPv4 Allow DNS OUT] "
$IPT -A OUTPUT -p udp -s $HOST_IP -o $INET --dport 53 $ACCEPT
$IPT -A INPUT  -p udp -d $HOST_IP -i $INET --sport 53 $LOG "[IPv4 Allow DNS IN] "
$IPT -A INPUT  -p udp -d $HOST_IP -i $INET --sport 53 $ACCEPT

# Allow NTP sync
$IPT -A OUTPUT -p udp -s $HOST_IP -o $INET --dport 123 $LOG "[IPv4 Allow NTP OUT] "
$IPT -A OUTPUT -p udp -s $HOST_IP -o $INET --dport 123 $ACCEPT
$IPT -A INPUT  -p udp -d $HOST_IP -i $INET --sport 123 $LOG "[IPv4 Allow NTP IN] "
$IPT -A INPUT  -p udp -d $HOST_IP -i $INET --sport 123 $ACCEPT

# Allow FTP traffic (for package managers)
$IPT -A OUTPUT -p tcp -s $HOST_IP -o $INET --dport 21 $LOG "[IPv4 Allow FTP OUT] "
$IPT -A OUTPUT -p tcp -s $HOST_IP -o $INET --dport 21 $ACCEPT
$IPT -A INPUT  -p tcp -d $HOST_IP -i $INET --sport 21 $LOG "[IPv4 Allow FTP IN] "
$IPT -A INPUT  -p tcp -d $HOST_IP -i $INET --sport 21 $ACCEPT

# Allow HTTP traffic
$IPT -A OUTPUT -p tcp -s $HOST_IP -o $INET --dport 80 $LOG "[IPv4 Allow HTTP OUT] "
$IPT -A OUTPUT -p tcp -s $HOST_IP -o $INET --dport 80 $ACCEPT
$IPT -A INPUT  -p tcp -d $HOST_IP -i $INET --sport 80 $LOG "[IPv4 Allow HTTP IN] "
$IPT -A INPUT  -p tcp -d $HOST_IP -i $INET --sport 80 $ACCEPT

# Allow HTTPS traffic
$IPT -A OUTPUT -p tcp -s $HOST_IP -o $INET --dport 443 $LOG "[IPv4 Allow HTTPS OUT] "
$IPT -A OUTPUT -p tcp -s $HOST_IP -o $INET --dport 443 $ACCEPT
$IPT -A INPUT  -p tcp -d $HOST_IP -i $INET --sport 443 $LOG "[IPv4 Allow HTTPS IN] "
$IPT -A INPUT  -p tcp -d $HOST_IP -i $INET --sport 443 $ACCEPT

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Default Deny Rules                                                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Output
$IPT -A OUTPUT $LOG "[IPv4 Deny OUT] "
$IPT -A OUTPUT $DROP

# Input
$IPT -A INPUT  $LOG "[IPv4 Deny IN] "
$IPT -A INPUT  $DROP
