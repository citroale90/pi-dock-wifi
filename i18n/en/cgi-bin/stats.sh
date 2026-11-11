#!/bin/bash
# Read each wireless snapshot and the DHCP leases once per response.
# Traduzione / Translation: Legge una sola volta per risposta ogni istantanea radio e i lease DHCP
export LC_ALL=C
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
umask 077
. "${CGI_ENV_FILE:-/etc/cgi-env.sh}"
: "${AP_INTERFACE1:?Missing AP_INTERFACE1}"
: "${INTERNET:?Missing INTERNET}"
AP_INTERFACE2=${AP_INTERFACE2:-}

cpu_cached() {
    local value=0
    [[ ! -r /tmp/cpu_usage_cache ]] || read -r value </tmp/cpu_usage_cache
    [[ "$value" =~ ^[0-9]+$ && "$value" -le 100 ]] || value=0
    printf '%s' "$value"
}
get_cpu() {
    local label cpu_user cpu_nice cpu_sys cpu_idle cpu_io cpu_irq cpu_soft cpu_steal rest
    local total previous_total previous_idle previous_time now delta busy value temp
    exec 201>/tmp/.cpu_calc_lock || { cpu_cached; return; }
    flock -w 2 201 || { cpu_cached; return; }
    read -r label cpu_user cpu_nice cpu_sys cpu_idle cpu_io cpu_irq cpu_soft cpu_steal rest </proc/stat
    total=$((cpu_user + cpu_nice + cpu_sys + cpu_idle + cpu_io + cpu_irq + cpu_soft + cpu_steal))
    read -r now rest </proc/uptime; now=${now%.*}
    value=$(cpu_cached)
    if [[ -r /tmp/cpu_usage_state ]]; then
        read -r previous_total previous_idle previous_time </tmp/cpu_usage_state
        if [[ "$previous_total $previous_idle $previous_time" =~ ^[0-9]+\ [0-9]+\ [0-9]+$ ]]; then
            (( now > previous_time )) || { printf '%s' "$value"; return; }
            delta=$((total - previous_total))
            busy=$((delta - cpu_idle + previous_idle))
            if (( delta > 0 && busy >= 0 && busy <= delta )); then value=$((busy * 100 / delta)); fi
        fi
    fi
    temp=$(mktemp /tmp/cpu_usage_state.XXXXXX) || { printf '%s' "$value"; return; }
    printf '%s %s %s\n' "$total" "$cpu_idle" "$now" >"$temp"
    mv -f "$temp" /tmp/cpu_usage_state
    temp=$(mktemp /tmp/cpu_usage_cache.XXXXXX) || { printf '%s' "$value"; return; }
    printf '%s\n' "$value" >"$temp"; mv -f "$temp" /tmp/cpu_usage_cache
    printf '%s' "$value"
}
get_bytes() {
    local value=0 path="/sys/class/net/$1/statistics/${2}_bytes"
    [[ ! -r "$path" ]] || read -r value <"$path"
    [[ "$value" =~ ^[0-9]+$ ]] || value=0
    printf '%s' "$value"
}
get_wifi_temp() {
    local phy file value
    phy=$(readlink -f "/sys/class/net/$1/phy80211" 2>/dev/null)
    if [[ -n "$phy" ]]; then
        for file in "$phy"/hwmon*/temp1_input; do
            [[ -r "$file" ]] || continue
            read -r value <"$file"
            [[ "$value" =~ ^-?[0-9]+$ ]] || continue
            awk -v t="$value" 'BEGIN {printf "%.1f",t/1000}'; return
        done
    fi
    printf null
}

