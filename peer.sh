#!/bin/bash
cmd="$1"
name="$2"
confdir='./peers'
NC='\033[0m'
DARKGREY='\033[1;30m'
LIGHTGREY='\033[0;37m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
LIGHTGREEN='\033[0;32m'
NET='10.1.2'
IP='1.2.3.4'
PORT='43211'
IFACE=wg0

usage() {
	echo 'Usage: ./peer [ gen | list | add <name> | del <name> | qr <name> ]'
}

addpeer() {
	name="$1"
	last="$(<$confdir/last)"
	ip="$(NET).$((last++))"

	echo $last > $confdir/last

	wg genkey | tee $confdir/$name.priv | wg pubkey > $confdir/$name.pub
	pubkey="$(<$confdir/$name.pub)"
	wg set wg0 peer "$pubkey" allowed-ips $ip/32

	echo -ne "
[Interface]
PrivateKey = $(<$confdir/$name.priv)
Address = ${ip)}/24
DNS = 8.8.8.8

[Peer]
PublicKey = $(<$confdir/${IFACE}.pub)
AllowedIPs = 0.0.0.0/0
Endpoint = ${IP}:${PORT}
" | tee $confdir/$name.conf
}

delpeer() {
	name="$1"

	address=$(grep Address $confdir/$name.conf|sed -r 's/.*(..)\/24/\1/')
	ip="${NET}.${address}"
	pubkey="$(<$confdir/$name.pub)"

	grep $address $confdir/unused || echo $address >> $confdir/unused

	wg set wg0 peer "$pubkey" allowed-ips $ip/32 remove

	rm $confdir/$name.conf
	rm $confdir/$name.priv
	rm $confdir/$name.pub
}

generate() {
	wg genkey | tee $confdir/$IFACE.priv | wg pubkey > $confdir/$IFACE.pub
	echo '100	v' >> /etc/iproute2/rt_tables
	echo "[Interface]
PrivateKey = $(<$confdir/$IFACE.priv)
Address = ${NET}.254

PostUp = ip ru ad from ${NET}.0/24 lookup v
PostUp = ip ro ad ${NET}.0/24 dev ${IFACE}
PostUp = ip ro ad ${NET}.0/24 dev ${IFACE} t v
#PostUp = iptables -A FORWARD -i ${IFACE} -j ACCEPT
#PostUp = iptables -A FORWARD -o ${IFACE} -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -s ${NET}.0/24 -o ${IFACE} -j MASQUERADE

PreDown = ip ru ad from ${NET}.0/24 lookup v
PreDown = ip ro ad ${NET}.0/24 dev ${IFACE}
PreDown = ip ro ad ${NET}.0/24 dev ${IFACE} t v
#PreDown = iptables -A FORWARD -i ${IFACE} -j ACCEPT
#PreDown = iptables -A FORWARD -o ${IFACE} -j ACCEPT
PreDown = iptables -t nat -A POSTROUTING -s ${NET}.0/24 -o ${IFACE} -j MASQUERADE

Table = off
" | tee $confdir/$IFACE.conf
}

install_wg() {
	echo "installing wg... (dummy)"
}

case $cmd in
	list)
		for i in $(ls -1 $confdir/*.pub); do
			iname=$(basename $i|sed 's/.pub//')
			pubkey=$(<$i)
			lasthandshake=$(wg | grep -A5 $pubkey | grep handshake | awk -F: '{print $2}')
			echo -e "$PURPLE$pubkey $WHITE$iname $LIGHTGREEN$lasthandshake $NC"
		done
		;;

	add) addpeer $name ;;
	del) delpeer $name ;;
	qr) qrencode -t ANSI -r $confdir/$name.conf ;;
	gen) generate ;;
	install) install_wg ;;
	help) usage ;;
	*) usage ;;
esac

exit 0


