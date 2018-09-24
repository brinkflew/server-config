#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                 Debian 9.4 Stretch Firewall Configuration                 ║
# ║                               for IPv6 only                               ║
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
IPT="/sbin/ip6tables"

# Shortcuts
LOG="-j LOG --log-level info --log-prefix"
DROP="-j DROP"
ACCEPT="-j ACCEPT"

STATE="-m state --state"

# IPs configuration
HOST_IP="::"
DNS_IP="::"
PROXY_IP="::"

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

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ Default Deny Rules                                                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Input
$IPT -A INPUT  $LOG "[IPv6 Deny OUT] "
$IPT -A INPUT  $DROP

# Output
$IPT -A OUTPUT $LOG "[IPv6 Deny IN] "
$IPT -A OUTPUT $DROP
