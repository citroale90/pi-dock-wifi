#!/bin/bash

# ==============================================================================
# ENTRYPOINT — Pi-Dock-Wifi
# Traduzione / Translation: ENTRYPOINT: Pi-Dock-Wifi
# ==============================================================================
# Fasi:
#   1. INIT (set -e attivo)   → check env, rete, bridge, hostapd, dnsmasq
#   2. RUNTIME (set -e off)   → monitor, healthcheck, webserver in background
# Traduzione / Translation: Phases: INIT uses set -e for environment, network, bridge, hostapd and dnsmasq; RUNTIME disables
# IT/EN: errexit for background monitors, healthcheck and web server.
#
# Se qualcosa fallisce durante INIT → il container muore e Docker lo riavvia.
# Se qualcosa fallisce durante RUNTIME → il healthcheck lo rileva e reagisce.
# Traduzione / Translation: A fatal INIT failure exits the container and Docker restarts it. RUNTIME failures are detected and
# IT/EN: handled by the healthcheck.
# ==============================================================================

set -Eeo pipefail

. /bin/logger.sh
case "${APP_LANGUAGE:-it}" in
    it) export LANG=it_IT.UTF-8 LC_ALL=it_IT.UTF-8 ;;
    en) export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 ;;
    *) pdw_echo "APP_LANGUAGE must be it or en" >&2; exit 1 ;;
esac

# Temporary compatibility for the existing container, before Compose recreation.
# Traduzione / Translation: Compatibilità temporanea con il container esistente, prima della ricreazione Compose
if [[ -r /opt/pi-dock-wifi-secrets/wifi.env ]]; then
    set -a
    . /opt/pi-dock-wifi-secrets/wifi.env
    set +a
fi

# Trap globale: logga riga e comando che ha fallito prima di morire
# Traduzione / Translation: Global trap: log the failing line and command before exiting
trap 'log "[FATAL] Errore alla riga $LINENO: comando \"$BASH_COMMAND\" (exit code $?)"' ERR

RUNTIME_PIDS=()
STOPPING=false

# Il filesystem del container sopravvive a docker restart e ai blackout.
# Il marcatore deve appartenere a questo avvio, non solo esistere.
# Traduzione / Translation: The container filesystem survives docker restart and power loss. The startup marker must identify this
# IT/EN: boot, not merely exist.
startup_token() {
    local boot ticks
    boot=$(cat /proc/sys/kernel/random/boot_id) || return 1
    ticks=$(awk '{print $22}' /proc/1/stat) || return 1
    [[ -n "$boot" && "$ticks" =~ ^[0-9]+$ ]] || return 1
    printf '%s:%s\n' "$boot" "$ticks"
}

# Helper: esegue una funzione con log strutturato
# Traduzione / Translation: Helper: execute a function with structured logging
run_step() {
    local label="$1"
    pdw_translate "$label"
    label=$PDW_MESSAGE
    shift
    log "[STEP] $label..."
    # Direct invocation preserves errexit during INIT. Runtime functions also
    # return explicitly on critical errors, since runtime intentionally uses +e.
    # Traduzione / Translation: La chiamata diretta conserva errexit durante INIT. Le funzioni runtime restituiscono esplicitamente
    # IT/EN: gli errori critici, poiché runtime usa intenzionalmente +e.
    "$@"
    local rc=$?
    if (( rc == 0 )); then
        log "[OK]   $label"
    else
        log "[FAIL] $label (exit code $rc)"
        return $rc
    fi
}

# ==============================================================================
# FASE 1 — INIT (ogni fallimento è fatale)
# Traduzione / Translation: PHASE 1: INIT; any failure is fatal
# ==============================================================================

# --- Verifiche preliminari ---
# Traduzione / Translation: Preliminary checks

check_required_env_vars() {
    local key value
    for key in WPA_PASSPHRASE1 WPA_PASSPHRASE2 DASHBOARD_PASSWORD PIHOLE_PASSWORD; do
        value="${!key:-}"
        if [[ -z "$value" || "$value" == CHANGE_ME* ]]; then
            log "[ERROR] Configure $key in .env before starting."
            exit 1
        fi
    done
    [[ "${WPS_UUID:-}" =~ ^[a-fA-F0-9-]{36}$ ]] || { log "[ERROR] Configure WPS_UUID in .env"; exit 1; }

    local missing=0
    for var in INTERNET AP_INTERFACE1 AP_INTERFACE2 CONFIG_FILES; do
        if [[ -z "${!var}" ]]; then
            log "[ERROR] Variabile d'ambiente '$var' non definita."
            missing=1
        fi
    done
    if (( missing )); then exit 1; fi
}

