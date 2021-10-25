#!/bin/bash

#set -x

netex="ip netns exec"

bash ./cleanup.sh

ulimit -l 1000000

ip netns add n0
ip netns add n1

eth0="enp0s8"
eth1="enp0s9"

ip link set dev $eth0 down
ip link set dev $eth1 down
ip link set $eth0 netns n0
ip link set $eth1 netns n1


$netex n0 ip link set lo up
$netex n1 ip link set lo up
$netex n0 ip link set $eth0 up
$netex n1 ip link set $eth1 up

$netex n0 ip addr add 10.0.0.1/24 dev $eth0
$netex n1 ip addr add 10.0.0.2/24 dev $eth1

# Client side
$netex n0 ip link add link $eth0 name $eth0.83 type vlan id 83
$netex n0 ip link set $eth0.83 up
$netex n0 ip link add link $eth0.83 name $eth0.83.20 type vlan id 20
$netex n0 ip link set $eth0.83.20 up
$netex n1 ethtool -K $eth0 txvlan off

$netex n0 dhclient $eth0.83.20 &

# BNG side
$netex n1 ip link add link $eth1 name $eth0.83 type vlan id 83
$netex n1 ip link set $eth1.83 up
$netex n1 ip link add link $eth1.83 name $eth1.83.20 type vlan id 20
$netex n1 ip link set $eth1.83.20 up

$netex n1 ethtool -K $eth1 rxvlan off

echo "echo 1 > /proc/sys/net/ipv4/ip_forward" | $netex n1 bash

$netex n1 ./dhcp_user_xdp -i $eth1 -d 10.0.0.2 -s 10.0.0.1

$netex n0 wireshark -i $eth0 &
$netex n1 wireshark -i $eth1 &
