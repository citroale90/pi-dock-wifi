#!/bin/bash

. /bin/logger.sh

HOSTAPD_LOG="/var/log/hostapd_raw.log"
RAW_LOG_LINES=15000
RAW_ROTATION_INTERVAL=60

if [[ -z "$CONFIG_FILES" ]]; then
    log "[ERROR] Variabile CONFIG_FILES non definita!"
    exit 1
fi
read -r -a configs <<< "$CONFIG_FILES"
log "[INFO] Avvio hostapd con config: $CONFIG_FILES"

# Process substitution keeps $! equal to the actual daemon, rather than awk.
# Traduzione / Translation: La sostituzione di processo mantiene in $! il PID del demone reale, non quello di awk
/usr/local/bin/hostapd -dd "${configs[@]}" \
    > >(timestamp_raw_stream >> "$HOSTAPD_LOG") 2>&1 &
HOSTAPD_PID=$!
rotate_logs_loop "$HOSTAPD_LOG" "$RAW_LOG_LINES" "$RAW_ROTATION_INTERVAL" &
ROT_PID=$!

# Preserve the existing minimum startup delay; tolerate slower socket creation.
# Traduzione / Translation: Conserva il ritardo minimo di avvio e tollera una creazione più lenta dei socket
sleep 5
read -r started _ < /proc/uptime
deadline=$(( ${started%%.*} + 45 ))
# /proc/uptime è monotono anche durante la correzione NTP dopo un blackout.
# Traduzione / Translation: /proc/uptime remains monotonic during NTP correction after power loss
while read -r now _ < /proc/uptime && (( ${now%%.*} <= deadline )); do
    if ! kill -0 "$HOSTAPD_PID" 2>/dev/null; then
        if wait "$HOSTAPD_PID"; then EXIT_CODE=1; else EXIT_CODE=$?; fi
        HOSTAPD_PID=
        break
    fi
    ready=true
    for iface in $AP_INTERFACE1 $AP_INTERFACE2; do
        [[ -z "$iface" ]] && continue
        response=$(timeout 2s hostapd_cli -i "$iface" ping 2>/dev/null) || response=
        grep -qx PONG <<< "$response" || ready=false
        status=$(timeout 2s hostapd_cli -i "$iface" status 2>/dev/null) || status=
        grep -Eq '^state=(ENABLED|DFS)$' <<< "$status" || ready=false
    done
    if [[ "$ready" == true ]]; then
        log "[INFO] Hostapd partito e risponde (PID $HOSTAPD_PID)."
        exit 0
    fi
    sleep 1
done

log "[ERROR] Hostapd non pronto (exit code: ${EXIT_CODE:-1})"
tail -20 "$HOSTAPD_LOG" 2>/dev/null | while IFS= read -r line; do
    log "[HOSTAPD] $line"
done
[[ -z "$HOSTAPD_PID" ]] || kill "$HOSTAPD_PID" 2>/dev/null || true
kill "$ROT_PID" 2>/dev/null || true
[[ -z "$HOSTAPD_PID" ]] || wait "$HOSTAPD_PID" 2>/dev/null || true
wait "$ROT_PID" 2>/dev/null || true
exit "${EXIT_CODE:-1}"
