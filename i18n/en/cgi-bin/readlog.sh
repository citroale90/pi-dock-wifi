#!/bin/bash
# Authentication remains enforced by nginx. Validators are held only in the UI.
# Traduzione / Translation: L’autenticazione resta applicata da nginx; i validatori sono conservati solo nell’interfaccia
LOG_FILE="${DASHBOARD_LOG_FILE:-/tmp/log.tmp}"
MAX_DISPLAY_LINES=1000
etag=
if [[ -f "$LOG_FILE" ]]; then
    metadata=$(stat -c '%d:%i:%s:%y' "$LOG_FILE" 2>/dev/null)
    if [[ -n "$metadata" ]]; then
        etag=$(printf '%s' "$metadata" | sha256sum); etag='"'${etag%% *}'"'
        if [[ "${HTTP_IF_NONE_MATCH:-}" == "$etag" ]]; then
            printf 'Status: 304 Not Modified\r\nETag: %s\r\nCache-Control: no-store\r\n\r\n' "$etag"
            exit 0
        fi
    fi
fi
printf 'Content-Type: text/plain\r\nCache-Control: no-store\r\n'
[[ -z "$etag" ]] || printf 'ETag: %s\r\n' "$etag"
printf '\r\n'
if [[ -f "$LOG_FILE" ]]; then
    tail -n "$MAX_DISPLAY_LINES" "$LOG_FILE" | tac
else
    printf 'Error: Log file %s has not been generated yet.\n' "$LOG_FILE"
fi
