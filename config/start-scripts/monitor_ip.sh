#!/bin/bash
# Monitor e recupero uplink: NetworkManager host resta l’unico gestore DHCP.
# Mai down/flush della WAN, mai riavvii di hostapd, bridge o container.
# Traduzione / Translation: Uplink monitoring/recovery: host NetworkManager remains the sole DHCP owner. Never bring down or flush
# IT/EN: WAN, or restart hostapd, bridge or container.
. /bin/logger.sh

uplink_snapshot() {
    local flags carrier addresses gateway
    UPLINK_STATE=missing UPLINK_IP= UPLINK_GATEWAY=
    [[ -n "${INTERNET:-}" ]] || { UPLINK_STATE=not_configured; return; }
    flags=$(ip -o link show dev "$INTERNET" 2>/dev/null) || return 0
    flags=${flags#*<}; flags=${flags%%>*}
    if [[ ",$flags," != *,UP,* ]]; then UPLINK_STATE=admin_down; return; fi
    carrier=$(cat "${NET_SYSFS:-/sys/class/net}/$INTERNET/carrier" 2>/dev/null) || carrier=0
    if [[ "$carrier" != 1 ]]; then UPLINK_STATE=no_carrier; return; fi
    addresses=$(ip -4 -o addr show dev "$INTERNET" scope global 2>/dev/null) || addresses=
    UPLINK_IP=$(awk '$3=="inet" {print $4;exit}' <<< "$addresses")
    [[ -n "$UPLINK_IP" ]] || { UPLINK_STATE=no_ip; return; }
    UPLINK_GATEWAY=$(ip -4 route show default dev "$INTERNET" 2>/dev/null | awk '$1=="default" && $2=="via" {print $3;exit}')
    [[ -n "$UPLINK_GATEWAY" ]] || { UPLINK_STATE=no_route; return; }
    UPLINK_STATE=configured
}

uplink_snapshot
if [[ "${1:-}" == --snapshot ]]; then
    printf '%s ip=%s gateway=%s\n' "$UPLINK_STATE" "${UPLINK_IP:--}" "${UPLINK_GATEWAY:--}"
    exit 0
fi

uplink_report() {
    local reason target address=${UPLINK_IP%/*}
    case "$UPLINK_STATE" in
        configured)
            for target in 1.1.1.1 8.8.8.8 9.9.9.9; do
                if ping -I "$INTERNET" -c 1 -W 1 "$target" >/dev/null 2>&1; then
                    printf '[OK] IP: %s - GW: %s - WAN: UP\n' "${UPLINK_IP%/*}" "$UPLINK_GATEWAY"
                    return
                fi
            done
            reason="nessuna risposta ai ping"
            ;;
        no_carrier) reason="cavo scollegato" ;;
        admin_down) reason="interfaccia disattivata" ;;
        no_ip) reason="IP assente" ;;
        no_route) reason="gateway assente" ;;
        missing) reason="interfaccia assente" ;;
        not_configured) reason="interfaccia non configurata" ;;
    esac
    pdw_translate "$reason"
    printf '[WARN] IP: %s - GW: %s - WAN: %s\n' "${address:--}" "${UPLINK_GATEWAY:--}" "$PDW_MESSAGE"
}

if [[ "${1:-}" == --report ]]; then
    uplink_report
    exit 0
fi

# Il percorso resta quello storico: entrypoint -> monitor_ip.sh.
# Solo questo monitor supervisiona il worker; --snapshot sopra non lo avvia.
# Traduzione / Translation: Retain the original entrypoint→monitor_ip.sh path. Only this monitor supervises the worker; --snapshot
# IT/EN: does not start it.
RECOVERY_PID= RECOVERY_RETRY_AT=0 MONITOR_SLEEP_PID=
stop_recovery() {
    trap '' TERM INT HUP
    [[ -z "$RECOVERY_PID" ]] || kill -TERM "$RECOVERY_PID" 2>/dev/null || true
    [[ -z "$RECOVERY_PID" ]] || wait "$RECOVERY_PID" 2>/dev/null || true
    RECOVERY_PID=
    [[ -z "$MONITOR_SLEEP_PID" ]] || kill "$MONITOR_SLEEP_PID" 2>/dev/null || true
    [[ -z "$MONITOR_SLEEP_PID" ]] || wait "$MONITOR_SLEEP_PID" 2>/dev/null || true
    MONITOR_SLEEP_PID=
}
trap 'stop_recovery; exit 0' TERM INT HUP
trap stop_recovery EXIT
ensure_recovery() {
    if [[ -n "$RECOVERY_PID" ]] && kill -0 "$RECOVERY_PID" 2>/dev/null; then return 0; fi
    if [[ -n "$RECOVERY_PID" ]]; then
        wait "$RECOVERY_PID" 2>/dev/null || true
        RECOVERY_PID=
    fi
    (( now >= RECOVERY_RETRY_AT )) || return 0
    python3 -B /opt/pi-dock-wifi/recovery/worker.py &
    RECOVERY_PID=$!
    RECOVERY_RETRY_AT=$(( now + 15 ))
}

last_link= last_message= last_report=0 last_probe=0
while [[ ! -e /tmp/shutdown_in_progress ]]; do
    uplink_snapshot
    now=$(date +%s)
    ensure_recovery
    link="$UPLINK_STATE:$UPLINK_IP:$UPLINK_GATEWAY"
    if [[ "$link" != "$last_link" ]] || (( now - last_probe >= 60 || now - last_report >= 180 )); then
        message=$(uplink_report)
        if [[ "$link" != "$last_link" || "$message" != "$last_message" ]] || (( now - last_report >= 180 )); then
            log "$message"
            last_report=$now
        fi
        last_link=$link
        last_message=$message
        last_probe=$now
    fi
    sleep 10 & MONITOR_SLEEP_PID=$!
    wait "$MONITOR_SLEEP_PID" || true
    MONITOR_SLEEP_PID=
done
