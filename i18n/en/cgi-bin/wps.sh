#!/bin/bash
# WPS a pulsante. Autenticazione e controllo Origin sono gestiti da nginx/auth.sh.
# hostapd chiude la finestra dopo 120 secondi: non servono timer in background.
# Traduzione / Translation: Push-button WPS. nginx/auth.sh enforce authentication and Origin checks; hostapd closes the window
# IT/EN: after 120 seconds, without background timers.
set -uo pipefail
umask 077
. "${CGI_ENV_FILE:-/etc/cgi-env.sh}"

ROOT=${HOSTAPD_CONFIG_DIR:-/etc/hostapd}
CLI=${HOSTAPD_CLI:-hostapd_cli}
STATE=${WPS_STATE_DIR:-/run/pi-dock-wifi/wps}
interfaces=("${AP_INTERFACE1:?}")
[[ -z "${AP_INTERFACE2:-}" ]] || interfaces+=("$AP_INTERFACE2")

reply() {
    printf 'Status: %s\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n\r\n%s\n' "$1" "$2"
    exit 0
}
fail() {
    reply "$1" "$(jq -nc --arg error "$2" '{success:false,error:$error}')"
}
exec 200>"${HOSTAPD_LOCK_FILE:-/tmp/hostapd_ctl.lock}"
flock -w 3 -x 200 || fail '409 Conflict' 'A Wi-Fi operation is in progress. Try again.'

select_interface() {
    local candidate=$1
    [[ "$candidate" =~ ^[a-zA-Z0-9_.:-]{1,15}$ ]] || return 1
    if [[ "$candidate" == "$AP_INTERFACE1" ]]; then
        conf="$ROOT/hostapd_46w.conf"
    elif [[ -n "${AP_INTERFACE2:-}" && "$candidate" == "$AP_INTERFACE2" ]]; then
        conf="$ROOT/hostapd_56w.conf"
    else
        return 1
    fi
    iface=$candidate
    [[ -r "$conf" ]]
}
config_value() {
    awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$conf"
}
cli() {
    timeout 3 "$CLI" -i "$iface" raw "$@" 2>/dev/null
}
cli_ok() {
    local response
    response=$(cli "$@") && [[ "$response" == OK ]]
}
uptime_seconds() {
    awk '{ printf "%.0f\n", int($1) }' /proc/uptime
}

