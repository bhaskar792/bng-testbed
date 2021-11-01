#!/bin/bash

#set -x

netex="ip netns exec"

./cleanup.sh
make
ulimit -l 1000000

ip netns add n0
ip netns add n1
ip netns add n2

eth0="enp6s0"
eth1="enp7s0"
eth2="enp8s0"
eth3="enp9s0"

ip link set dev $eth0 down
ip link set dev $eth1 down
ip link set dev $eth2 down
ip link set dev $eth3 down

ip link set $eth0 netns n0
ip link set $eth1 netns n1
ip link set $eth2 netns n1
ip link set $eth3 netns n2

$netex n0 ip link set lo up
$netex n1 ip link set lo up
$netex n2 ip link set lo up

$netex n0 ip link set $eth0 up
$netex n1 ip link set $eth1 up
$netex n1 ip link set $eth2 up
$netex n2 ip link set $eth3 up

#$netex n0 ip addr add 10.0.0.1/24 dev $eth0
$netex n1 ip addr add 10.0.0.2/24 dev $eth1
$netex n1 ip addr add 10.0.1.2/24 dev $eth2
$netex n2 ip addr add 10.0.1.1/24 dev $eth3

# Client side
$netex n0 ip link add link $eth0 name $eth0.83 type vlan id 83
$netex n0 ip link set $eth0.83 up
$netex n0 ip link add link $eth0.83 name $eth0.83.20 type vlan id 20
$netex n0 ip link set $eth0.83.20 up
$netex n1 ethtool -K $eth1 txvlan off

$netex n0 dhclient $eth0.83.20 &

# BNG side
$netex n1 ip link add link $eth1 name $eth1.83 type vlan id 83
$netex n1 ip link set $eth1.83 up
$netex n1 ip link add link $eth1.83 name $eth1.83.20 type vlan id 20
$netex n1 ip link set $eth1.83.20 up

$netex n1 ethtool -K $eth1 rxvlan off

echo "echo 1 > /proc/sys/net/ipv4/ip_forward" | $netex n1 bash

$netex n1 ./dhcp_user_xdp -i $eth1 -d 10.0.1.1 -s 10.0.1.2

#DHCP server side
# Added below line as dhcpd was having permission issues
$netex n2 chmod 777 /var/lib/dhcp/dhcpd.leases
#$netex n2 dhcpd -d &

$netex n0 wireshark -i $eth0 &
$netex n1 wireshark -i $eth1 &
$netex n2 wireshark -i $eth2 &
$netex n2 dhcpd -d &
