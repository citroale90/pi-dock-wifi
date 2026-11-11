#!/bin/bash
# Password-only sessions. All state is private to the root CGI process.
# Traduzione / Translation: Sessioni basate sulla password; tutto lo stato è privato al processo CGI root
set -u
umask 077
STATE=${DASHBOARD_STATE_DIR:-/run/pi-dock-wifi}
SESSIONS="$STATE/web-sessions"
TTL=43200
reply() {
    printf 'Status: %s\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n' "$1"
    [[ -z "${2:-}" ]] || printf 'Set-Cookie: %s\r\n' "$2"
    printf '\r\n%s\n' "${3:-}"
    exit 0
}
cookie() {
    local part
    IFS=';' read -ra parts <<< "${HTTP_COOKIE:-}"
    for part in "${parts[@]}"; do
        part="${part#"${part%%[![:space:]]*}"}"
        if [[ "$part" =~ ^pi_router_session=([a-f0-9]{64})$ ]]; then
            printf '%s' "${BASH_REMATCH[1]}"
            return
        fi
    done
}
same_origin() {
    # Debian's fastcgi_params normalizes HTTP_HOST and removes the port.
    # Traduzione / Translation: fastcgi_params di Debian normalizza HTTP_HOST rimuovendo la porta
    [[ -z "${HTTP_ORIGIN:-}" || "${HTTP_ORIGIN}" == "http://${HTTP_HOST:-}" || "${HTTP_ORIGIN}" == "https://${HTTP_HOST:-}" ||
       "${HTTP_ORIGIN}" == "http://${HTTP_HOST:-}:${SERVER_PORT:-}" || "${HTTP_ORIGIN}" == "https://${HTTP_HOST:-}:${SERVER_PORT:-}" ]]
}
token=$(cookie)
[[ -r "$STATE/password.sha256" ]] || reply '503 Service Unavailable' '' '{"error":"Sign-in not configured"}'
read -r expected < "$STATE/password.sha256"
case "${AUTH_ACTION:-}" in
    check)
        [[ -n "$token" && -r "$SESSIONS/$token" ]] || reply '401 Unauthorized'
        read -r expires version < "$SESSIONS/$token"
        [[ "$expires" =~ ^[0-9]+$ && "$expires" -gt "$(date +%s)" && "$version" == "$expected" ]] || reply '401 Unauthorized'
        if [[ "${HTTP_X_ORIGINAL_METHOD:-GET}" == POST ]]; then
            [[ "${HTTP_X_DASHBOARD_REQUEST:-}" == 1 ]] && same_origin || reply '403 Forbidden'
        fi
        if [[ "${HTTP_X_ORIGINAL_URI:-}" == /terminal/ws* ]]; then
            [[ -n "${HTTP_ORIGIN:-}" ]] && same_origin || reply '403 Forbidden'
        fi
        reply '204 No Content'
        ;;
    login|logout)
        [[ "${REQUEST_METHOD:-}" == POST ]] || reply '405 Method Not Allowed'
        [[ "${HTTP_X_DASHBOARD_REQUEST:-}" == 1 ]] && same_origin || reply '403 Forbidden'
        secure=''
        if [[ "${HTTPS:-}" == on || ( -n "${TRUSTED_PROXY_IP:-}" && "${REMOTE_ADDR:-}" == "$TRUSTED_PROXY_IP" && "${HTTP_X_FORWARDED_PROTO:-}" == https ) ]]; then
            secure='; Secure'
        fi
        if [[ "$AUTH_ACTION" == logout ]]; then
            [[ -z "$token" ]] || rm -f -- "$SESSIONS/$token"
            reply '200 OK' "pi_router_session=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0$secure" '{"success":true}'
        fi
        [[ "${CONTENT_LENGTH:-}" =~ ^[0-9]+$ && "${CONTENT_LENGTH}" -gt 0 && "${CONTENT_LENGTH}" -le 4096 ]] || reply '400 Bad Request'
        body=''
        IFS= read -r -N "$CONTENT_LENGTH" body || true
        actual=$(printf '%s' "$body" | jq -erj '.password | select(type == "string" and length > 0 and length <= 1024)' | sha256sum)
        [[ "${actual%% *}" == "$expected" ]] || reply '401 Unauthorized' '' '{"error":"Incorrect password"}'
        mkdir -p "$SESSIONS" || reply '503 Service Unavailable'
        chmod 700 "$SESSIONS"
        find "$SESSIONS" -type f -mmin +720 -delete
        token=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
        [[ "$token" =~ ^[a-f0-9]{64}$ ]] || reply '503 Service Unavailable'
        printf '%s %s\n' "$(( $(date +%s) + TTL ))" "$expected" > "$SESSIONS/$token" || reply '503 Service Unavailable'
        reply '200 OK' "pi_router_session=$token; Path=/; HttpOnly; SameSite=Strict; Max-Age=$TTL$secure" '{"success":true}'
        ;;
    *) reply '404 Not Found' ;;
esac
