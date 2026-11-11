#!/bin/bash
# Standalone host setup: private backup, storage and UPS shutdown are excluded.
# Traduzione / Translation: Preparazione host autonoma: esclusi backup privati, storage e spegnimento UPS
SERVICE_FILE_UDEV="/etc/udev/rules.d/70-persistent-net-names.rules"
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NEED_REBOOT=0
. "$PROJECT_DIR/config/i18n.sh"
pdw_load_language "$PROJECT_DIR/.env" || return 1 2>/dev/null || exit 1
#======================================================================
# FASE 1 - SISTEMA BASE (locale pi-router)
# Pacchetti, overlay kernel, overclock, naming persistente WiFi.
# Traduzione / Translation: PHASE 1: LOCAL BASE SYSTEM — packages, kernel overlays, overclock and persistent Wi-Fi naming
#======================================================================


# ------------------------------------------------------
# Pacchetti di sistema richiesti
# Traduzione / Translation: Required system packages
# ------------------------------------------------------
ensure_packages() {
    local REQUIRED_PKGS=(
        sshpass          # SSH con password (avahi reflector, watchdog) | IT/EN: SSH with password, original Avahi/watchdog dependency note
        nvme-cli         # nvme connect/disconnect | IT/EN: Connessione e disconnessione NVMe
        netcat-openbsd   # nc (test porte) | IT/EN: nc for port checks
        bridge-utils     # bridge link | IT/EN: Comandi di gestione del bridge
        avahi-daemon     # mDNS reflector | IT/EN: Ripetitore mDNS
        iproute2         # ip, bridge (di solito presente) | IT/EN: ip and bridge, usually already installed
        wget             # download generico | IT/EN: generic downloads
        curl             # notifiche Telegram (host-watchdog) | IT/EN: Telegram notifications, original host-watchdog dependency note
        ca-certificates  # per https | IT/EN: HTTPS certificates
    )

    local MISSING=()
    for PKG in "${REQUIRED_PKGS[@]}"; do
        if ! dpkg -s "$PKG" >/dev/null 2>&1; then
            MISSING+=("$PKG")
        fi
    done

    if [ ${#MISSING[@]} -eq 0 ]; then
        pdw_echo "Tutti i pacchetti richiesti sono già installati."
        return 0
    fi

    pdw_echo "Installo pacchetti mancanti: ${MISSING[*]}"
    if sudo apt-get update -q && sudo apt-get install -y "${MISSING[@]}"; then
        pdw_echo "  ✔ Pacchetti installati."
        return 0
    else
        pdw_echo "  ✖ ERRORE: installazione pacchetti fallita. Continuo ma alcune funzioni potrebbero fallire."
        return 1
    fi
}


# ------------------------------------------------------
# Persistent net names (WiFi)
# Traduzione / Translation: Nomi persistenti delle interfacce di rete Wi-Fi
# ------------------------------------------------------
read_wifi_mac_addresses() {
    MAC_WLAN0=$(cat /sys/class/net/wlan0/address 2>/dev/null)
    MAC_WLAN1=$(cat /sys/class/net/wlan1/address 2>/dev/null)

    [[ -n "$MAC_WLAN0" && -n "$MAC_WLAN1" ]]
}


create_persistent_net_names_rule() {
    [ -f "$SERVICE_FILE_UDEV" ] && return

    if ! read_wifi_mac_addresses; then
        pdw_echo "MAC WiFi non disponibili → rimando al prossimo boot"
        NEED_REBOOT=1
        return
    fi

    sudo tee "$SERVICE_FILE_UDEV" > /dev/null <<END_SCRIPT
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$MAC_WLAN0", NAME="wlan0"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$MAC_WLAN1", NAME="wlan1"
END_SCRIPT

    NEED_REBOOT=1
}


# ------------------------------------------------------
# Overlay e parametri kernel
# Traduzione / Translation: Kernel overlays and parameters
# ------------------------------------------------------
ensure_add_necessary_overlay() {
    local CONFIG="/boot/firmware/config.txt"
    declare -a REQUIRED_LINES=(
        "dtoverlay=disable-wifi"
        "usb_max_current_enable=1"
        "dtoverlay=pcie-32bit-dma-pi5"
        "dtparam=pciex1_gen=3"
    )

    for LINE in "${REQUIRED_LINES[@]}"; do
        if ! grep -qx "$LINE" "$CONFIG"; then
            echo "$LINE" | sudo tee -a "$CONFIG" > /dev/null
            NEED_REBOOT=1
        fi
    done
}


ensure_overclock_settings() {
    local CONFIG="/boot/firmware/config.txt"
    local LINE KEY
    # Profilo corrente. Un valore già impostato dall'amministratore prevale:
    # non aggiungere righe duplicate che annullino una riduzione dell'overclock.
    # Traduzione / Translation: Current profile: values already set by the administrator take precedence. Do not append duplicate keys
    # IT/EN: that undo a reduced overclock.
    local OC_LINES=(
        "over_voltage_delta=50000"
        "arm_freq=2800"
        "gpu_freq=900"
    )
    for LINE in "${OC_LINES[@]}"; do
        KEY="${LINE%%=*}"
        if grep -Eq "^[[:space:]]*${KEY}[[:space:]]*=" "$CONFIG"; then
            pdw_echo "$KEY già configurato: mantengo il valore esistente."
        else
            echo "$LINE" | sudo tee -a "$CONFIG" > /dev/null
            NEED_REBOOT=1
        fi
    done
}

# ------------------------------------------------------
# IRQ affinity + threaded NAPI (pi-router)
# Sgrava CPU0: SSD UAS -> CPU3, eth0/audio -> CPU2, WiFi -> CPU1.
# NB: gli MSI del controller PCIe brcmstb NON supportano il cambio di
# affinity (mt7915e resta su CPU0 come hard-IRQ): il processing dei
# pacchetti WiFi migra su CPU1 via threaded NAPI + RPS.
# Traduzione / Translation: IRQ affinity and threaded NAPI: move SSD UAS to CPU3, Ethernet/audio to CPU2 and Wi-Fi processing to
# IT/EN: CPU1. brcmstb PCIe MSI affinity cannot be changed: MT7915E hardware IRQ stays on CPU0, while threaded
# IT/EN: NAPI and RPS move packet processing to CPU1.
# ------------------------------------------------------
ensure_irq_affinity() {
    local SCRIPT_PATH="/usr/local/bin/irq-pin.sh"
    local SERVICE_FILE="/etc/systemd/system/irq-affinity.service"
    local UPDATED=0

    # ── 1. Script (crea se manca O se versione obsoleta) ─────────────────────
    # Traduzione / Translation: 1. Create the script when missing or outdated
    if [ ! -f "$SCRIPT_PATH" ] || ! grep -q "SCRIPT_VERSION=1" "$SCRIPT_PATH"; then
        sudo tee "$SCRIPT_PATH" > /dev/null <<'END_SCRIPT'
#!/bin/bash
# SCRIPT_VERSION=1
# IRQ affinity pi-router -- mask: 1=CPU0 2=CPU1 4=CPU2 8=CPU3
# Layout: CPU0 sistema | CPU1 WiFi (NAPI) | CPU2 eth0+audio | CPU3 SSD UAS.
# I numeri IRQ cambiano tra boot: risoluzione per nome da /proc/interrupts.
# Traduzione / Translation: Script version marker. IRQ masks: 1=CPU0, 2=CPU1, 4=CPU2, 8=CPU3. CPU0 handles the system, CPU1
# IT/EN: Wi-Fi/NAPI, CPU2 Ethernet/audio, CPU3 SSD UAS. IRQ numbers change across boots and are resolved by
# IT/EN: name from /proc/interrupts.

set_affinity() {
    local pattern="$1" mask="$2"
    local irq
    for irq in $(grep "$pattern" /proc/interrupts | awk -F: '{print $1}' | tr -d ' '); do
        echo "$mask" > "/proc/irq/$irq/smp_affinity" 2>/dev/null && \
            pdw_echo "IRQ $irq ($pattern) -> mask $mask"
    done
}

set_affinity "xhci-hcd:usb1" 8   # SSD UAS (Bus 002)      -> CPU3 | IT/EN: SSD UAS, bus 002, CPU3
set_affinity "xhci-hcd:usb3" 4   # audio/HID (Bus 003/4)  -> CPU2 | IT/EN: Audio/HID, bus 003/4, CPU2
set_affinity "eth0"          4   # ethernet               -> CPU2 | IT/EN: Ethernet, CPU2

# mt7915e: affinity MSI non supportata (brcmstb) -> threaded NAPI su CPU1.
# Traduzione / Translation: mt7915e MSI affinity is unsupported by brcmstb; use threaded NAPI on CPU1
for iface in wlan0 wlan1; do
    [ -e "/sys/class/net/$iface" ] || continue
    echo 1 > "/sys/class/net/$iface/threaded" 2>/dev/null
    # RPS di riserva per il path non-NAPI (mask 2 = CPU1)
    # Traduzione / Translation: Fallback RPS for the non-NAPI path, mask 2 = CPU1
    for q in /sys/class/net/$iface/queues/rx-*/rps_cpus; do
        echo 2 > "$q" 2>/dev/null
    done
done
sleep 1
for pid in $(pgrep -f '^napi/wlan'); do
    taskset -pc 1 "$pid" >/dev/null 2>&1 && pdw_echo "napi pid $pid -> CPU1"
done

exit 0
END_SCRIPT
        sudo chmod +x "$SCRIPT_PATH"
        pdw_echo "  ✔ irq-pin.sh v1 installato/aggiornato."
        UPDATED=1
    else
        pdw_echo "irq-pin.sh v1 già presente, salto."
    fi

    # ── 2. Servizio systemd ───────────────────────────────────────────────────
    # Traduzione / Translation: 2. Systemd service
    if [ ! -f "$SERVICE_FILE" ] || ! grep -q "UNIT_VERSION=1" "$SERVICE_FILE"; then
        sudo tee "$SERVICE_FILE" > /dev/null <<'END_SVC'
[Unit]
# UNIT_VERSION=1
# Traduzione / Translation: UNIT_VERSION=1
Description=IRQ affinity pinning (CPU0 sistema, CPU1 WiFi, CPU2 eth0, CPU3 SSD)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/irq-pin.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
END_SVC
        pdw_echo "  ✔ Servizio irq-affinity creato/aggiornato (UNIT_VERSION=1)."
        UPDATED=1
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable irq-affinity.service 2>/dev/null

    if [ "$UPDATED" -eq 1 ]; then
        sudo systemctl restart irq-affinity.service 2>/dev/null
        pdw_echo "  ✔ irq-affinity applicato."
    else
        sudo systemctl start irq-affinity.service 2>/dev/null
    fi
}

#======================================================================
# FASE 2 - RETE (locale pi-router)
# rfkill, disabilitazione servizi, /etc/hosts, avahi reflector.
# NB: check_avahi_reflector viene ESEGUITO per ultimo (vedi ESECUZIONE):
# agisce sui container gia' avviati dalle fasi precedenti.
# Traduzione / Translation: PHASE 2: LOCAL NETWORK — rfkill, service management, host naming and Avahi reflector.
# IT/EN: check_avahi_reflector runs last; the original note refers to services prepared in earlier phases.
#======================================================================


# ------------------------------------------------------
# Network
# Traduzione / Translation: Rete
# ------------------------------------------------------
unblock_wifi() {
    sudo rfkill unblock all
}


disable_network_services() {
    sudo systemctl stop wpa_supplicant 2>/dev/null
    sudo systemctl disable wpa_supplicant 2>/dev/null

    if [ ! -f "/etc/NetworkManager/conf.d/99-ignore-wifi.conf" ]; then
        sudo mkdir -p /etc/NetworkManager/conf.d
        sudo tee "/etc/NetworkManager/conf.d/99-ignore-wifi.conf" > /dev/null <<'END_SCRIPT'
[keyfile]
unmanaged-devices=interface-name:wlan*;interface-name:tailscale*;interface-name:br-*
END_SCRIPT
        sudo systemctl restart NetworkManager
    fi

    sudo systemctl enable NetworkManager
}


# ------------------------------------------------------
# /etc/hosts
# Traduzione / Translation: File /etc/hosts
# ------------------------------------------------------


# ------------------------------------------------------
# Avahi reflector e interfacce
# Traduzione / Translation: Avahi reflector and interfaces
# ------------------------------------------------------
check_avahi_reflector() {
    local HOSTS=("localhost")
    declare -A INTERFACES_MAP
    INTERFACES_MAP["localhost"]="br0,eth0"

    local CONFIG_SCRIPT='
CONF="/etc/avahi/avahi-daemon.conf"
. "$2/config/i18n.sh"
INTERFACES="$1"


_sudo() { sudo "$@"; }

pdw_echo "Configurazione Avahi su $(hostname) per interfacce: $INTERFACES"

if ! command -v avahi-daemon >/dev/null 2>&1; then
    _sudo apt-get update -q && _sudo apt-get install -y avahi-daemon || { pdw_echo "ERRORE: impossibile installare avahi-daemon"; exit 1; }
fi

[ -f "$CONF" ] || { pdw_echo "ERRORE: $CONF non trovato"; exit 1; }

# --- Rimuovi publish-addresses da [server] se presente (chiave non valida) ---
# Traduzione / Translation: Remove publish-addresses from [server] if present: it is not a valid key in that section
_sudo sed -i '\"'\"'/^\\[server\\]/,/^\\[/{/^publish-addresses=/d}'\"'\"' "$CONF"

# --- publish-addresses=yes nella sezione [publish] ---
# Traduzione / Translation: Set publish-addresses=yes in [publish]
if grep -q "^\\[publish\\]" "$CONF"; then
    if grep -q "^#*[[:space:]]*publish-addresses=" "$CONF"; then
        _sudo sed -i "s/^#*[[:space:]]*publish-addresses=.*/publish-addresses=yes/" "$CONF"
    else
        _sudo sed -i "/^\\[publish\\]/a publish-addresses=yes" "$CONF"
    fi
else
    printf "\\n[publish]\\npublish-addresses=yes\\n" | _sudo tee -a "$CONF" >/dev/null
fi

# --- allow-interfaces in [server] ---
# Traduzione / Translation: Set allow-interfaces in [server]
if grep -q "^allow-interfaces=" "$CONF"; then
    _sudo sed -i "s/^allow-interfaces=.*/allow-interfaces=$INTERFACES/" "$CONF"
else
    _sudo sed -i "/^\\[server\\]/a allow-interfaces=$INTERFACES" "$CONF"
fi

# --- enable-reflector in [reflector] ---
# Traduzione / Translation: Set enable-reflector in [reflector]
if grep -q "^\\[reflector\\]" "$CONF"; then
    _sudo sed -i "s/^#*[[:space:]]*enable-reflector[[:space:]]*=.*/enable-reflector=yes/" "$CONF"
else
    printf "\\n[reflector]\\nenable-reflector=yes\\n" | _sudo tee -a "$CONF" >/dev/null
fi

pdw_echo "Configurazione scritta. Riavvio avahi-daemon..."
if _sudo systemctl restart avahi-daemon; then
    pdw_echo "Configurazione completata su $(hostname)"
else
    pdw_echo "WARN: avahi-daemon restart fallito su $(hostname)"
    _sudo journalctl -u avahi-daemon --no-pager -n 5 2>/dev/null
fi
'

    for HOST in "${HOSTS[@]}"; do
        local IFACES="${INTERFACES_MAP[$HOST]}"
        pdw_echo "Configuro Avahi reflector su $HOST (interfacce: $IFACES)..."

        if [[ "$HOST" == "localhost" ]]; then
            if bash -s -- "$IFACES" "$PROJECT_DIR" <<< "$CONFIG_SCRIPT"; then
                pdw_echo "  ✔ Configurazione riuscita su localhost."
            else
                pdw_echo "  ✖ WARN: configurazione fallita su localhost."
            fi
        fi
    done
}


if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ensure_packages
    create_persistent_net_names_rule
    ensure_add_necessary_overlay
    ensure_overclock_settings
    ensure_irq_affinity
    unblock_wifi
    disable_network_services
    check_avahi_reflector
    if [ "$NEED_REBOOT" -eq 1 ]; then
        pdw_echo "Reboot necessario per applicare le modifiche al kernel."
        sudo reboot
    fi
fi
