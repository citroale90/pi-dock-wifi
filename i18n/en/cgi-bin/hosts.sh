#!/bin/bash
# Preserve the existing hosts API, using the same resolver as the live table.
# No network name lookups and no separate, inconsistent reservation parser.
# Traduzione / Translation: Conserva l’API hosts usando lo stesso risolutore della tabella live, senza risoluzioni di rete né un
# IT/EN: parser delle prenotazioni separato e incoerente.
printf 'Content-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-store\r\n\r\n'
"${CLIENT_IDENTITIES_HELPER:-/opt/pi-dock-wifi-web/client-identities.sh}" |
    jq '[.[] | select(.ip!="") | {ip,mac,hostname,ip_source,ip_confirmed,hostname_source}]'
