#!/system/bin/sh

MODPATH="/data/adb/modules/zapret"
REFRESH=$(cat "$MODPATH/config/dnscrypt-rules-fix" 2>/dev/null || echo "0")

setup() {
  INTERFACE_ONLY=$(cat "$MODPATH/config/interface-only" 2>/dev/null || echo "")
  IGNORE_DNSCRYPT=$(cat "$MODPATH/config/interface-ignore-dnscrypt" 2>/dev/null || echo "0")
  if [ -n "$INTERFACE_ONLY" ] && [ "$IGNORE_DNSCRYPT" = "1" ]; then
    IPT_EXCLUDE_PREROUTING="! -i $INTERFACE_ONLY"
    IPT_EXCLUDE_OUTPUT="! -o $INTERFACE_ONLY"
    IPT_EXCLUDE_FORWARD="! -i $INTERFACE_ONLY ! -o $INTERFACE_ONLY"
  else
    IPT_EXCLUDE_PREROUTING=""
    IPT_EXCLUDE_OUTPUT=""
    IPT_EXCLUDE_FORWARD=""
  fi
  echo 1 >/proc/sys/net/ipv4/conf/all/route_localnet
  for chain in PREROUTING OUTPUT FORWARD; do
    for proto in udp tcp; do
      case "$chain" in
        PREROUTING)
          IPTABLES_EXCLUDE="$IPT_EXCLUDE_PREROUTING"
          ;;
        OUTPUT)
          IPTABLES_EXCLUDE="$IPT_EXCLUDE_OUTPUT"
          ;;
        FORWARD)
          IPTABLES_EXCLUDE="$IPT_EXCLUDE_FORWARD"
          ;;
        *)
          IPTABLES_EXCLUDE=""
          ;;
      esac
      iptables -t nat -C "$chain" $IPTABLES_EXCLUDE -p $proto --dport 53 -j DNAT --to-destination 127.0.0.1:5253 2>/dev/null || iptables -t nat -A "$chain" $IPTABLES_EXCLUDE -p $proto --dport 53 -j DNAT --to-destination 127.0.0.1:5253
      ip6tables -t nat -C "$chain" $IPTABLES_EXCLUDE -p $proto --dport 53 -j REDIRECT --to-ports 5253 2>/dev/null || ip6tables -t nat -A "$chain" $IPTABLES_EXCLUDE -p $proto --dport 53 -j REDIRECT --to-ports 5253
    done
  done
  for chain in OUTPUT FORWARD; do
    for proto in udp tcp; do
      case "$chain" in
        OUTPUT)
          IPTABLES_FILTER_EXCLUDE="$IPT_EXCLUDE_OUTPUT"
          ;;
        FORWARD)
          IPTABLES_FILTER_EXCLUDE="$IPT_EXCLUDE_FORWARD"
          ;;
        *)
          IPTABLES_FILTER_EXCLUDE=""
          ;;
      esac
      iptables -t filter -C $chain $IPTABLES_FILTER_EXCLUDE -p $proto --dport 853 -j DROP 2>/dev/null || iptables -t filter -A $chain $IPTABLES_FILTER_EXCLUDE -p $proto --dport 853 -j DROP
      ip6tables -t filter -C $chain $IPTABLES_FILTER_EXCLUDE -p $proto --dport 853 -j DROP 2>/dev/null || ip6tables -t filter -A $chain $IPTABLES_FILTER_EXCLUDE -p $proto --dport 853 -j DROP
    done
  done
}

start_bg(){
  [ -x "$MODPATH/dnscrypt/make-unkillable.sh" ] && nohup sh "$MODPATH/dnscrypt/make-unkillable.sh" >/dev/null 2>&1 &
  [ -x "$MODPATH/dnscrypt/dnscrypt-proxy" ] || { echo "dnscrypt-proxy not found" >&2; exit 1; }
  pgrep -x dnscrypt-proxy >/dev/null || "$MODPATH/dnscrypt/dnscrypt-proxy" >/dev/null 2>&1 &
}

start_fg(){
  [ -x "$MODPATH/dnscrypt/make-unkillable.sh" ] && nohup sh "$MODPATH/dnscrypt/make-unkillable.sh" >/dev/null 2>&1 &
  [ -x "$MODPATH/dnscrypt/dnscrypt-proxy" ] || { echo "dnscrypt-proxy not found" >&2; exit 1; }
  "$MODPATH/dnscrypt/dnscrypt-proxy" >/dev/null 2>&1
}

if [ "$REFRESH" = "1" ]; then
  while true; do
    setup
    start_bg
    sleep 5
  done
else
  while true; do
    setup
    start_fg
    sleep 5
  done
fi
