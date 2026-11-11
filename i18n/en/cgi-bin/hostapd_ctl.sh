#!/bin/bash
# Persist changes and reconcile hostapd's in-memory ACL without restarting an AP.
# Traduzione / Translation: Salva le modifiche e riconcilia l’ACL in memoria di hostapd senza riavviare l’AP
set -uo pipefail
umask 077
. "${CGI_ENV_FILE:-/etc/cgi-env.sh}"
: "${AP_INTERFACE1:?}" "${AP_INTERFACE2:?}"
ROOT=${HOSTAPD_CONFIG_DIR:-/etc/hostapd}
CLI=${HOSTAPD_CLI:-hostapd_cli}
exec 200>"${HOSTAPD_LOCK_FILE:-/tmp/hostapd_ctl.lock}"
flock -x 200
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
fail() { jq -nc --arg error "$1" '{success:false,error:$error}'; exit 0; }
valid_mac() { [[ "$1" =~ ^([a-f0-9]{2}:){5}[a-f0-9]{2}$ ]]; }
select_iface() {
    case "$1" in
        "$AP_INTERFACE1") stem=46w; deny="$ROOT/4w.deny" ;;
        "$AP_INTERFACE2") stem=56w; deny="$ROOT/6w.deny" ;;
        *) return 1 ;;
    esac
    [[ ! -f "$ROOT/$1.deny" ]] || deny="$ROOT/$1.deny"
    iface=$1
    conf="$ROOT/hostapd_$stem.conf"
    tmpl="$conf.template"
    [[ -f "$deny" && -f "$conf" && -f "$tmpl" ]]
}
read_list() {
    local line mac
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=${line%%#*}
        read -r mac _ <<< "$line"
        [[ -z "$mac" ]] && continue
        mac=${mac,,}
        valid_mac "$mac" || return 1
        printf '%s\n' "$mac"
    done < "$1" | sort -u
}
runtime_list() {
    local output line mac
    output=$("$CLI" -i "$iface" deny_acl SHOW 2>/dev/null) || return 1
    [[ "$output" != *FAIL* && "$output" != *'Could not'* && "$output" != *UNKNOWN* ]] || return 1
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == 'Selected interface '* ]] && continue
        read -r mac _ <<< "$line"
        mac=${mac,,}
        valid_mac "$mac" || return 1
        printf '%s\n' "$mac"
    done <<< "$output" | sort -u
}
cli_ok() {
    local response
    response=$("$CLI" -i "$iface" "$@" 2>/dev/null) || return 1
    [[ "$response" == OK ]]
}
configured_enabled() {
    grep -q '^deny_mac_file=' "$conf" && grep -q '^deny_mac_file=' "$tmpl"
}
sync_acl() {
    local desired=$1 current mac
    current=$(runtime_list) || return 1
    # Add first so previously blocked devices never become temporarily allowed.
    # Traduzione / Translation: Aggiunge prima i blocchi: i dispositivi già bloccati non diventano temporaneamente autorizzati
    while IFS= read -r mac; do
        [[ -z "$mac" ]] && continue
        grep -qxF "$mac" <<< "$current" || cli_ok deny_acl ADD_MAC "$mac" || return 1
    done <<< "$desired"
    while IFS= read -r mac; do
        [[ -z "$mac" ]] && continue
        grep -qxF "$mac" <<< "$desired" || cli_ok deny_acl DEL_MAC "$mac" || return 1
    done <<< "$current"
    current=$(runtime_list) || return 1
    [[ "$current" == "$desired" ]]
}
write_config() {
    local file=$1 enabled=$2
    sed '/^[[:space:]#]*macaddr_acl=/d; /^[[:space:]#]*deny_mac_file=/d' "$file" > "$tx/new" || return 1
    printf '\nmacaddr_acl=0\n' >> "$tx/new"
    [[ "$enabled" == false ]] || printf 'deny_mac_file=%s\n' "$deny" >> "$tx/new"
    # Preserve inode: templates are individual bind mounts.
    # Traduzione / Translation: Conserva l’inode: i template sono bind mount di singoli file
    cat "$tx/new" > "$file" && chmod 600 "$file"
}
json_list() { if [[ -n "$1" ]]; then printf '%s\n' "$1" | jq -R . | jq -s .; else printf '[]'; fi; }
decode() { local s=${1//+/ }; [[ "$s" != *\\* ]] || return 1; printf '%b' "${s//%/\\x}"; }
if [[ "${REQUEST_METHOD:-GET}" == POST ]]; then
    [[ "${CONTENT_LENGTH:-}" =~ ^[0-9]+$ && "$CONTENT_LENGTH" -le 4096 ]] || fail 'Invalid request'
    post=''; IFS= read -r -N "$CONTENT_LENGTH" post || true
    action=''; iface=''; mac=''
    IFS='&' read -ra fields <<< "$post"
    for field in "${fields[@]}"; do
        key=${field%%=*}; value=$(decode "${field#*=}") || fail 'Invalid parameter'
        case "$key" in action) action=$value ;; iface) iface=$value ;; mac) mac=${value,,} ;; esac
    done
    if [[ "$action" == restart_container ]]; then
        printf '{"success":true,"message":"Container restarting..."}\n'
        (sleep 1; kill 1) >/dev/null 2>&1 &
        exit 0
    fi
    case "$action" in add_deny|remove_deny|enable_deny|disable_deny) ;; *) fail 'Unrecognized action' ;; esac
    select_iface "$iface" || fail 'Invalid interface or configuration'
    [[ "$action" != add_deny && "$action" != remove_deny ]] || valid_mac "$mac" || fail 'Invalid MAC format'
    old_list=$(read_list "$deny") || fail 'Invalid deny list'
    old_acl=$(runtime_list) || fail 'hostapd unreachable'
    enabled=false; configured_enabled && enabled=true
    new_list=$old_list
    case "$action" in
        add_deny)
            grep -qxF "$mac" <<< "$old_list" && fail 'MAC is already in the deny list'
            new_list=$(printf '%s\n%s\n' "$old_list" "$mac" | sed '/^$/d' | sort -u)
            ;;
        remove_deny) new_list=$(printf '%s\n' "$old_list" | sed "/^$mac$/d; /^$/d") ;;
        enable_deny) enabled=true ;;
        disable_deny) enabled=false ;;
    esac
    tx=$(mktemp -d /tmp/hostapd-transaction.XXXXXX) || fail 'Cannot prepare the change'
    cp "$deny" "$tx/deny" && cp "$conf" "$tx/conf" && cp "$tmpl" "$tx/tmpl" || { rm -rf "$tx"; fail 'Cannot save the configuration'; }
    committed=false
    rollback() {
        local failed=false
        if [[ "$committed" == false ]]; then
            cat "$tx/deny" > "$deny" || failed=true
            cat "$tx/conf" > "$conf" || failed=true
            cat "$tx/tmpl" > "$tmpl" || failed=true
            sync_acl "$old_acl" || failed=true
            [[ "$failed" == false ]] || printf 'hostapd_ctl: ripristino incompleto su %s\n' "$iface" >&2
        fi
        rm -rf "$tx"
    }
    trap rollback EXIT
    trap 'exit 1' TERM INT HUP
    desired=''; [[ "$enabled" == false ]] || desired=$new_list
    sync_acl "$desired" || fail 'Hostapd update failed; restoring previous settings'
    if [[ -n "$new_list" ]]; then printf '%s\n' "$new_list" > "$deny"; else : > "$deny"; fi
    [[ $? == 0 ]] && chmod 600 "$deny" && write_config "$conf" "$enabled" && write_config "$tmpl" "$enabled" || fail 'Save failed; restoring previous settings'
    committed=true
    jq -nc --arg action "$action" --arg mac "$mac" --argjson enabled "$enabled" '{success:true,message:(if $action=="enable_deny" then "Deny list enabled and applied" elif $action=="disable_deny" then "Deny list disabled and applied" elif $action=="add_deny" then ($mac+" added"+(if $enabled then " and blocked" else " to the disabled list" end)) else ($mac+" removed") end)}'
    exit 0
fi
[[ "${REQUEST_METHOD:-GET}" == GET ]] || fail 'Method not allowed'
result='{}'
for ap in "$AP_INTERFACE1" "$AP_INTERFACE2"; do
    select_iface "$ap" || fail 'Hostapd configuration is missing'
    list=$(read_list "$deny") || fail 'Invalid deny list'
    enabled=false; configured_enabled && enabled=true
    desired=''; [[ "$enabled" == false ]] || desired=$list
    synchronized=false
    live=$(runtime_list) && [[ "$live" == "$desired" ]] && synchronized=true
    result=$(jq -nc --argjson r "$result" --arg iface "$ap" --arg file "$deny" --argjson list "$(json_list "$list")" --argjson enabled "$enabled" --argjson synced "$synchronized" '$r + {($iface):{deny_file:$file,deny_list:$list,deny_enabled:$enabled,acl_synchronized:$synced}}')
done
jq -nc --argjson interfaces "$result" '{interfaces:$interfaces}'
