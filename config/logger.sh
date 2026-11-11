#!/bin/bash
# logger.sh - Log su file + /tmp/log.tmp per la dashboard + stdout per docker logs
# Rotazione in-place per entrambi i file senza cambiare inode
# Traduzione / Translation: logger.sh: file log, /tmp/log.tmp for the dashboard and stdout for docker logs. Rotate files in place
# IT/EN: without changing their inodes.
#
# USO:
#   . /bin/logger.sh              → importa log(), echod(), rotate_logs(), rotate_logs_loop()
#   log "[INFO] messaggio"        → scrive su LOG_FILE + TMP_LOG_FILE + stdout
# Traduzione / Translation: USAGE: source /bin/logger.sh to import log, echod and rotation helpers. log writes the message to the
# IT/EN: main log, temporary dashboard log and stdout.
#
# Tutti gli script (entrypoint, dnsmasq_start.sh, monitor_ip.sh, ecc.)
# devono fare solo ". /bin/logger.sh" — nient'altro.
# Traduzione / Translation: Scripts such as entrypoint, dnsmasq_start and monitor_ip only need to source /bin/logger.sh

. "${BASH_SOURCE[0]%/*}/i18n.sh"

DEFAULT_LOG_FILE="/var/log/pi-dock-wifi.log"
DEFAULT_MAX_LINES=1000

: "${LOG_FILE:=$DEFAULT_LOG_FILE}"
export LOG_FILE

: "${MAX_LOG_LINES:=$DEFAULT_MAX_LINES}"

TMP_LOG_FILE="/tmp/log.tmp"

# Leggi subito ogni riga: awk con input su pipe può attendere un blocco intero
# e assegnare lo stesso orario a eventi accaduti molto prima.
# Traduzione / Translation: Read each line immediately: awk reading a pipe may wait for a whole block and incorrectly timestamp
# IT/EN: much older events together
timestamp_raw_stream() {
    if command -v mawk >/dev/null 2>&1; then
        mawk -W interactive '{ print strftime("[%d-%m-%Y %H:%M:%S]", systime()), $0; fflush(); }'
    else
        local line
        while IFS= read -r line || [[ -n "$line" ]]; do
            printf '[%(%d-%m-%Y %H:%M:%S)T] %s\n' -1 "$line"
        done
    fi
}

# --- Funzione di rotazione in-place (mantiene inode) ---
# Può essere usata anche da altri script per i propri log (es. dnsmasq_raw.log)
# Uso: rotate_logs <file> <max_lines>
# Traduzione / Translation: In-place rotation preserves the inode. Other scripts may use it for their logs, for example
# IT/EN: dnsmasq_raw.log. Usage: rotate_logs FILE MAX_LINES.
_rotate_logs_locked() {
    local file="$1"
    local max_lines="$2"

    if [[ -f "$file" ]]; then
        local line_count
        line_count=$(wc -l < "$file" 2>/dev/null || echo 0)
        if (( line_count > max_lines )); then
            local keep=$(( max_lines * 80 / 100 ))
            local temp
            temp=$(mktemp "${file}.rotate.XXXXXX") || return 1
            if tail -n "$keep" "$file" > "$temp"; then
                cat "$temp" > "$file"
            fi
            rm -f "$temp"
        fi
    fi
}

# All cooperating writers and rotators share the same lock. The helper above
# is called only while holding it, avoiding nested acquisition in log().
# Traduzione / Translation: Scrittori e rotatori cooperanti condividono lo stesso lock. L’helper superiore viene chiamato solo
# IT/EN: mentre il lock è acquisito, evitando acquisizioni annidate in log().
rotate_logs() {
    {
        flock -x 200 || return 1
        _rotate_logs_locked "$@"
    } 200>/tmp/.log_lock
}

# --- [BUG FIX #1/#13] Loop di rotazione continua per log raw ---
# Uso: rotate_logs_loop <file> <max_lines> <interval_seconds>
# Eseguire in background: rotate_logs_loop "$LOG" 15000 60 &
# Traduzione / Translation: Continuous rotation loop for raw logs. Usage: rotate_logs_loop FILE MAX_LINES INTERVAL_SECONDS; run it
# IT/EN: in the background.
rotate_logs_loop() {
    local file="$1"
    local max_lines="$2"
    local interval="${3:-60}"

    local key
    key=$(printf '%s' "$file" | sha256sum) || exit 1
    key=${key%% *}
    {
        flock -n 202 || return 0
        local sleep_pid=
        trap 'if [[ -n "$sleep_pid" ]]; then kill "$sleep_pid" 2>/dev/null || true; wait "$sleep_pid" 2>/dev/null || true; fi; exit 0' TERM INT
        while true; do
            sleep "$interval" &
            sleep_pid=$!
            wait "$sleep_pid" || return 0
            sleep_pid=
            rotate_logs "$file" "$max_lines"
        done
    } 202>"/tmp/.rotate-${key}.lock"
}

# --- log() scrive su LOG_FILE, TMP_LOG_FILE e stdout (docker logs) ---
# Traduzione / Translation: log writes to LOG_FILE, TMP_LOG_FILE and stdout, as seen by docker logs
log() {
    local message="$*"
    pdw_translate "$message"
    message=$PDW_MESSAGE
    local timestamp
    timestamp="$(date '+%d-%m-%Y %H:%M:%S')"
    local formatted="$timestamp - $message"

    # Scrittura atomica con flock: file + file + stdout in un blocco unico
    # Traduzione / Translation: Atomic flock-protected write: both files and stdout are handled in a single block
    {
        flock -x 200 || return 1
        [[ -f "$LOG_FILE" ]] || { touch "$LOG_FILE" && chmod 640 "$LOG_FILE"; }
        [[ -f "$TMP_LOG_FILE" ]] || { touch "$TMP_LOG_FILE" && chmod 644 "$TMP_LOG_FILE"; }
        echo "$formatted" >> "$LOG_FILE"
        echo "$formatted" >> "$TMP_LOG_FILE"
        echo "$formatted"  # stdout → docker logs | IT/EN: stdout per docker logs
        _rotate_logs_locked "$LOG_FILE" "$MAX_LOG_LINES"
        _rotate_logs_locked "$TMP_LOG_FILE" "$MAX_LOG_LINES"
    } 200>/tmp/.log_lock
}

# --- echod scrive solo su stdout (per output non strutturato) ---
# Traduzione / Translation: echod writes only timestamped stdout for unstructured diagnostic output
echod() {
    pdw_translate "$*"
    echo "$(date '+%d-%m-%Y %H:%M:%S') - $PDW_MESSAGE"
}