read_status() {
    local output radio started=0 now
    supported=false; ready=false; state=unavailable; last_result=''; remaining=null
    reason='WPS is unavailable on this network.'
    output=$(cli WPS_GET_STATUS) || return 0
    [[ "$output" == *'PBC Status: '* ]] || return 0
    supported=true
    radio=$(timeout 3 "$CLI" -i "$iface" status 2>/dev/null) || radio=''
    state=idle; reason=''
    last_result=$(awk -F': ' '$1 == "Last WPS result" { print $2; exit }' <<< "$output")
    if [[ "$(config_value ignore_broadcast_ssid)" == 1 || "$(config_value ignore_broadcast_ssid)" == 2 ]]; then
        state=disabled; reason='WPS richiede che il nome della rete sia visibile.'
    elif [[ "$(config_value wps_state)" != 2 ]]; then
        state=disabled; reason='WPS is not enabled on this network.'
    elif [[ "$(config_value config_methods)" != virtual_push_button ||
            "$(config_value ap_setup_locked)" != 1 ||
            -n "$(config_value ap_pin)" ||
            "$(config_value wps_independent)" != 0 ]]; then
        state=disabled; reason='This network is not configured for push-button-only WPS.'
    elif ! grep -qx 'state=ENABLED' <<< "$radio"; then
        state=disabled; reason='The Wi-Fi network is not ready.'
    else
        ready=true
    fi
    if grep -qx 'PBC Status: Active' <<< "$output"; then
        state=active
        { read -r started < "$STATE/$iface.started"; } 2>/dev/null || started=0
        if [[ "$started" =~ ^[0-9]{1,10}$ && "$started" != 0 ]]; then
            now=$(uptime_seconds)
            remaining=$(( 120 - (now - 10#$started) ))
            (( remaining < 0 )) && remaining=0
            (( remaining > 120 )) && remaining=120
        fi
    elif grep -qx 'PBC Status: Overlap' <<< "$output"; then
        state=overlap; reason='Più dispositivi richiedono WPS. Cancel e riprova con uno solo.'
    fi
}
status_json() {
    jq -nc --arg state "$state" --arg reason "$reason" --arg result "$last_result" \
        --argjson supported "$supported" --argjson ready "$ready" --argjson seconds "$remaining" \
        '{state:$state,reason:$reason,last_result:$result,supported:$supported,ready:$ready,remaining_seconds:$seconds}'
}

# Ripetere CANCEL è innocuo e copre anche un'eventuale sessione parziale.
# Traduzione / Translation: Repeating CANCEL is harmless and also covers a partially opened session
cancel_sessions() {
    local candidate failed=false
    for candidate in "${interfaces[@]}"; do
        if select_interface "$candidate" && cli_ok WPS_CANCEL; then
            rm -f -- "$STATE/$candidate.started"
        else
            failed=true
        fi
    done
    [[ "$failed" == false ]]
}

case "${REQUEST_METHOD:-GET}" in
    GET)
        result='{}'
        for candidate in "${interfaces[@]}"; do
            select_interface "$candidate" || fail '503 Service Unavailable' 'Wi-Fi configuration unavailable.'
            read_status
            result=$(jq -nc --argjson all "$result" --arg iface "$iface" --argjson status "$(status_json)" '$all + {($iface):$status}')
        done
        reply '200 OK' "$(jq -nc --argjson interfaces "$result" '{success:true,interfaces:$interfaces}')"
        ;;
    POST)
        [[ "${CONTENT_TYPE:-}" == application/x-www-form-urlencoded* &&
           "${CONTENT_LENGTH:-}" =~ ^[1-9][0-9]{0,2}$ && "$CONTENT_LENGTH" -le 128 ]] ||
            fail '400 Bad Request' 'Invalid request.'
        body=''; IFS= read -r -N "$CONTENT_LENGTH" body || true
        [[ ${#body} -eq "$CONTENT_LENGTH" ]] || fail '400 Bad Request' 'Incomplete request.'
        case "$body" in
            action=start) action=start ;;
            action=cancel) action=cancel ;;
            *) fail '400 Bad Request' 'Action or parameters not allowed.' ;;
        esac
        if [[ "$action" == cancel ]]; then
            cancel_sessions || fail '503 Service Unavailable' 'Cannot cancel WPS on both bands.'
            reply '200 OK' '{"success":true,"message":"WPS pairing cancelled on both bands."}'
        fi
        # Il router usa un solo SSID e un solo processo hostapd. Controlliamo
        # entrambe le reti prima di aprire la stessa sessione sulle due radio.
        # Traduzione / Translation: The router uses one SSID and one hostapd process. Check both networks before opening the same pairing
        # IT/EN: session on both radios.
        select_interface "${interfaces[0]}" || fail '503 Service Unavailable' 'Wi-Fi configuration unavailable.'
        declare -A shared
        for key in uuid ssid wpa_passphrase wpa_psk; do
            shared[$key]=$(config_value "$key")
        done
        [[ "${shared[uuid]}" =~ ^[a-f0-9-]{36}$ ]] || fail '409 Conflict' 'Shared WPS identity not configured.'
        for candidate in "${interfaces[@]}"; do
            select_interface "$candidate" || fail '503 Service Unavailable' 'Wi-Fi configuration unavailable.'
            read_status
            [[ "$ready" == true ]] || fail '409 Conflict' "$reason"
            for key in "${!shared[@]}"; do
                [[ "$(config_value "$key")" == "${shared[$key]}" ]] ||
                    fail '409 Conflict' 'The two bands do not share the same Wi-Fi configuration.'
            done
        done
        cancel_sessions || fail '503 Service Unavailable' 'Cannot close the previous WPS session.'
        mkdir -p "$STATE" && chmod 700 "$STATE" || fail '503 Service Unavailable' 'Cannot prepare WPS.'
        started=$(uptime_seconds)
        for candidate in "${interfaces[@]}"; do
            printf '%s\n' "$started" > "$STATE/$candidate.started" ||
                fail '503 Service Unavailable' 'Cannot record the WPS session.'
        done
        select_interface "${interfaces[0]}"
        # wps_independent=0 fa coordinare a hostapd l'apertura, l'annullamento
        # e la conclusione della sessione sulle due bande dello stesso AP.
        # Traduzione / Translation: and completion of the session on both bands of the same AP
        if ! cli_ok WPS_PBC; then
            cancel_sessions || true
            fail '503 Service Unavailable' 'Cannot start WPS. Try again.'
        fi
        for candidate in "${interfaces[@]}"; do
            select_interface "$candidate"
            read_status
            if [[ "$state" != active ]]; then
                cancel_sessions || true
                fail '503 Service Unavailable' 'WPS is not active on both bands. Session cancelled.'
            fi
        done
        reply '200 OK' '{"success":true,"message":"WPS is open on 2.4 and 5 GHz for two minutes. Press the device WPS button."}'

        ;;
    *) fail '405 Method Not Allowed' 'Method not allowed.' ;;
esac