if [ ! -w "/sys" ]; then
    log "[ERROR] Manca la privileged mode."
    exit 1
fi

check_nsswitch() {
    /bin/check_nsswitch.sh \
        || log "[WARNING] check_nsswitch.sh errore (continuo)"
}

# --- Rete ---
# Traduzione / Translation: Network

obtain_ip_dhcp() {
    if ! ip link show "$INTERNET" &>/dev/null; then
        log "[ERROR] Interfaccia $INTERNET non esiste!"
        return 0  # Non fatale — potrebbe apparire dopo | IT/EN: Nonfatal: the interface may appear later
    fi

    if ip addr show "$INTERNET" | grep "inet " >/dev/null; then
        log "[INFO] $INTERNET ha un IP."
    else
        log "[WARNING] $INTERNET senza IP. DNS verrà comunque fissato."
    fi

    chattr -i /etc/resolv.conf 2>/dev/null || true
    printf "nameserver 192.168.4.1\nnameserver 1.1.1.1\n" > /etc/resolv.conf || return 1
    chattr +i /etc/resolv.conf || true
    log "[INFO] DNS fissato su 192.168.4.1."
}

setup_nat() {
    for param in ip_dynaddr ip_forward; do
        local val
        val=$(cat /proc/sys/net/ipv4/$param) || return 1
        if [ "$val" -eq 1 ]; then
            log "[INFO] $param già attivo"
        else
            echo "1" > /proc/sys/net/ipv4/$param || return 1
            log "[INFO] $param attivato"
        fi
    done
}

restore_iptables() {
    if [[ -f /bin/iptables-rules.sh ]]; then
        /bin/iptables-rules.sh
    else
        log "[ERROR] /bin/iptables-rules.sh non trovato"
        return 1
    fi
}

unblock_wifi() {
    local blocked
    blocked=$(rfkill list wifi | awk '/^[0-9]+:/{id=$1; sub(/:$/, "", id)} /Soft blocked: yes/{print id}' | xargs)
    if [[ -n "$blocked" ]]; then
        rfkill unblock wifi || { log "[ERROR] Sblocco WiFi fallito"; return 1; }
        log "[INFO] WiFi sbloccato: $blocked"
    else
        log "[INFO] Nessuna interfaccia WiFi bloccata."
    fi
}

# --- Bridge ---
# Traduzione / Translation: Bridge

setup_bridge() {
    for iface in $AP_INTERFACE1 $AP_INTERFACE2; do
        ip link set "$iface" nomaster 2>/dev/null || true
        ip link set "$iface" down 2>/dev/null || true
    done
    sleep 0.5

    if ip link show br0 &>/dev/null; then
        log "[INFO] br0 esiste, ricreo..."
        for iface in $(bridge -j link show master br0 | jq -r '.[].ifname'); do
            ip link set "$iface" nomaster 2>/dev/null || true
        done
        ip link set br0 down 2>/dev/null || true
        ip link del br0 2>/dev/null || true
        sleep 1
    fi

    ip link add name br0 type bridge || { log "[ERROR] Creazione br0 fallita"; return 1; }
    ip link set br0 up || return 1
    log "[INFO] Bridge br0 creato."
}

# --- Hostapd ---
# Traduzione / Translation: Hostapd

