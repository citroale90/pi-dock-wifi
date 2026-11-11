#!/bin/bash
# ==============================================================================
# HEALTHCHECK — Pi-Dock-Wifi
# Traduzione / Translation: HEALTHCHECK: Pi-Dock-Wifi
# ==============================================================================
# Filosofia: RIPARA prima di RIAVVIARE
# Traduzione / Translation: Policy: REPAIR before RESTART
#
# Livelli di intervento:
#   1. Controllo   → i servizi sono attivi?
#   2. Recovery    → se no, provo a ripararli
#   3. Escalation  → se il recovery fallisce N volte consecutive, restart container
# Traduzione / Translation: Intervention levels: check whether services are active; attempt repair when needed; restart the
# IT/EN: container only after repeated consecutive recovery failures.
#
# Il traffic monitoring è stato RIMOSSO — causava falsi positivi con client
# idle (telefono in standby). Il socket check di hostapd è sufficiente per
# verificare che l'AP funzioni.
# Traduzione / Translation: Traffic monitoring was removed because idle/standby clients caused false positives. The hostapd
# IT/EN: control socket is sufficient to check AP operation.
# ==============================================================================

set -o pipefail

EXITCODE=0
# Share the lock with entrypoint's log consumer; lock BEFORE truncating output.
# Traduzione / Translation: Condivide il lock con il lettore log dell’entrypoint: acquisirlo prima di troncare l’output
exec 210>/var/lock/healthcheck.lock || exit 1
flock -n 210 || exit 0
exec 1> /tmp/healthcheck-tmp 2>&1

. /bin/logger.sh

# I file di stato possono essere vuoti o danneggiati dopo una scrittura interrotta.
# Traduzione / Translation: State files may be empty or damaged after an interrupted write
read_counter() {
    local value=0
    { read -r value < "$1"; } 2>/dev/null || true
    [[ "$value" =~ ^[0-9]{1,6}$ ]] || value=0
    printf '%s\n' "$((10#$value))"
}

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

# --- Config ---
# Traduzione / Translation: Configuration
STATUS_FILE="/tmp/health_status"
FAIL_FILE="/tmp/healthcheck_consecutive_fails"
MAX_CONSECUTIVE_FAILS=3    # Restart container solo dopo N fallimenti consecutivi | IT/EN: Restart the container only after N consecutive failures

# --- Nessun recovery durante INIT, arresto o con marcatori di avvii precedenti ---
# Traduzione / Translation: No recovery during INIT, shutdown or when startup markers belong to an earlier boot
startup_is_current() {
    local marker boot ticks
    { read -r marker < /tmp/startup_complete; } 2>/dev/null || return 1
    boot=$(cat /proc/sys/kernel/random/boot_id) || return 1
    ticks=$(awk '{print $22}' /proc/1/stat) || return 1
    [[ -n "$boot" && "$ticks" =~ ^[0-9]+$ && "$marker" == "$boot:$ticks" ]]
}
if [[ -e /tmp/shutdown_in_progress ]] || ! startup_is_current; then
    echod "[INFO] Startup non completato, salto healthcheck"
    exit 0
fi

# --- Non controllare se un restart è già in corso ---
# Traduzione / Translation: Do not check while a restart is already in progress
if [[ -e /tmp/skip_check ]]; then
    echod "[INFO] Restart in corso, salto healthcheck"
    exit 0
fi

# ==============================================================================
# FUNZIONI
# Traduzione / Translation: FUNCTIONS
# ==============================================================================

# Incrementa il contatore di fallimenti consecutivi e ritorna il valore
# Traduzione / Translation: Increment the consecutive-failure counter and return its value
bump_fail() {
    local count
    count=$(read_counter "$FAIL_FILE")
    count=$(( count + 1 ))
    echo "$count" > "$FAIL_FILE"
    echo "$count"
}

# Reset contatore fallimenti
# Traduzione / Translation: Reset the failure counter
reset_fail() {
    echo "0" > "$FAIL_FILE" 2>/dev/null || true
}

