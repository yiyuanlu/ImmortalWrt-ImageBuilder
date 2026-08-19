#!/bin/sh

# Safe first-boot network layout for a multi-port x86 soft router.
# Keep the default ImmortalWrt firewall policy unchanged: WAN input remains
# rejected. The first physical NIC becomes WAN; all remaining NICs join LAN.

ifnames=""
for iface in /sys/class/net/*; do
	name="$(basename "$iface")"
	if [ -e "$iface/device" ] && echo "$name" | grep -Eq '^(eth|en)'; then
		ifnames="$ifnames $name"
	fi
done
ifnames="$(echo "$ifnames" | awk '{$1=$1};1')"
count="$(echo "$ifnames" | wc -w)"

if [ "$count" -gt 1 ]; then
	wan_ifname="$(echo "$ifnames" | awk '{print $1}')"
	lan_ifnames="$(echo "$ifnames" | cut -d ' ' -f2-)"

	uci set network.wan='interface'
	uci set network.wan.device="$wan_ifname"
	uci set network.wan.proto='dhcp'
	uci set network.wan6='interface'
	uci set network.wan6.device="$wan_ifname"
	uci set network.wan6.proto='dhcpv6'

	bridge_section="$(uci show network | sed -n "s/^network\.\([^.=]*\)\.name='br-lan'$/\1/p" | head -n 1)"
	if [ -n "$bridge_section" ]; then
		uci -q delete "network.$bridge_section.ports"
		for port in $lan_ifnames; do
			uci add_list "network.$bridge_section.ports=$port"
		done
	fi

	uci set network.lan.proto='static'
	uci set network.lan.ipaddr='192.168.1.1'
	uci set network.lan.netmask='255.255.255.0'
	uci commit network
fi

exit 0
