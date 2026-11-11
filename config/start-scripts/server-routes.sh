#!/bin/bash

. /bin/logger.sh

# CONFIGURAZIONE: Solo la rotta originale con separatore ;
# Formato: "RETE,GW"
# Traduzione / Translation: CONFIGURATION: routes use semicolon-separated entries in NETWORK,GATEWAY format
ROUTES="${EXTRA_ROUTES:-}"
BRIDGE=br0
QUIET=false
case "${1:-}" in
    '') ;;
    --quiet) QUIET=true ;;
    *) log "[ERROR] Argomento server-routes non valido"; exit 1 ;;
esac

[[ "$QUIET" == true ]] || log "[INFO] Avvio configurazione routes..."

# Salviamo l'IFS originale
# Traduzione / Translation: Save the original IFS
RESULT=0
OLD_IFS=$IFS
IFS=';'

for entry in $ROUTES; do
    # Estrazione sicura di TARGET e GATEWAY
    # Traduzione / Translation: Safely extract TARGET and GATEWAY
    TARGET=${entry%%,*}
    GATEWAY=${entry##*,}

    # Verifica se la stringa è valida
    # Traduzione / Translation: Validate the entry structure
    if [[ -z "$TARGET" || -z "$GATEWAY" ]]; then
        continue
    fi

    # Controllo se la rotta è già presente e corretta
    # Usiamo 'ip route show TARGET' per una verifica mirata
    # Traduzione / Translation: Check whether the route already exists with the expected gateway and bridge using ip route show exact
    if ip -4 route show exact "$TARGET" 2>/dev/null | awk -v gateway="$GATEWAY" -v bridge="$BRIDGE" '
        {
            via_ok=0; dev_ok=0
            for (i=1; i<NF; i++) {
                if ($i == "via" && $(i+1) == gateway) via_ok=1
                if ($i == "dev" && $(i+1) == bridge) dev_ok=1
            }
            if (via_ok && dev_ok) found=1
        }
        END { exit !found }'; then
        [[ "$QUIET" == true ]] || log "[INFO] OK: $TARGET via $GATEWAY è già configurata."
        continue
    fi
    
    # Replace in one operation: a failed update must leave the old route intact.
    # Traduzione / Translation: Sostituisce la rotta in una sola operazione: un errore deve lasciare intatta la precedente
    if ip -4 route replace "$TARGET" via "$GATEWAY" dev "$BRIDGE"; then
        log "[INFO] Rotta impostata: $TARGET via $GATEWAY"
    else
        log "[ERROR] Impossibile impostare $TARGET via $GATEWAY. Verifica permessi/connettività."
        RESULT=1
    fi
done

# Ripristino dell'ambiente
# Traduzione / Translation: Restore the shell environment
IFS=$OLD_IFS
exit "$RESULT"