# Restart del container (ultima risorsa)
# Traduzione / Translation: Restart the container as a last resort
restart_container() {
    local reason="$1"
    pdw_translate "$reason"
    reason=$PDW_MESSAGE
    [[ ! -e /tmp/shutdown_in_progress ]] || return 0
    declare -g EXITCODE=1
    echo "unhealthy" > "$STATUS_FILE"
    echo "1" > /tmp/skip_check

    log "[ERROR] RESTART: $reason"

    if pgrep -x hostapd > /dev/null; then
        pkill -9 -x hostapd
        log "[INFO] hostapd terminato"
    fi

    reset_fail
    return 1
}

# --- Check 1: br0 ha un IP? ---
# Traduzione / Translation: Check 1: does br0 have an IP address?
BRIDGE=br0
BRIDGE_ADDRESS=192.168.4.1/24
bridge_has_expected_address() {
    ip -4 -o addr show dev "$BRIDGE" 2>/dev/null | awk -v expected="$BRIDGE_ADDRESS" '
        $4 == expected { found=1 }
        END { exit !found }'
}

bridge_ready() {
    local link flags
    link=$(ip -o link show dev "$BRIDGE" 2>/dev/null) || return 1
    flags=${link#*<}
    flags=${flags%%>*}
    [[ ",$flags," == *,UP,* ]] || return 1
    bridge_has_expected_address
}

check_bridge() {
    bridge_ready && return 0
    [[ ! -e /tmp/shutdown_in_progress ]] || return 0
    log "[WARN] $BRIDGE inattivo o senza $BRIDGE_ADDRESS, tento recovery..."
    ip link set "$BRIDGE" up || return 1
    # Aggiunge solo l'indirizzo mancante, senza flush o disconnessioni.
    # Traduzione / Translation: Add only the missing address without flushing or disconnecting the interface
    if ! bridge_has_expected_address; then
        ip addr add "$BRIDGE_ADDRESS" dev "$BRIDGE" || return 1
    fi
    sleep 2
    if bridge_ready; then
        log "[INFO] $BRIDGE stato e indirizzo ripristinati con successo"
        return 0
    fi
    log "[ERROR] $BRIDGE non recuperabile"
    return 1
}

# --- Check 2: hostapd è attivo e risponde? ---
# Traduzione / Translation: Check 2: is hostapd running and responsive?
check_hostapd() {
    # 2a. Processo vivo?
    # Traduzione / Translation: 2a. Is the process alive?
    if ! pgrep -x hostapd > /dev/null; then
        log "[ERROR] hostapd non in esecuzione"
        return 1
    fi

    # 2b. Socket e ping per ogni interfaccia
    # Traduzione / Translation: 2b. Socket and ping for each interface
    local failed=0
    for iface in $AP_INTERFACE1 $AP_INTERFACE2; do
        [[ -z "$iface" ]] && continue

        if [[ ! -S "/var/run/hostapd/${iface}" ]]; then
            log "[WARN] Socket hostapd mancante per $iface"
            failed=1
            continue
        fi

        local response
        response=$(timeout 2s hostapd_cli -i "$iface" ping 2>/dev/null) || response=
        if ! grep -qx 'PONG' <<< "$response"; then
            log "[WARN] hostapd non risponde su $iface"
            failed=1
        fi
        local status link flags
        status=$(timeout 2s hostapd_cli -i "$iface" status 2>/dev/null) || status=
        # DFS è la normale attesa radar/CAC, non un errore del processo.
        # Traduzione / Translation: DFS is normal radar/CAC waiting, not a process failure
        if ! grep -Eq '^state=(ENABLED|DFS)$' <<< "$status"; then
            log "[WARN] Radio $iface non operativa"
            failed=1
        fi
        # Attesa radar legittima: non richiedere ancora il BSS nel bridge.
        # Traduzione / Translation: Legitimate radar waiting: do not require the BSS to be in the bridge yet
        grep -qx 'state=DFS' <<< "$status" && continue
        link=$(ip -o link show dev "$iface" 2>/dev/null) || link=
        flags=${link#*<}
        flags=${flags%%>*}
        if [[ ",$flags," != *,UP,* ]] || [[ ! "$link" =~ (^|[[:space:]])master[[:space:]]${BRIDGE}([[:space:]]|$) ]]; then
            log "[WARN] $iface inattiva o non collegata a $BRIDGE"
            failed=1
        fi

    done

    return $failed
}

# --- Check 3: dnsmasq è attivo? ---
# Traduzione / Translation: Check 3: is dnsmasq active?
check_dnsmasq() {
    if dnsmasq_ready; then
        return 0
    fi

    sleep 2
    if dnsmasq_ready; then
        log "[INFO] dnsmasq tornato attivo da solo"
        return 0
    fi

    if pgrep -x dnsmasq >/dev/null; then
        log "[ERROR] dnsmasq presente ma DHCP non in ascolto; nessun avvio duplicato"
        return 1
    fi

    if ! bridge_ready; then
        log "[ERROR] dnsmasq morto e br0 senza IP — skip recovery"
        return 1
    fi

    [[ ! -e /tmp/shutdown_in_progress ]] || return 0

    rm -f /var/run/dnsmasq_custom.pid 2>/dev/null || true

    log "[WARN] dnsmasq non attivo, riavvio..."

    # One launcher owns PID, cleanup and rotation for both boot and recovery.
    # Close the health lock in this long-running child.
    # Traduzione / Translation: Un solo launcher gestisce PID, cleanup e rotazione, sia per avvio sia per recupero. Chiude il lock
    # IT/EN: dell’healthcheck nel figlio di lunga durata.
    /bin/dnsmasq_start.sh --recover >/dev/null 2>&1 210>&- &

    sleep 3

    if dnsmasq_ready; then
        log "[INFO] dnsmasq riavviato con log + rotazione"
        return 0
    fi

    log "[ERROR] dnsmasq non recuperabile"
    return 1
}

# ==============================================================================
# ESECUZIONE CHECK
# Traduzione / Translation: RUN CHECKS
# ==============================================================================

PROBLEMS=()

check_bridge   || PROBLEMS+=("bridge")
check_hostapd  || PROBLEMS+=("hostapd")
check_dnsmasq  || PROBLEMS+=("dnsmasq")
# Verifica soltanto la configurazione locale prevista, senza ping al NAS/modem.
# Traduzione / Translation: Verify the expected local configuration only, without pinging NAS or modem
if [[ ! -e /tmp/shutdown_in_progress ]]; then
    /bin/server-routes.sh --quiet || { pdw_translate "rotte LAN"; PROBLEMS+=("$PDW_MESSAGE"); }
fi

# ==============================================================================
# DECISIONE
# Traduzione / Translation: DECISION
# ==============================================================================

if (( ${#PROBLEMS[@]} == 0 )); then
    # Tutto OK
    # Traduzione / Translation: All checks passed
    reset_fail

    # Log periodico (ogni 4 check = ~2 minuti)
    # Traduzione / Translation: Periodic log every four checks, approximately two minutes
    COUNTER_FILE="/tmp/healthcheck_counter"
    count=$(read_counter "$COUNTER_FILE")
    count=$(( count + 1 ))
    echo "$count" > "$COUNTER_FILE"

    if (( count % 4 == 0 )); then
        uplink=$(/bin/monitor_ip.sh --snapshot 2>/dev/null) || uplink="observer_error"
        case "$uplink" in
            configured*) log "[OK] Servizi locali Wi-Fi/DHCP/rotte sani; Ethernet: $uplink. Internet non verificata da questo healthcheck." ;;
            *) log "[WARN] Servizi locali Wi-Fi/DHCP/rotte sani; Ethernet degradata: $uplink. Nessun riavvio della LAN per un guasto a monte." ;;
        esac
        echo "0" > "$COUNTER_FILE"
    fi
else
    # Problemi rilevati
    # Traduzione / Translation: Problems detected
    fails=$(bump_fail)
    log "[WARN] Problemi: ${PROBLEMS[*]} (fallimento $fails/$MAX_CONSECUTIVE_FAILS)"

    if (( fails >= MAX_CONSECUTIVE_FAILS )); then
        restart_container "Fallimento consecutivo $fails: ${PROBLEMS[*]}"
    fi
fi

exit $EXITCODE
