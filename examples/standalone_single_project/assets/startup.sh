#! /bin/bash
set -e

sysctl -w net.ipv4.ip_forward=1
IFACE=$(ip -brief link | tail -1 | awk  {'print $1'})
iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
