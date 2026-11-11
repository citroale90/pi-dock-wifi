#!/bin/bash

# Manteniamo le dipendenze richieste per l'ambiente Docker
# Traduzione / Translation: Keep the dependencies required by the Docker environment
. /bin/logger.sh

# Variabili di configurazione
# Traduzione / Translation: Configuration variables
CONFIG_FILE="/etc/nsswitch.conf"
TARGET_LINE="hosts:          files mdns4_minimal [NOTFOUND=return] dns mdns4"

# Funzione per normalizzare una stringa (rimuove spazi multipli e tabulazioni)
# Traduzione / Translation: Normalize a string by collapsing repeated spaces and tabs
normalize_string() {
    echo "$1" | tr -s '[:space:]' ' ' | sed 's/^ *//;s/ *$//'
}

# Funzione per sostituire la riga "hosts:" in /etc/nsswitch.conf
# Traduzione / Translation: Replace the hosts: line in /etc/nsswitch.conf
replace_hosts_line() {
    # Creiamo un file temporaneo in /tmp (che è quasi sempre scrivibile)
    # Traduzione / Translation: Create a temporary file in /tmp, which is normally writable
    local TEMP_FILE
    TEMP_FILE=$(mktemp /tmp/nsswitch.conf.XXXXXX) || return 1

    # Eseguiamo sed scrivendo l'output nel file temporaneo invece che in-place
    # Traduzione / Translation: Write sed output to the temporary file instead of editing in place
    if {
        if grep -q '^hosts:' "$CONFIG_FILE"; then
            sed "/^hosts:/c\\${TARGET_LINE}" "$CONFIG_FILE"
        else
            cat "$CONFIG_FILE" && printf '\n%s\n' "$TARGET_LINE"
        fi
    } > "$TEMP_FILE"; then
        
        # Sovrascriviamo il contenuto del file originale con quello temporaneo.
        # L'uso di 'cat' mantiene l'inode originale e i permessi del file.
        # Traduzione / Translation: Copy temporary content over the original file using cat to preserve inode and permissions
        if cat "$TEMP_FILE" > "$CONFIG_FILE"; then
            log "[INFO] Riga 'hosts:' sostituita con successo tramite reindirizzamento."
            rm "$TEMP_FILE"
        else
            log "[ERROR] Impossibile sovrascrivere $CONFIG_FILE. Permessi insufficienti o file system RO."
            rm -f "$TEMP_FILE"
            return 1
        fi
        
        # Verifica post-modifica
        # Traduzione / Translation: Post-change verification
        local verify_line=$(grep "^hosts:" "$CONFIG_FILE")
        local norm_verify=$(normalize_string "$verify_line")
        local norm_target=$(normalize_string "$TARGET_LINE")

        if [[ "$norm_verify" == "$norm_target" ]]; then
            log "[INFO] Verifica finale: la configurazione è corretta."
            return 0
        else
            log "[ERROR] La modifica ha avuto esito, ma la verifica finale ha fallito."
            return 1
        fi
    else
        log "[ERROR] Errore durante l'esecuzione di sed sul file temporaneo."
        rm -f "$TEMP_FILE"
        return 1
    fi
}

# Controllo preliminare: verifica che il file esista
# Traduzione / Translation: First verify that the file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "[FATAL] File mancante: $CONFIG_FILE"
    exit 1
fi

# Estrazione della riga attuale
# Traduzione / Translation: Extract the current line
current_line=$(grep "^hosts:" "$CONFIG_FILE" | head -n 1)

if [[ -z "$current_line" ]]; then
    log "[WARN] Riga 'hosts:' assente. Procedendo con l'aggiunta/sostituzione."
    # Se la riga non esiste, forziamo la creazione (caso raro ma possibile)
    # Traduzione / Translation: If the line is absent, create it; uncommon but possible
    replace_hosts_line
    exit $?
fi

# Normalizzazione per un confronto affidabile
# Traduzione / Translation: Normalize for a reliable comparison
norm_current=$(normalize_string "$current_line")
norm_target=$(normalize_string "$TARGET_LINE")

if [[ "$norm_current" == "$norm_target" ]]; then
    log "[INFO] Nsswitch già corretto. Nessuna modifica necessaria."
    exit 0
fi

# Se siamo qui, la configurazione è diversa e serve un aggiornamento
# Traduzione / Translation: The configuration differs, so an update is required
log "[INFO] Nsswitch non è corretto. Sostituendola con la nuova riga."

# Creazione del backup (solo se necessario)
# Traduzione / Translation: Create a backup only when needed
BACKUP_FILE="${CONFIG_FILE}.bak"
if cp "$CONFIG_FILE" "$BACKUP_FILE"; then
    log "[INFO] Backup creato correttamente: $BACKUP_FILE"
else
    log "[ERROR] Impossibile creare il backup. Aborto per sicurezza."
    exit 1
fi

# Esecuzione della sostituzione
# Traduzione / Translation: Apply the replacement
replace_hosts_line
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    pdw_echo "[ERROR] L'aggiornamento è fallito. Il backup è disponibile in $BACKUP_FILE."
    log "[ERROR] Aggiornamento fallito. Ripristino manuale consigliato."
    exit 1
fi

log "[INFO] Configurazione Nsswitch aggiornato e verificato."

