#!/bin/bash
echo "Content-type: application/json"
echo ""

. /etc/cgi-env.sh 2>/dev/null || true

# Configurazione Pi-hole (network_mode: host => localhost)
# Traduzione / Translation: Pi-hole configuration; host networking uses localhost
PIHOLE_HOST="${PIHOLE_HOST:-127.0.0.1}"
PIHOLE_PORT="${PIHOLE_PORT:-8090}"
PIHOLE_PASSWORD="${PIHOLE_PASSWORD:?Set PIHOLE_PASSWORD}"
PIHOLE_URL="http://${PIHOLE_HOST}:${PIHOLE_PORT}"

# Funzione per fare logout e liberare il seat API
# Traduzione / Translation: Log out and release the API session slot
pihole_logout() {
    if [ -n "$SID" ]; then
        curl -s --connect-timeout 2 --max-time 3 \
            -X DELETE -H "sid: ${SID}" \
            "${PIHOLE_URL}/api/auth" >/dev/null 2>&1
    fi
}

# Trap per garantire logout anche in caso di errore
# Traduzione / Translation: Ensure logout even when an error occurs
trap pihole_logout EXIT

# --- Pi-hole v6 API ---
# Step 1: Login per ottenere il SID
# Traduzione / Translation: Pi-hole v6 API: step 1, sign in to obtain the SID
LOGIN_RESP=$(curl -s --connect-timeout 3 --max-time 5 \
    -X POST -H "Content-Type: application/json" \
    -d "$(jq -nc --arg password "$PIHOLE_PASSWORD" '{password:$password}')" \
    "${PIHOLE_URL}/api/auth" 2>/dev/null)

SID=""
if [ -n "$LOGIN_RESP" ]; then
    SID=$(echo "$LOGIN_RESP" | jq -r '.session.sid // empty' 2>/dev/null)
fi

# Step 2: Fetch stats con il SID
# Traduzione / Translation: Step 2: fetch statistics using the SID
if [ -n "$SID" ]; then
    SUMMARY=$(curl -s --connect-timeout 3 --max-time 5 \
        -H "sid: ${SID}" \
        "${PIHOLE_URL}/api/stats/summary" 2>/dev/null)

    if [ -n "$SUMMARY" ] && echo "$SUMMARY" | jq -e '.queries' >/dev/null 2>&1; then
        QUERIES=$(echo "$SUMMARY" | jq -r '.queries.total // 0')
        BLOCKED=$(echo "$SUMMARY" | jq -r '.queries.blocked // 0')
        PERCENT=$(echo "$SUMMARY" | jq -r '.queries.percent_blocked // 0')
        DOMAINS=$(echo "$SUMMARY" | jq -r '.gravity.domains_being_blocked // 0')

        # Top blocked domains
        # Traduzione / Translation: Domini bloccati più frequentemente
        TOP_BLOCKED=$(curl -s --connect-timeout 3 --max-time 5 \
            -H "sid: ${SID}" \
            "${PIHOLE_URL}/api/stats/top_blocked?count=5" 2>/dev/null)

        TOP_ADS="{}"
        if [ -n "$TOP_BLOCKED" ]; then
            TOP_ADS=$(echo "$TOP_BLOCKED" | jq '[.top_blocked[]? | {(.domain): .count}] | add // {}' 2>/dev/null || echo '{}')
        fi

        # Logout prima di stampare (trap EXIT lo fa comunque, ma meglio essere espliciti)
        # Traduzione / Translation: Log out before printing; the EXIT trap also does this, but the explicit call documents the intent
        pihole_logout
        SID=""

        printf '{"status":"online","dns_queries_today":%s,"ads_blocked_today":%s,"ads_percentage_today":%s,"domains_being_blocked":%s,"top_ads":%s}' \
            "$QUERIES" "$BLOCKED" "$PERCENT" "$DOMAINS" "$TOP_ADS"
        exit 0
    fi
fi

# Fallback: prova senza auth (Pi-hole senza password)
# Traduzione / Translation: Fallback: try without authentication for passwordless Pi-hole
SUMMARY=$(curl -s --connect-timeout 3 --max-time 5 \
    "${PIHOLE_URL}/api/stats/summary" 2>/dev/null)

if [ -n "$SUMMARY" ] && echo "$SUMMARY" | jq -e '.queries' >/dev/null 2>&1; then
    QUERIES=$(echo "$SUMMARY" | jq -r '.queries.total // 0')
    BLOCKED=$(echo "$SUMMARY" | jq -r '.queries.blocked // 0')
    PERCENT=$(echo "$SUMMARY" | jq -r '.queries.percent_blocked // 0')
    DOMAINS=$(echo "$SUMMARY" | jq -r '.gravity.domains_being_blocked // 0')
    printf '{"status":"online","dns_queries_today":%s,"ads_blocked_today":%s,"ads_percentage_today":%s,"domains_being_blocked":%s,"top_ads":{}}' \
        "$QUERIES" "$BLOCKED" "$PERCENT" "$DOMAINS"
    exit 0
fi

# Se arriviamo qui, controlla se è un errore di seats
# Traduzione / Translation: If execution reaches this point, check for exhausted API session slots
ERROR_KEY=$(echo "$LOGIN_RESP" | jq -r '.error.key // empty' 2>/dev/null)
if [ "$ERROR_KEY" = "api_seats_exceeded" ]; then
    echo '{"status": "offline", "error": "Too many open Pi-hole API sessions. Wait a few minutes."}'
else
    echo '{"status": "offline", "error": "Pi-hole unreachable"}'
fi
