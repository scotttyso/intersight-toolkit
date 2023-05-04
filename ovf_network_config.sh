#!/bin/bash -x
# William Lam
# www.virtuallyghetto.com
# Tyson Scott
# Network Customization script for Ubuntu 22.0.4

if [ -e /root/ran_customization ]; then
    exit
else
    NETPLAN_FILE=$(ls /etc/netplan/*.yaml)

    DNS_DOMAINS=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.domain"   | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    DNS_SERVERS=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.dns"      | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    NTP_SERVERS=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.ntp"      | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    IP_ADDRESS=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.ipaddress" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    IP_SOURCE=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv"  | grep "guestinfo.ip_source" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    HOSTNAME=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv"    | grep "guestinfo.hostname" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    GATEWAY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv"     | grep "guestinfo.gateway"  | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    PREFIX=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv"      | grep "guestinfo.prefix"   | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')

    ######################################
    ### Determine if IP_SOURCE is DHCP ###
    ######################################
    if [[ ${IP_SOURCE} == DHCP ]]; then
        cat > ${NETPLAN_FILE} << __CUSTOMIZE_NETPLAN__
network:
  version: 2
  renderer: networkd
  ethernets:
    ens160:
      dhcp4: true
__CUSTOMIZE_NETPLAN__
    ##################################
    ### Static IP Address Settings ###
    ##################################
    else
        cat > ${NETPLAN_FILE} << __CUSTOMIZE_NETPLAN__
# This is the network config written by 'subiquity'
network:
  version: 2
  renderer: networkd
  ethernets:
    ens160:
      dhcp4: false
      addresses: [${IP_ADDRESS}/${PREFIX}]
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        search: [${DNS_DOMAINS}]
        addresses: [${DNS_SERVERS}]
__CUSTOMIZE_NETPLAN__

    hostnamectl set-hostname ${HOSTNAME}
    netplan apply
    fi
    if [[ ${NTP_SERVERS} ]]; then
    ###########################
    ### NTP Server Settings ###
    ###########################
        cat > /etc/ntp.conf << __CUSTOMIZE_TIMESYNC__
# /etc/ntp.conf, configuration for ntpd; see ntp.conf(5) for help

driftfile /var/lib/ntp/ntp.drift

# Leap seconds definition provided by tzdata
leapfile /usr/share/zoneinfo/leap-seconds.list

# Enable this if you want statistics to be logged.
#statsdir /var/log/ntpstats/

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

# Specify one or more NTP servers.
__CUSTOMIZE_TIMESYNC__
        IFS=', ' read -r -a array <<< ${NTP_SERVERS}
        printf "server %s\n" "${array[@]}" >> /etc/ntp.conf
        cat >> /etc/ntp.conf << __CUSTOMIZE_TIMESYNC__

# Use servers from the NTP Pool Project. Approved by Ubuntu Technical Board
# on 2011-02-08 (LP: #104525). See http://www.pool.ntp.org/join.html for
# more information.
# pool 0.ubuntu.pool.ntp.org iburst 
# pool 1.ubuntu.pool.ntp.org iburst 
# pool 2.ubuntu.pool.ntp.org iburst 
# pool 3.ubuntu.pool.ntp.org iburst 

# Use Ubuntu's ntp server as a fallback.
#pool ntp.ubuntu.com

# Access control configuration; see /usr/share/doc/ntp-doc/html/accopt.html for
# details.  The web page <http://support.ntp.org/bin/view/Support/AccessRestrictions>
# might also be helpful.
#
# Note that "restrict" applies to both servers and clients, so a configuration
# that might be intended to block requests from certain clients could also end
# up blocking replies from your own upstream servers.

# By default, exchange time with everybody, but don't allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1

# Needed for adding pool entries
restrict source notrap nomodify noquery

# Clients from this (example!) subnet have unlimited access, but only if
# cryptographically authenticated.
#restrict 192.168.123.0 mask 255.255.255.0 notrust


# If you want to provide time to your local subnet, change the next line.
# (Again, the address is an example only.)
#broadcast 192.168.123.255

# If you want to listen to time broadcasts on your local subnet, de-comment the
# next lines.  Please do this only if you trust everybody on the network!
#disable auth
#broadcastclient
__CUSTOMIZE_TIMESYNC__
        service ntp restart
    fi
    touch /root/ran_customization
fi
