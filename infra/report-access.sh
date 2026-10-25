#!/bin/bash
set -euo pipefail

DB_PATH="${DB_PATH:-/var/lib/northernbridge/college.db}"
SITE_PORT="${SITE_PORT:-80}"

# Poll briefly for a bridged-adapter DHCP lease — on a fresh boot after
# `vagrant halt`, the interface can take a few seconds to re-acquire one.
for i in $(seq 1 15); do
    [ "$(ip -4 -o addr show scope global | wc -l)" -ge 2 ] && break
    sleep 1
done

discover_ips() {
    NAT_IP=""; BRIDGE_IP=""; local first_ip="" ip
    while IFS= read -r ip; do
        [ -z "$ip" ] && continue
        [ -z "$first_ip" ] && first_ip="$ip"
        case "$ip" in
            10.0.2.*) [ -z "$NAT_IP" ] && NAT_IP="$ip" ;;
            *)        [ -z "$BRIDGE_IP" ] && BRIDGE_IP="$ip" ;;
        esac
    done < <(ip -4 -o addr show scope global | awk '{gsub(/\/.*/,"",$4); print $4}')
    if [ -z "$NAT_IP" ] && [ -n "$first_ip" ]; then
        NAT_IP="$first_ip"
        [ "$BRIDGE_IP" = "$first_ip" ] && BRIDGE_IP=""
    fi
}

check_http() {
    local host="$1"
    [ -z "$host" ] && { echo ""; return; }
    curl -ksS -o /dev/null -w '%{http_code}' "http://${host}:${SITE_PORT}/" 2>/dev/null || echo "ERR"
}

discover_ips
NAT_CODE="$(check_http "$NAT_IP")"
BRIDGE_CODE="$(check_http "$BRIDGE_IP")"

if [ -n "$NAT_IP" ]; then
    echo "  [NAT adapter]      http://$NAT_IP:$SITE_PORT/    ->  HTTP ${NAT_CODE:-n/a}"
    echo "                     This site is ONLY accessible from inside the VirtualBox VM."
    echo "                     The host machine will NOT be able to reach this address"
    echo "                     until a port-forward is configured in the Vagrantfile."
else
    echo "  [NAT adapter]      not detected."
fi
echo
if [ -n "$BRIDGE_IP" ]; then
    echo "  [Bridged adapter]  http://$BRIDGE_IP:$SITE_PORT/    ->  HTTP ${BRIDGE_CODE:-n/a}"
    echo "                     This site can be reached by anyone connected to the same"
    echo "                     router / local network as this VM."
else
    echo "  [Bridged adapter]  not detected."
fi
echo
if [ -f "$DB_PATH" ]; then
    echo "  Student rows   : $(sqlite3 "$DB_PATH" 'SELECT COUNT(*) FROM students;')"
fi
