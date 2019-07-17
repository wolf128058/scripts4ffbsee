#!/bin/bash

# -----
# title           :reset_ffbsee_routes.sh
# description     :reset the routes for a router or devide with an interface to ffbsee
# author          :Jonas aka Wolf
# version         :0.1
# usage           :reset_ffbsee_routes.sh
# -----

# just an auxiliary to get a ipv6 addr from a mac
format_eui_64() {
    local macaddr="$1"
    printf "%02x%s" $(( 16#${macaddr:0:2} ^ 2#00000010 )) "${macaddr:2}" \
        | sed -E -e 's/([0-9a-zA-Z]{2})*/0x\0|/g' \
        | tr -d ':\n' \
        | xargs -d '|' \
        printf "%02x%02x:%02xff:fe%02x:%02x%02x"
}

# dryrun feature
dryrun=0

# default route feature
default=0

# ethdev is the ethernetdevice with connection to ffbsee
ethdev='eth1'

# ipv4 ffbsee gateway
ipv4gw='10.15.224.1'
ipv6gw='fdef:1701:b5ee:23::1'

# get arguments
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -i|--interface)
    ethdev="$2"
    echo "- Custom Interface set: $ethdev"
    shift # past argument
    shift # past value
    ;;
    --gw4)
    ipv4gw="$2"
    shift # past argument
    shift # past value
    ;;
    --gw6)
    ipv6gw="$2"
    shift # past argument
    shift # past value
    ;;
    --default)
    default=1
    shift # past argument
    shift # past value
    ;;
    -d|--dryrun)
    dryrun=1
    shift # past argument
    ;;
    *)    # unknown option
    shift # past argument
    ;;
esac
done

# and now look for mac an get own ips
mac=$(ifconfig $ethdev | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
ipv6_suffix=$(format_eui_64 $mac)
ipv6_linklocal="fe80::$ipv6_suffix"
ipv6_ffbsee="fdef:1701:b5ee:23:$ipv6_suffix"

echo "- MAC: $mac"
echo "- IPv6-Link-Local: $ipv6_linklocal"
echo "- IPv6-FFBSEE-Suggestion: $ipv6_ffbsee"

if [[ $dryrun == 1 ]]; then
  echo '- Was just a dry-run I will not set any routes.'
  exit
fi

# give me some ipv6
ip -6 addr add $ipv6_linklocal/64 dev $ethdev
ip -6 addr add $ipv6_ffbsee/64 dev $ethdev

# let me set a default route on
ip route del fdef:1701:b5ee::/48
ip route add fdef:1701:b5ee::/48 dev $ethdev

# ipv4-to-ffbsee
ip route del 10.11.160.0/20
ip route add 10.11.160.0/20 dev $ethdev
ip route del 10.15.224.0/20
ip route add 10.15.224.0/20 dev $ethdev

# dn42
route -A inet6 del fd00::/8
route -A inet6 add fd00::/8 gw $ipv6gw dev $ethdev
ip route del 172.20.0.0/14
ip route add 172.20.0.0/14 via $ipv4gw dev $ethdev

# ipv4 ff3l
ip route del 10.119.0.0/16
ip route add 10.119.0.0/16 via $ipv4gw dev $ethdev

if [[ $default == 1 ]]; then
## default route feature v6
ip route del ::/0
ip route add ::/0 via $ipv6gw dev $ethdev
## default route feature v4
ip route delete default
ip route add default via $ipv4gw dev $ethdev
fi