# One shared local resolver for both the live table and the hosts endpoint.
# Traduzione / Translation: La tabella live e l’endpoint hosts usano lo stesso risolutore locale condiviso
IDENTITIES_JSON=$("${CLIENT_IDENTITIES_HELPER:-/opt/pi-dock-wifi-web/client-identities.sh}") || IDENTITIES_JSON='[]'
wifi='{}'; clients='{}'
for iface in "$AP_INTERFACE1" "$AP_INTERFACE2"; do
    [[ -n "$iface" ]] || continue
    info=$(iw dev "$iface" info 2>/dev/null)
    stations=$(iw dev "$iface" station dump 2>/dev/null)
    ssid=$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*ssid[[:space:]]\+//p')
    channel=$(printf '%s\n' "$info" | awk '$1=="channel" {print $2;exit}')
    width=$(printf '%s\n' "$info" | sed -n 's/.*width: \([0-9]*\).*/\1/p')
    freq=$(printf '%s\n' "$info" | awk '$1=="channel" {gsub(/[^0-9]/,"",$3);print $3;exit}')
    standard=802.11
    if [[ "$freq" =~ ^[0-9]+$ ]]; then
        if (( freq >= 5000 )); then standard='802.11ac/ax (5GHz)'; elif (( freq >= 2400 )); then standard='802.11n/ax (2.4GHz)'; fi
    fi
    records=$(printf '%s\n' "$stations" | awk '
        $1=="Station" {m=tolower($2);order[++n]=m;next}
        $1=="signal:" {signal[m]=$2}
        END {for(i=1;i<=n;i++){m=order[i];r=signal[m];if(r!~/^-?[0-9]+$/)r=-999;
            printf "%s\t%s\n",m,r}}')
    list=$(printf '%s' "$records" | jq -Rsc --argjson known "$IDENTITIES_JSON" '
        ($known|map({key:.mac,value:.})|from_entries) as $names |
        split("\n")|map(select(length>0)|split("\t")|
            . as $row | ($names[$row[0]]//{mac:$row[0],ip:"",hostname:"",ip_source:"none",ip_confirmed:false,hostname_source:"none"}) +
            {rssi:($row[1]|tonumber)})')
    count=$(printf '%s' "$list" | jq length)
    deny="/etc/hostapd/$iface.deny"
    if [[ ! -f "$deny" ]]; then
        if [[ "$iface" == "$AP_INTERFACE1" ]]; then deny=/etc/hostapd/4w.deny; else deny=/etc/hostapd/6w.deny; fi
    fi
    deny_count=0
    [[ ! -r "$deny" ]] || deny_count=$(grep -cvE '^[[:space:]]*$|^[[:space:]]*#' "$deny" 2>/dev/null)
    wifi=$(jq -nc --argjson old "$wifi" --arg iface "$iface" --argjson rx "$(get_bytes "$iface" rx)" --argjson tx "$(get_bytes "$iface" tx)" \
        --arg ssid "${ssid:-n/d}" --argjson count "$count" --argjson temp "$(get_wifi_temp "$iface")" \
        --arg channel "${channel:-n/d}" --arg width "${width:-n/d}" --arg standard "$standard" --argjson deny_count "${deny_count:-0}" \
        '$old+{($iface):{rx:$rx,tx:$tx,info:{ssid:$ssid,client_count:$count},temp:$temp,hostapd:{channel:$channel,width:$width,standard:$standard,deny_count:$deny_count}}}')
    clients=$(jq -nc --argjson old "$clients" --arg iface "$iface" --argjson list "$list" '$old+{($iface):$list}')
done

read -r uptime rest </proc/uptime; uptime=${uptime%.*}
formatted="$((uptime/86400))g $((uptime%86400/3600))h $((uptime%3600/60))min"
ram=$(free | awk '/Mem:/ {if($2>0)printf "%.1f",$3/$2*100;else print 0}')
temp_raw=0
[[ ! -r /sys/class/thermal/thermal_zone0/temp ]] || read -r temp_raw </sys/class/thermal/thermal_zone0/temp
[[ "$temp_raw" =~ ^[0-9]+$ ]] || temp_raw=0
temp=$(awk -v t="$temp_raw" 'BEGIN {printf "%.1f",t/1000}')
jq -nc --arg uptime "$formatted" --argjson cpu "$(get_cpu)" --argjson ram "${ram:-0}" --argjson temp "$temp" \
    --argjson wifi "$wifi" --argjson clients "$clients" '{uptime:$uptime,cpu:$cpu,ram:$ram,temp:$temp,wifi:$wifi,clients:$clients}'
