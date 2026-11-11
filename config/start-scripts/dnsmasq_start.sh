#!/bin/bash

. /bin/logger.sh

DNSMASQ_LOG="/var/log/dnsmasq_raw.log"
RAW_LOG_LINES=15000
RAW_ROTATION_INTERVAL=60

# A single launcher owns a daemon and its rotation process.
# Traduzione / Translation: Un solo launcher gestisce demone e processo di rotazione
exec 203>/var/lock/dnsmasq-start.lock || exit 1
flock -n 203 || exit 0
if pgrep -x dnsmasq >/dev/null; then
    log "[INFO] dnsmasq già attivo, nessun avvio duplicato."
    exit 0
fi

case "${1:-}" in
    '')
        # Keep the existing boot configuration and addresses unchanged.
        # Traduzione / Translation: Conserva configurazione di avvio e indirizzi esistenti
        ip link set br0 down || exit 1
        ip addr flush dev br0 || exit 1
        ip link set br0 up || exit 1
        ip addr add 192.168.4.1/24 dev br0 || exit 1
        ;;
    --recover)
        # Recovery starts the service without resetting the active bridge.
        # Traduzione / Translation: Il recupero riavvia il servizio senza reimpostare il bridge attivo
        ;;
    *) log "[ERROR] Argomento dnsmasq_start non valido"; exit 1 ;;
esac

for (( i=0; i<10; i++ )); do
    if ip addr show br0 | grep 'inet 192\.168\.4\.1/' >/dev/null; then break; fi
    sleep 1
done
if ! ip addr show br0 | grep 'inet 192\.168\.4\.1/' >/dev/null; then
    log "[ERROR] br0 senza indirizzo corretto; dnsmasq non verrà avviato."
    exit 1
fi

if [[ "${1:-}" != --recover ]]; then
    /bin/server-routes.sh || exit 1
fi

cleanup_dnsmasq() {
    [[ -z "${ROT_PID:-}" ]] || kill "$ROT_PID" 2>/dev/null || true
    if [[ "${DNSMASQ_RUNNING:-false}" == true ]]; then
        kill "$DNSMASQ_PID" 2>/dev/null || true
    fi
    [[ -z "${ROT_PID:-}" ]] || wait "$ROT_PID" 2>/dev/null || true
    if [[ -n "${DNSMASQ_PID:-}" ]] && [[ "$(cat /var/run/dnsmasq_custom.pid 2>/dev/null)" == "$DNSMASQ_PID" ]]; then
        rm -f /var/run/dnsmasq_custom.pid
    fi
}
trap cleanup_dnsmasq EXIT
trap 'DNSMASQ_STOPPING=true; exit 0' TERM INT

/usr/sbin/dnsmasq --no-daemon --conf-file=/etc/dnsmasq.conf \
    --dhcp-leasefile=/var/lib/misc/dnsmasq.leases \
    > >(timestamp_raw_stream >> "$DNSMASQ_LOG") 2>&1 &
DNSMASQ_PID=$!
DNSMASQ_RUNNING=true
printf '%s\n' "$DNSMASQ_PID" > /var/run/dnsmasq_custom.pid || exit 1
rotate_logs_loop "$DNSMASQ_LOG" "$RAW_LOG_LINES" "$RAW_ROTATION_INTERVAL" &
ROT_PID=$!

if wait "$DNSMASQ_PID"; then EXIT_CODE=0; else EXIT_CODE=$?; fi
DNSMASQ_RUNNING=false
if (( EXIT_CODE == 0 )); then
    log "[INFO] dnsmasq arrestato regolarmente."
else
    log "[WARN] dnsmasq terminato inaspettatamente (exit code $EXIT_CODE)"
fi
exit "$EXIT_CODE"