start_hostapd() {
    local FIRST_RUN_FLAG="/tmp/first_run_done"

    if [ -e /tmp/skip_check ]; then
        log "[INFO] skip_check presente, salto hostapd"
        return 0
    fi

    : "${WPA_PASSPHRASE1:?WPA_PASSPHRASE1 mancante}" "${WPA_PASSPHRASE2:?WPA_PASSPHRASE2 mancante}"
    umask 077
    # Genera configurazioni dai template
    # Traduzione / Translation: Generate configuration files from templates
    envsubst < /etc/hostapd/hostapd_46w.conf.template > /etc/hostapd/hostapd_46w.conf || return 1
    envsubst < /etc/hostapd/hostapd_56w.conf.template > /etc/hostapd/hostapd_56w.conf || return 1

    chmod 750 /etc/hostapd/ || return 1
    chmod 600 /etc/hostapd/*.deny /etc/hostapd/*.conf /etc/hostapd/*.template 2>/dev/null || true

    # Attendi che le interfacce WiFi siano pronte
    # Traduzione / Translation: Wait for the Wi-Fi interfaces to be ready
    sleep 3

    if [ -z "$CONFIG_FILES" ]; then
        log "[ERROR] CONFIG_FILES vuota"
        exit 1
    fi

    /bin/start_hostapd.sh &
    HOSTAPD_LAUNCH_PID=$!
    # wait è interrompibile: SIGTERM durante INIT non resta bloccato nel figlio.
    # Traduzione / Translation: wait is interruptible: SIGTERM during INIT does not remain blocked in a child
    if wait "$HOSTAPD_LAUNCH_PID"; then
        :
    else
        local rc=$?
        log "[ERROR] Hostapd non avviato (exit code $rc)"
        return "$rc"
    fi

    # Attendi che le interfacce entrino nel bridge (polling attivo)
    # Traduzione / Translation: Actively poll until the interfaces join the bridge
    local max_wait=20
    local waited=0
    local all_ready=false
    while (( waited < max_wait )); do
        all_ready=true
        for iface in $AP_INTERFACE1 $AP_INTERFACE2; do
            # Durante il CAC DFS il BSS può non essere ancora nel bridge.
            # Il controllo periodico richiederà il bridge quando sarà ENABLED.
            # Traduzione / Translation: During DFS CAC the BSS may not have joined the bridge yet. Periodic checks require it once its state
            # IT/EN: becomes ENABLED.
            if timeout 2s hostapd_cli -i "$iface" status 2>/dev/null | grep -qx 'state=DFS'; then
                continue
            fi
            if ! ip link show "$iface" 2>/dev/null | grep "master br0" >/dev/null; then
                all_ready=false
                break
            fi
        done
        if $all_ready; then break; fi
        sleep 1
        waited=$(( waited + 1 ))
    done

    # Verifica bridge-wait
    # Traduzione / Translation: Check the bridge wait result
    if ! $all_ready; then
        log "[ERROR] Interfacce non nel bridge dopo ${max_wait}s"
        return 1
    fi

    # Verifica che hostapd sia ancora vivo
    # Traduzione / Translation: Verify that hostapd is still alive
    if ! pgrep -x hostapd > /dev/null; then
        log "[ERROR] hostapd morto durante init bridge"
        exit 1
    fi

    # Tutto ok
    # Traduzione / Translation: All checks passed
    touch "$FIRST_RUN_FLAG" || return 1

    # Log stato finale
    # Traduzione / Translation: Log the final state
    for iface in $AP_INTERFACE1 $AP_INTERFACE2; do
        if ip link show "$iface" 2>/dev/null | grep "master br0" >/dev/null; then
            log "[INFO]   $iface → br0 OK"
        else
            log "[WARN]   $iface → br0 MANCANTE"
        fi
    done
}

# --- DHCP ---
# Traduzione / Translation: DHCP

# DHCP pronto soltanto se la porta 67 appartiene al dnsmasq del container.
# Un server DHCP di un altro container non prova che questo servizio funzioni.
# Traduzione / Translation: DHCP is ready only if port 67 belongs to this container’s dnsmasq. Another container’s DHCP listener
# IT/EN: does not prove this service works.
dnsmasq_ready() {
    local pids sockets pid
    pids=$(pgrep -x dnsmasq) || return 1
    sockets=$(ss -H -lunp 'sport = :67' 2>/dev/null) || return 1
    for pid in $pids; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        [[ "$sockets" == *"pid=$pid,"* ]] && return 0
    done
    return 1
}
start_dhcp() {
    /bin/dnsmasq_start.sh &
    local launcher=$!
    DNSMASQ_LAUNCH_PID=$launcher
    local rc
    local waited=0
    local max_wait=30
    while (( waited < max_wait )); do
        if dnsmasq_ready; then
            log "[INFO] Dnsmasq e socket DHCP pronti dopo ${waited}s."
            return 0
        fi
        if ! kill -0 "$launcher" 2>/dev/null; then
            if wait "$launcher"; then
                rc=1
            else
                rc=$?
            fi
            log "[ERROR] Avvio dnsmasq fallito (exit code $rc)"
            return "$rc"
        fi
        sleep 1
        waited=$(( waited + 1 ))
    done
    log "[ERROR] DHCP non pronto dopo ${max_wait}s"
    return 1
}

# --- Webserver ---
# Traduzione / Translation: Web server

start_webserver() {
    /bin/bash /opt/pi-dock-wifi-web/configure.sh || return 1
    mkdir -p /var/log/nginx 2>/dev/null || true

    env | grep -E '^(AP_INTERFACE1|AP_INTERFACE2|ETH_INTERFACE|INTERNET)=' > /etc/cgi-env.sh
    chmod 644 /etc/cgi-env.sh || return 1

    LC_ALL=C spawn-fcgi -s /var/run/fcgiwrap.socket -- /usr/sbin/fcgiwrap || return 1
    sleep 1
    chown root:www-data /var/run/fcgiwrap.socket || return 1
    chmod 660 /var/run/fcgiwrap.socket || return 1

    if [ ! -S /var/run/fcgiwrap.socket ]; then
        log "[ERROR] fcgiwrap socket non creato"
        return 1
    fi
    log "[INFO] fcgiwrap avviato"

    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    nginx || { log "[ERROR] nginx non partito"; return 1; }
    /bin/bash /opt/pi-dock-wifi-web/nginx-log-rotation.sh &
    NGINX_ROTATION_PID=$!
    log "[INFO] nginx avviato su porta 8888 (login e rotazione log attivi)"
}

# ==============================================================================
# FASE 2 — RUNTIME (errori gestiti, non fatali)
# Traduzione / Translation: PHASE 2: RUNTIME; errors are handled rather than immediately fatal
# ==============================================================================

monitor_ip() {
    /bin/monitor_ip.sh
}

healthcheck_loop() {
    while true; do
        sleep 30
        (
            flock -n 200 || exit 1
            if [ -f /tmp/healthcheck-tmp ]; then
                cat /tmp/healthcheck-tmp
                rm /tmp/healthcheck-tmp
            fi
        ) 200>/var/lock/healthcheck.lock
    done
}

monitor_health_status() {
    while true; do
        sleep 10
        if [[ -f /tmp/health_status ]] && grep -q unhealthy /tmp/health_status; then
            log "[ERROR] Healthcheck unhealthy. Terminazione..."
            kill -TERM "$MAIN_PID"
            return 1
        fi
    done
}

# ==============================================================================
# CLEANUP — Pulizia ordinata su SIGTERM/SIGINT/SIGHUP
# Traduzione / Translation: CLEANUP: orderly handling of SIGTERM, SIGINT and SIGHUP
# ==============================================================================

cleanup() {
    log "[INFO] Cleanup in corso..."

    [[ -z "${NGINX_ROTATION_PID:-}" ]] || kill "$NGINX_ROTATION_PID" 2>/dev/null || true
    [[ -z "${HOSTAPD_LAUNCH_PID:-}" ]] || kill "$HOSTAPD_LAUNCH_PID" 2>/dev/null || true
    [[ -z "${DNSMASQ_LAUNCH_PID:-}" ]] || kill "$DNSMASQ_LAUNCH_PID" 2>/dev/null || true
    pkill -x nginx 2>/dev/null || true
    pkill -x fcgiwrap 2>/dev/null || true
    pkill -x dnsmasq 2>/dev/null || true
    pkill -x hostapd 2>/dev/null || true

    local i=0
    while (( i < 10 )); do
        pgrep -x "hostapd|dnsmasq|nginx" > /dev/null 2>&1 || break
        sleep 0.5
        i=$(( i + 1 ))
    done

    for iface in $AP_INTERFACE1 $AP_INTERFACE2; do
        ip link set "$iface" nomaster 2>/dev/null || true
        ip link set "$iface" down 2>/dev/null || true
    done
    ip addr flush dev br0 2>/dev/null || true
    ip link set br0 down 2>/dev/null || true

    chattr -i /etc/resolv.conf 2>/dev/null || true

    rm -f /etc/hostapd/hostapd_46w.conf \
          /etc/hostapd/hostapd_56w.conf \
          /tmp/skip_check \
          /tmp/health_status \
          /tmp/startup_complete \
          /tmp/first_run_done \
          /tmp/log.tmp \
          /tmp/monitorip_counter \
          /tmp/monitorip_fails \
          /tmp/.log_lock \
          /tmp/healthcheck_first_run_done \
          /tmp/healthcheck_counter \
          /tmp/traffic_state_initialized \
          /var/run/fcgiwrap.socket \
          /tmp/healthcheck_consecutive_fails \
          /var/run/dnsmasq_custom.pid 2>/dev/null || true
    rm -rf /tmp/wifi_traffic_state 2>/dev/null || true

    log "[INFO] Cleanup completato."
}

handle_stop() {
    local signal="$1" rc=0 pid
    [[ "$STOPPING" == false ]] || return 0
    STOPPING=true
    trap '' SIGINT SIGTERM SIGHUP
    trap - ERR
    set +e
    touch /tmp/shutdown_in_progress /tmp/skip_check
    rm -f /tmp/startup_complete
    if [[ -f /tmp/health_status ]] && grep -qx unhealthy /tmp/health_status; then
        rc=1
        log "[ERROR] Ricevuto $signal dopo un guasto locale confermato; arresto controllato."
    else
        log "[INFO] Ricevuto $signal; arresto richiesto, non un errore INIT."
    fi
    for pid in "${RUNTIME_PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
    cleanup
    exit "$rc"
}

trap 'handle_stop SIGINT' SIGINT
trap 'handle_stop SIGTERM' SIGTERM
trap 'handle_stop SIGHUP' SIGHUP

# ==============================================================================
# MAIN — Orchestrazione
# Traduzione / Translation: MAIN: orchestration
# ==============================================================================

main() {
    export MAIN_PID=$$
    local start_time=$(date +%s)

    # Scarta solo stato transitorio: mai lease DHCP, credenziali o log persistenti.
    # Traduzione / Translation: Discard only transient state; never DHCP leases, credentials or persistent logs
    rm -f /tmp/startup_complete /tmp/shutdown_in_progress /tmp/skip_check \
        /tmp/health_status /tmp/first_run_done /tmp/healthcheck_first_run_done \
        /tmp/healthcheck_consecutive_fails /tmp/healthcheck_counter \
        /tmp/monitorip_counter /tmp/monitorip_fails

    log "[INFO] === INIT === (PID $$)"

    run_step "Verifica variabili"    check_required_env_vars
    run_step "Verifica nsswitch"     check_nsswitch
    run_step "Configurazione DNS"    obtain_ip_dhcp
    run_step "Configurazione NAT"    setup_nat
    run_step "Sblocco WiFi"          unblock_wifi
    run_step "Regole iptables"       restore_iptables
    run_step "Configurazione bridge" setup_bridge
    sleep 4
    run_step "Avvio hostapd"         start_hostapd
    run_step "Avvio dnsmasq"         start_dhcp
    # Le rotte non dipendono da quale percorso ha avviato dnsmasq.
    # Traduzione / Translation: Routes must not depend on which path started dnsmasq
    run_step "Rotte LAN"             /bin/server-routes.sh

    local elapsed=$(( $(date +%s) - start_time ))
    log "[INFO] === INIT completata in ${elapsed}s ==="

    # Disabilita set -e per la fase runtime
    # Traduzione / Translation: Disable set -e during runtime
    set +e
    # Rimuovi trap ERR per la fase runtime (non serve più, set -e è off)
    # Traduzione / Translation: Remove the ERR trap during runtime because errexit is off
    trap - ERR

    /bin/monitor_ip.sh &
    RUNTIME_PIDS+=("$!")
    healthcheck_loop &
    RUNTIME_PIDS+=("$!")
    monitor_health_status &
    RUNTIME_PIDS+=("$!")
    run_step "Avvio webserver" start_webserver || log "[WARN] Webserver non partito — dashboard offline"

    if ! startup_token > /tmp/startup_complete; then
        log "[ERROR] Impossibile pubblicare il marcatore di avvio corrente."
        return 1
    fi
    log "[INFO] === Tutti i servizi avviati ==="

    # Un segnale richiesto termina tramite handle_stop(), senza il falso FATAL 143.
    # Traduzione / Translation: Requested signals exit through handle_stop without a false FATAL 143 message
    if wait; then
        log "[WARN] Tutti i processi di monitoraggio sono terminati."
    else
        local rc=$?
        log "[ERROR] Attesa dei processi runtime terminata (exit code $rc)."
        return "$rc"
    fi
}

main
