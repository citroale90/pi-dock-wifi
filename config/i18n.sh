#!/bin/bash
# IT: Catalogo dei messaggi; nessun comando esterno nel percorso di traduzione.
# EN: Message catalogue; no external commands in the translation path.
pdw_translate() {
    PDW_MESSAGE="$*"
    local pdw_regex
    case "${APP_LANGUAGE:-it}" in
        en)
            case "$PDW_MESSAGE" in
                'nessuna risposta ai ping') PDW_MESSAGE='no ping replies' ;;
                'cavo scollegato') PDW_MESSAGE='cable disconnected' ;;
                'interfaccia disattivata') PDW_MESSAGE='interface is down' ;;
                'IP assente') PDW_MESSAGE='no IP address' ;;
                'gateway assente') PDW_MESSAGE='no gateway' ;;
                'interfaccia assente') PDW_MESSAGE='interface missing' ;;
                'interfaccia non configurata') PDW_MESSAGE='interface not configured' ;;
                '[OK] Healthcheck superato.') PDW_MESSAGE='[OK] Health check passed.' ;;
                'APP_LANGUAGE deve essere it oppure en')
                    pdw_regex='^APP_LANGUAGE\ deve\ essere\ it\ oppure\ en$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'APP_LANGUAGE must be it or en'
                    fi
                    ;;
                '[FATAL] Errore alla riga '*': comando "'*'" (exit code '*')')
                    pdw_regex='^\[FATAL\]\ Errore\ alla\ riga\ (.*):\ comando\ "(.*)"\ \(exit\ code\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[FATAL] Error at line %s: command "%s" (exit code %s)' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
                    fi
                    ;;
                '[ERROR] Configurare '*' in .env prima dell'"'"'avvio.')
                    pdw_regex='^\[ERROR\]\ Configurare\ (.*)\ in\ \.env\ prima\ dell'"'"'avvio\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Configure %s in .env before starting.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Configurare WPS_UUID in .env')
                    pdw_regex='^\[ERROR\]\ Configurare\ WPS_UUID\ in\ \.env$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Configure WPS_UUID in .env'
                    fi
                    ;;
                '[ERROR] Variabile d'"'"'ambiente '"'"''*''"'"' non definita.')
                    pdw_regex='^\[ERROR\]\ Variabile\ d'"'"'ambiente\ '"'"'(.*)'"'"'\ non\ definita\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Environment variable '"'"'%s'"'"' is not defined.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Manca la privileged mode.')
                    pdw_regex='^\[ERROR\]\ Manca\ la\ privileged\ mode\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Privileged mode is required.'
                    fi
                    ;;
                '[WARNING] check_nsswitch.sh errore (continuo)')
                    pdw_regex='^\[WARNING\]\ check_nsswitch\.sh\ errore\ \(continuo\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARNING] check_nsswitch.sh failed (continuing)'
                    fi
                    ;;
                '[ERROR] Interfaccia '*' non esiste!')
                    pdw_regex='^\[ERROR\]\ Interfaccia\ (.*)\ non\ esiste!$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Interface %s does not exist!' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] '*' ha un IP.')
                    pdw_regex='^\[INFO\]\ (.*)\ ha\ un\ IP\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] %s has an IP address.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARNING] '*' senza IP. DNS verrà comunque fissato.')
                    pdw_regex='^\[WARNING\]\ (.*)\ senza\ IP\.\ DNS\ verrà\ comunque\ fissato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARNING] %s has no IP address. DNS will still be configured.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] DNS fissato su 192.168.4.1.')
                    pdw_regex='^\[INFO\]\ DNS\ fissato\ su\ 192\.168\.4\.1\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] DNS set to 192.168.4.1.'
                    fi
                    ;;
                '[INFO] '*' già attivo')
                    pdw_regex='^\[INFO\]\ (.*)\ già\ attivo$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] %s is already enabled' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] '*' attivato')
                    pdw_regex='^\[INFO\]\ (.*)\ attivato$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] %s enabled' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] /bin/iptables-rules.sh non trovato')
                    pdw_regex='^\[ERROR\]\ /bin/iptables\-rules\.sh\ non\ trovato$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] /bin/iptables-rules.sh not found'
                    fi
                    ;;
                '[ERROR] Sblocco WiFi fallito')
                    pdw_regex='^\[ERROR\]\ Sblocco\ WiFi\ fallito$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Failed to unblock Wi-Fi'
                    fi
                    ;;
                '[INFO] WiFi sbloccato: '*'')
                    pdw_regex='^\[INFO\]\ WiFi\ sbloccato:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Wi-Fi unblocked: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Nessuna interfaccia WiFi bloccata.')
                    pdw_regex='^\[INFO\]\ Nessuna\ interfaccia\ WiFi\ bloccata\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] No Wi-Fi interfaces are blocked.'
                    fi
                    ;;
                '[INFO] br0 esiste, ricreo...')
                    pdw_regex='^\[INFO\]\ br0\ esiste,\ ricreo\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] br0 exists; recreating it...'
                    fi
                    ;;
                '[ERROR] Creazione br0 fallita')
                    pdw_regex='^\[ERROR\]\ Creazione\ br0\ fallita$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Failed to create br0'
                    fi
                    ;;
                '[INFO] Bridge br0 creato.')
                    pdw_regex='^\[INFO\]\ Bridge\ br0\ creato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Bridge br0 created.'
                    fi
                    ;;
                '[INFO] skip_check presente, salto hostapd')
                    pdw_regex='^\[INFO\]\ skip_check\ presente,\ salto\ hostapd$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] skip_check is present; skipping hostapd'
                    fi
                    ;;
                '[ERROR] CONFIG_FILES vuota')
                    pdw_regex='^\[ERROR\]\ CONFIG_FILES\ vuota$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] CONFIG_FILES is empty'
                    fi
                    ;;
                '[ERROR] Hostapd non avviato (exit code '*')')
                    pdw_regex='^\[ERROR\]\ Hostapd\ non\ avviato\ \(exit\ code\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Hostapd did not start (exit code %s)' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Interfacce non nel bridge dopo '*s)
                    pdw_regex='^\[ERROR\]\ Interfacce\ non\ nel\ bridge\ dopo\ (.*)s$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Interfaces did not join the bridge within %ss' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] hostapd morto durante init bridge')
                    pdw_regex='^\[ERROR\]\ hostapd\ morto\ durante\ init\ bridge$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] hostapd exited during bridge initialization'
                    fi
                    ;;
                '[WARN]   '*' → br0 MANCANTE')
                    pdw_regex='^\[WARN\]\ \ \ (.*)\ →\ br0\ MANCANTE$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN]   %s → br0 MISSING' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Dnsmasq e socket DHCP pronti dopo '*s.)
                    pdw_regex='^\[INFO\]\ Dnsmasq\ e\ socket\ DHCP\ pronti\ dopo\ (.*)s\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Dnsmasq and DHCP socket ready after %ss.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Avvio dnsmasq fallito (exit code '*')')
                    pdw_regex='^\[ERROR\]\ Avvio\ dnsmasq\ fallito\ \(exit\ code\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Failed to start dnsmasq (exit code %s)' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] DHCP non pronto dopo '*s)
                    pdw_regex='^\[ERROR\]\ DHCP\ non\ pronto\ dopo\ (.*)s$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] DHCP is not ready after %ss' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] fcgiwrap socket non creato')
                    pdw_regex='^\[ERROR\]\ fcgiwrap\ socket\ non\ creato$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] fcgiwrap socket was not created'
                    fi
                    ;;
                '[INFO] fcgiwrap avviato')
                    pdw_regex='^\[INFO\]\ fcgiwrap\ avviato$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] fcgiwrap started'
                    fi
                    ;;
                '[ERROR] nginx non partito')
                    pdw_regex='^\[ERROR\]\ nginx\ non\ partito$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] nginx did not start'
                    fi
                    ;;
                '[INFO] nginx avviato su porta 8888 (login e rotazione log attivi)')
                    pdw_regex='^\[INFO\]\ nginx\ avviato\ su\ porta\ 8888\ \(login\ e\ rotazione\ log\ attivi\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] nginx started on port 8888 (sign-in and log rotation enabled)'
                    fi
                    ;;
                '[ERROR] Healthcheck unhealthy. Terminazione...')
                    pdw_regex='^\[ERROR\]\ Healthcheck\ unhealthy\.\ Terminazione\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Healthcheck is unhealthy. Terminating...'
                    fi
                    ;;
                '[INFO] Cleanup in corso...')
                    pdw_regex='^\[INFO\]\ Cleanup\ in\ corso\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Cleanup in progress...'
                    fi
                    ;;
                '[INFO] Cleanup completato.')
                    pdw_regex='^\[INFO\]\ Cleanup\ completato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Cleanup completed.'
                    fi
                    ;;
                '[ERROR] Ricevuto '*' dopo un guasto locale confermato; arresto controllato.')
                    pdw_regex='^\[ERROR\]\ Ricevuto\ (.*)\ dopo\ un\ guasto\ locale\ confermato;\ arresto\ controllato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Received %s after a confirmed local fault; controlled container shutdown.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Ricevuto '*'; arresto richiesto, non un errore INIT.')
                    pdw_regex='^\[INFO\]\ Ricevuto\ (.*);\ arresto\ richiesto,\ non\ un\ errore\ INIT\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Received %s; shutdown requested, not an INIT error.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'Verifica variabili')
                    pdw_regex='^Verifica\ variabili$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Check variables'
                    fi
                    ;;
                'Verifica nsswitch')
                    pdw_regex='^Verifica\ nsswitch$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Check nsswitch'
                    fi
                    ;;
                'Configurazione DNS')
                    pdw_regex='^Configurazione\ DNS$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configure DNS'
                    fi
                    ;;
                'Configurazione NAT')
                    pdw_regex='^Configurazione\ NAT$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configure NAT'
                    fi
                    ;;
                'Sblocco WiFi')
                    pdw_regex='^Sblocco\ WiFi$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Unblock Wi-Fi'
                    fi
                    ;;
                'Regole iptables')
                    pdw_regex='^Regole\ iptables$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Iptables rules'
                    fi
                    ;;
                'Configurazione bridge')
                    pdw_regex='^Configurazione\ bridge$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configure bridge'
                    fi
                    ;;
                'Avvio hostapd')
                    pdw_regex='^Avvio\ hostapd$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Start hostapd'
                    fi
                    ;;
                'Avvio dnsmasq')
                    pdw_regex='^Avvio\ dnsmasq$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Start dnsmasq'
                    fi
                    ;;
                'Rotte LAN')
                    pdw_regex='^Rotte\ LAN$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'LAN Routes'
                    fi
                    ;;
                '[INFO] === INIT completata in '*'s ===')
                    pdw_regex='^\[INFO\]\ ===\ INIT\ completata\ in\ (.*)s\ ===$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] === INIT completed in %ss ===' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'Avvio webserver')
                    pdw_regex='^Avvio\ webserver$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Start web server'
                    fi
                    ;;
                '[WARN] Webserver non partito — dashboard offline')
                    pdw_regex='^\[WARN\]\ Webserver\ non\ partito\ —\ dashboard\ offline$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Web server did not start — dashboard offline'
                    fi
                    ;;
                '[ERROR] Impossibile pubblicare il marcatore di avvio corrente.')
                    pdw_regex='^\[ERROR\]\ Impossibile\ pubblicare\ il\ marcatore\ di\ avvio\ corrente\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Cannot publish the current startup marker.'
                    fi
                    ;;
                '[INFO] === Tutti i servizi avviati ===')
                    pdw_regex='^\[INFO\]\ ===\ Tutti\ i\ servizi\ avviati\ ===$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] === All services started ==='
                    fi
                    ;;
                '[WARN] Tutti i processi di monitoraggio sono terminati.')
                    pdw_regex='^\[WARN\]\ Tutti\ i\ processi\ di\ monitoraggio\ sono\ terminati\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] All monitoring processes have exited.'
                    fi
                    ;;
                '[ERROR] Attesa dei processi runtime terminata (exit code '*').')
                    pdw_regex='^\[ERROR\]\ Attesa\ dei\ processi\ runtime\ terminata\ \(exit\ code\ (.*)\)\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Waiting for runtime processes ended (exit code %s).' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Startup non completato, salto healthcheck')
                    pdw_regex='^\[INFO\]\ Startup\ non\ completato,\ salto\ healthcheck$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Startup is not complete; skipping healthcheck'
                    fi
                    ;;
                '[INFO] Restart in corso, salto healthcheck')
                    pdw_regex='^\[INFO\]\ Restart\ in\ corso,\ salto\ healthcheck$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Restart in progress; skipping healthcheck'
                    fi
                    ;;
                '[INFO] hostapd terminato')
                    pdw_regex='^\[INFO\]\ hostapd\ terminato$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] hostapd terminated'
                    fi
                    ;;
                '[WARN] '*' inattivo o senza '*', tento recovery...')
                    pdw_regex='^\[WARN\]\ (.*)\ inattivo\ o\ senza\ (.*),\ tento\ recovery\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] %s is down or missing %s; attempting recovery...' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] '*' stato e indirizzo ripristinati con successo')
                    pdw_regex='^\[INFO\]\ (.*)\ stato\ e\ indirizzo\ ripristinati\ con\ successo$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] %s state and address restored successfully' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] '*' non recuperabile')
                    pdw_regex='^\[ERROR\]\ (.*)\ non\ recuperabile$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Cannot recover %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] hostapd non in esecuzione')
                    pdw_regex='^\[ERROR\]\ hostapd\ non\ in\ esecuzione$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] hostapd is not running'
                    fi
                    ;;
                '[WARN] Socket hostapd mancante per '*'')
                    pdw_regex='^\[WARN\]\ Socket\ hostapd\ mancante\ per\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Missing hostapd socket for %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] hostapd non risponde su '*'')
                    pdw_regex='^\[WARN\]\ hostapd\ non\ risponde\ su\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] hostapd is not responding on %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] Radio '*' non operativa')
                    pdw_regex='^\[WARN\]\ Radio\ (.*)\ non\ operativa$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Radio %s is not operational' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] '*' inattiva o non collegata a '*'')
                    pdw_regex='^\[WARN\]\ (.*)\ inattiva\ o\ non\ collegata\ a\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] %s is down or not attached to %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] dnsmasq tornato attivo da solo')
                    pdw_regex='^\[INFO\]\ dnsmasq\ tornato\ attivo\ da\ solo$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] dnsmasq recovered on its own'
                    fi
                    ;;
                '[ERROR] dnsmasq presente ma DHCP non in ascolto; nessun avvio duplicato')
                    pdw_regex='^\[ERROR\]\ dnsmasq\ presente\ ma\ DHCP\ non\ in\ ascolto;\ nessun\ avvio\ duplicato$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] dnsmasq exists but DHCP is not listening; not starting a duplicate'
                    fi
                    ;;
                '[ERROR] dnsmasq morto e br0 senza IP — skip recovery')
                    pdw_regex='^\[ERROR\]\ dnsmasq\ morto\ e\ br0\ senza\ IP\ —\ skip\ recovery$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] dnsmasq exited and br0 has no IP address — skipping recovery'
                    fi
                    ;;
                '[WARN] dnsmasq non attivo, riavvio...')
                    pdw_regex='^\[WARN\]\ dnsmasq\ non\ attivo,\ riavvio\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] dnsmasq is not running; restarting...'
                    fi
                    ;;
                '[INFO] dnsmasq riavviato con log + rotazione')
                    pdw_regex='^\[INFO\]\ dnsmasq\ riavviato\ con\ log\ \+\ rotazione$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] dnsmasq restarted with logging and rotation'
                    fi
                    ;;
                '[ERROR] dnsmasq non recuperabile')
                    pdw_regex='^\[ERROR\]\ dnsmasq\ non\ recuperabile$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Cannot recover dnsmasq'
                    fi
                    ;;
                '[OK] Servizi locali Wi-Fi/DHCP/rotte sani; Ethernet: '*'. Internet non verificata da questo healthcheck.')
                    pdw_regex='^\[OK\]\ Servizi\ locali\ Wi\-Fi/DHCP/rotte\ sani;\ Ethernet:\ (.*)\.\ Internet\ non\ verificata\ da\ questo\ healthcheck\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[OK] Local Wi-Fi/DHCP/routes are healthy; Ethernet: %s. This healthcheck does not verify Internet access.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] Servizi locali Wi-Fi/DHCP/rotte sani; Ethernet degradata: '*'. Nessun riavvio della LAN per un guasto a monte.')
                    pdw_regex='^\[WARN\]\ Servizi\ locali\ Wi\-Fi/DHCP/rotte\ sani;\ Ethernet\ degradata:\ (.*)\.\ Nessun\ riavvio\ della\ LAN\ per\ un\ guasto\ a\ monte\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Local Wi-Fi/DHCP/routes are healthy; Ethernet is degraded: %s. The LAN will not restart for an upstream fault.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] Problemi: '*' (fallimento '*/*')')
                    pdw_regex='^\[WARN\]\ Problemi:\ (.*)\ \(fallimento\ (.*)/(.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Problems: %s (failure %s/%s)' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
                    fi
                    ;;
                '[INFO] dnsmasq già attivo, nessun avvio duplicato.')
                    pdw_regex='^\[INFO\]\ dnsmasq\ già\ attivo,\ nessun\ avvio\ duplicato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] dnsmasq is already running; not starting a duplicate.'
                    fi
                    ;;
                '[ERROR] Argomento dnsmasq_start non valido')
                    pdw_regex='^\[ERROR\]\ Argomento\ dnsmasq_start\ non\ valido$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Invalid dnsmasq_start argument'
                    fi
                    ;;
                '[ERROR] br0 senza indirizzo corretto; dnsmasq non verrà avviato.')
                    pdw_regex='^\[ERROR\]\ br0\ senza\ indirizzo\ corretto;\ dnsmasq\ non\ verrà\ avviato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] br0 has no valid address; dnsmasq will not start.'
                    fi
                    ;;
                '[INFO] dnsmasq arrestato regolarmente.')
                    pdw_regex='^\[INFO\]\ dnsmasq\ arrestato\ regolarmente\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] dnsmasq stopped normally.'
                    fi
                    ;;
                '[WARN] dnsmasq terminato inaspettatamente (exit code '*')')
                    pdw_regex='^\[WARN\]\ dnsmasq\ terminato\ inaspettatamente\ \(exit\ code\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] dnsmasq exited unexpectedly (exit code %s)' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Argomento server-routes non valido')
                    pdw_regex='^\[ERROR\]\ Argomento\ server\-routes\ non\ valido$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Invalid server-routes argument'
                    fi
                    ;;
                '[INFO] Avvio configurazione routes...')
                    pdw_regex='^\[INFO\]\ Avvio\ configurazione\ routes\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Configuring routes...'
                    fi
                    ;;
                '[INFO] OK: '*' via '*' è già configurata.')
                    pdw_regex='^\[INFO\]\ OK:\ (.*)\ via\ (.*)\ è\ già\ configurata\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] OK: %s via %s is already configured.' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] Rotta impostata: '*' via '*'')
                    pdw_regex='^\[INFO\]\ Rotta\ impostata:\ (.*)\ via\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Route set: %s via %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[ERROR] Impossibile impostare '*' via '*'. Verifica permessi/connettività.')
                    pdw_regex='^\[ERROR\]\ Impossibile\ impostare\ (.*)\ via\ (.*)\.\ Verifica\ permessi/connettività\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Cannot set %s via %s. Check permissions/connectivity.' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] Ethernet '*' configurata: '*', gateway '*'. Recupero Ethernet integrato in questo container tramite NetworkManager.')
                    pdw_regex='^\[INFO\]\ Ethernet\ (.*)\ configurata:\ (.*),\ gateway\ (.*)\.\ Recupero\ Ethernet\ integrato\ in\ questo\ container\ tramite\ NetworkManager\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Ethernet %s configured: %s, gateway %s. Ethernet recovery is integrated into this container through NetworkManager.' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
                    fi
                    ;;
                '[WARN] Ethernet '*': carrier assente. Wi-Fi/LAN mantenuti; attendo il collegamento fisico, nessun reset ciclico.')
                    pdw_regex='^\[WARN\]\ Ethernet\ (.*):\ carrier\ assente\.\ Wi\-Fi/LAN\ mantenuti;\ attendo\ il\ collegamento\ fisico,\ nessun\ reset\ ciclico\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Ethernet %s: no carrier. Wi-Fi/LAN remain active; waiting for the physical link without repeated resets.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] Ethernet '*': '*'. Wi-Fi/LAN mantenuti; Il recupero integrato gestisce il ripristino tramite NetworkManager.')
                    pdw_regex='^\[WARN\]\ Ethernet\ (.*):\ (.*)\.\ Wi\-Fi/LAN\ mantenuti;\ Il\ recupero\ integrato\ gestisce\ il\ ripristino\ tramite\ NetworkManager\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Ethernet %s: %s. Wi-Fi/LAN remain active; integrated recovery uses NetworkManager to restore the uplink.' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] Riga '"'"'hosts:'"'"' sostituita con successo tramite reindirizzamento.')
                    pdw_regex='^\[INFO\]\ Riga\ '"'"'hosts:'"'"'\ sostituita\ con\ successo\ tramite\ reindirizzamento\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] The '"'"'hosts:'"'"' line was replaced successfully through redirection.'
                    fi
                    ;;
                '[ERROR] Impossibile sovrascrivere '*'. Permessi insufficienti o file system RO.')
                    pdw_regex='^\[ERROR\]\ Impossibile\ sovrascrivere\ (.*)\.\ Permessi\ insufficienti\ o\ file\ system\ RO\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Cannot overwrite %s. Insufficient permissions or read-only filesystem.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Verifica finale: la configurazione è corretta.')
                    pdw_regex='^\[INFO\]\ Verifica\ finale:\ la\ configurazione\ è\ corretta\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Final verification: the configuration is correct.'
                    fi
                    ;;
                '[ERROR] La modifica ha avuto esito, ma la verifica finale ha fallito.')
                    pdw_regex='^\[ERROR\]\ La\ modifica\ ha\ avuto\ esito,\ ma\ la\ verifica\ finale\ ha\ fallito\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] The change succeeded, but final verification failed.'
                    fi
                    ;;
                '[ERROR] Errore durante l'"'"'esecuzione di sed sul file temporaneo.')
                    pdw_regex='^\[ERROR\]\ Errore\ durante\ l'"'"'esecuzione\ di\ sed\ sul\ file\ temporaneo\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] sed failed on the temporary file.'
                    fi
                    ;;
                '[FATAL] File mancante: '*'')
                    pdw_regex='^\[FATAL\]\ File\ mancante:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[FATAL] Missing file: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] Riga '"'"'hosts:'"'"' assente. Procedendo con l'"'"'aggiunta/sostituzione.')
                    pdw_regex='^\[WARN\]\ Riga\ '"'"'hosts:'"'"'\ assente\.\ Procedendo\ con\ l'"'"'aggiunta/sostituzione\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] The '"'"'hosts:'"'"' line is missing. Adding/replacing it.'
                    fi
                    ;;
                '[INFO] Nsswitch già corretto. Nessuna modifica necessaria.')
                    pdw_regex='^\[INFO\]\ Nsswitch\ già\ corretto\.\ Nessuna\ modifica\ necessaria\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Nsswitch is already correct. No changes needed.'
                    fi
                    ;;
                '[INFO] Nsswitch non è corretto. Sostituendola con la nuova riga.')
                    pdw_regex='^\[INFO\]\ Nsswitch\ non\ è\ corretto\.\ Sostituendola\ con\ la\ nuova\ riga\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Nsswitch is incorrect. Replacing it with the new line.'
                    fi
                    ;;
                '[INFO] Backup creato correttamente: '*'')
                    pdw_regex='^\[INFO\]\ Backup\ creato\ correttamente:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Backup created successfully: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Impossibile creare il backup. Aborto per sicurezza.')
                    pdw_regex='^\[ERROR\]\ Impossibile\ creare\ il\ backup\.\ Aborto\ per\ sicurezza\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Cannot create the backup. Aborting for safety.'
                    fi
                    ;;
                '[ERROR] L'"'"'aggiornamento è fallito. Il backup è disponibile in '*.)
                    pdw_regex='^\[ERROR\]\ L'"'"'aggiornamento\ è\ fallito\.\ Il\ backup\ è\ disponibile\ in\ (.*)\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Update failed. The backup is available in %s.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Aggiornamento fallito. Ripristino manuale consigliato.')
                    pdw_regex='^\[ERROR\]\ Aggiornamento\ fallito\.\ Ripristino\ manuale\ consigliato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Update failed. Manual restoration is recommended.'
                    fi
                    ;;
                '[INFO] Configurazione Nsswitch aggiornato e verificato.')
                    pdw_regex='^\[INFO\]\ Configurazione\ Nsswitch\ aggiornato\ e\ verificato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Nsswitch configuration updated and verified.'
                    fi
                    ;;
                '[ERROR] Variabile CONFIG_FILES non definita!')
                    pdw_regex='^\[ERROR\]\ Variabile\ CONFIG_FILES\ non\ definita!$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] CONFIG_FILES is not defined!'
                    fi
                    ;;
                '[INFO] Avvio hostapd con config: '*'')
                    pdw_regex='^\[INFO\]\ Avvio\ hostapd\ con\ config:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Starting hostapd with configuration: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Hostapd partito e risponde (PID '*').')
                    pdw_regex='^\[INFO\]\ Hostapd\ partito\ e\ risponde\ \(PID\ (.*)\)\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Hostapd started and is responding (PID %s).' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Hostapd non pronto (exit code: '*')')
                    pdw_regex='^\[ERROR\]\ Hostapd\ non\ pronto\ \(exit\ code:\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Hostapd is not ready (exit code: %s)' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'Tutti i pacchetti richiesti sono già installati.')
                    pdw_regex='^Tutti\ i\ pacchetti\ richiesti\ sono\ già\ installati\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'All required packages are already installed.'
                    fi
                    ;;
                'Installo pacchetti mancanti: '*'')
                    pdw_regex='^Installo\ pacchetti\ mancanti:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Installing missing packages: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '  ✔ Pacchetti installati.')
                    pdw_regex='^\ \ ✔\ Pacchetti\ installati\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ Packages installed.'
                    fi
                    ;;
                '  ✖ ERRORE: installazione pacchetti fallita. Continuo ma alcune funzioni potrebbero fallire.')
                    pdw_regex='^\ \ ✖\ ERRORE:\ installazione\ pacchetti\ fallita\.\ Continuo\ ma\ alcune\ funzioni\ potrebbero\ fallire\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✖ ERROR: package installation failed. Continuing, but some features may fail.'
                    fi
                    ;;
                'MAC WiFi non disponibili → rimando al prossimo boot')
                    pdw_regex='^MAC\ WiFi\ non\ disponibili\ →\ rimando\ al\ prossimo\ boot$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Wi-Fi MAC addresses are unavailable → retrying at the next boot'
                    fi
                    ;;
                ''*' già configurato: mantengo il valore esistente.')
                    pdw_regex='^(.*)\ già\ configurato:\ mantengo\ il\ valore\ esistente\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '%s is already configured: keeping its current value.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '  ✔ irq-pin.sh v1 installato/aggiornato.')
                    pdw_regex='^\ \ ✔\ irq\-pin\.sh\ v1\ installato/aggiornato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ irq-pin.sh v1 installed/updated.'
                    fi
                    ;;
                'irq-pin.sh v1 già presente, salto.')
                    pdw_regex='^irq\-pin\.sh\ v1\ già\ presente,\ salto\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'irq-pin.sh v1 is already present; skipping it.'
                    fi
                    ;;
                '  ✔ Servizio irq-affinity creato/aggiornato (UNIT_VERSION=1).')
                    pdw_regex='^\ \ ✔\ Servizio\ irq\-affinity\ creato/aggiornato\ \(UNIT_VERSION=1\)\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ irq-affinity service created/updated (UNIT_VERSION=1).'
                    fi
                    ;;
                '  ✔ irq-affinity applicato.')
                    pdw_regex='^\ \ ✔\ irq\-affinity\ applicato\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ irq-affinity applied.'
                    fi
                    ;;
                'Configurazione Avahi su '*' per interfacce: '*'')
                    pdw_regex='^Configurazione\ Avahi\ su\ (.*)\ per\ interfacce:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configuring Avahi on %s for interfaces: %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                'ERRORE: impossibile installare avahi-daemon')
                    pdw_regex='^ERRORE:\ impossibile\ installare\ avahi\-daemon$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'ERROR: cannot install avahi-daemon'
                    fi
                    ;;
                'ERRORE: '*' non trovato')
                    pdw_regex='^ERRORE:\ (.*)\ non\ trovato$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'ERROR: %s not found' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'Configurazione scritta. Riavvio avahi-daemon...')
                    pdw_regex='^Configurazione\ scritta\.\ Riavvio\ avahi\-daemon\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configuration written. Restarting avahi-daemon...'
                    fi
                    ;;
                'Configurazione completata su '*'')
                    pdw_regex='^Configurazione\ completata\ su\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configuration completed on %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'WARN: avahi-daemon restart fallito su '*'')
                    pdw_regex='^WARN:\ avahi\-daemon\ restart\ fallito\ su\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'WARN: avahi-daemon restart failed on %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'Configuro Avahi reflector su '*' (interfacce: '*')...')
                    pdw_regex='^Configuro\ Avahi\ reflector\ su\ (.*)\ \(interfacce:\ (.*)\)\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configuring Avahi reflector on %s (interfaces: %s)...' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '  ✔ Configurazione riuscita su localhost.')
                    pdw_regex='^\ \ ✔\ Configurazione\ riuscita\ su\ localhost\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ Configuration succeeded on localhost.'
                    fi
                    ;;
                '  ✖ WARN: configurazione fallita su localhost.')
                    pdw_regex='^\ \ ✖\ WARN:\ configurazione\ fallita\ su\ localhost\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✖ WARN: configuration failed on localhost.'
                    fi
                    ;;
                'Reboot necessario per applicare le modifiche al kernel.')
                    pdw_regex='^Reboot\ necessario\ per\ applicare\ le\ modifiche\ al\ kernel\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'A reboot is required to apply the kernel changes.'
                    fi
                    ;;
                'Fallimento consecutivo '*': '*'')
                    pdw_regex='^Fallimento\ consecutivo\ (.*):\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Consecutive failure %s: %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                'rotte LAN')
                    pdw_regex='^rotte\ LAN$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'LAN routes'
                    fi
                    ;;
                'DASHBOARD_PASSWORD mancante')
                    pdw_regex='^DASHBOARD_PASSWORD\ mancante$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'DASHBOARD_PASSWORD is missing'
                    fi
                    ;;
                'PIHOLE_PASSWORD mancante')
                    pdw_regex='^PIHOLE_PASSWORD\ mancante$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'PIHOLE_PASSWORD is missing'
                    fi
                    ;;
                'Web asset mancante: '*'')
                    pdw_regex='^Web\ asset\ mancante:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Missing web asset: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
            esac
            ;;
        it)
            case "$PDW_MESSAGE" in
                'no ping replies') PDW_MESSAGE='nessuna risposta ai ping' ;;
                'cable disconnected') PDW_MESSAGE='cavo scollegato' ;;
                'interface is down') PDW_MESSAGE='interfaccia disattivata' ;;
                'no IP address') PDW_MESSAGE='IP assente' ;;
                'no gateway') PDW_MESSAGE='gateway assente' ;;
                'interface missing') PDW_MESSAGE='interfaccia assente' ;;
                'interface not configured') PDW_MESSAGE='interfaccia non configurata' ;;
                '[OK] Health check passed.') PDW_MESSAGE='[OK] Healthcheck superato.' ;;
                'APP_LANGUAGE must be it or en')
                    pdw_regex='^APP_LANGUAGE\ must\ be\ it\ or\ en$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'APP_LANGUAGE deve essere it oppure en'
                    fi
                    ;;
                '[FATAL] Error at line '*': command "'*'" (exit code '*')')
                    pdw_regex='^\[FATAL\]\ Error\ at\ line\ (.*):\ command\ "(.*)"\ \(exit\ code\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[FATAL] Errore alla riga %s: comando "%s" (exit code %s)' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
                    fi
                    ;;
                '[ERROR] Configure '*' in .env before starting.')
                    pdw_regex='^\[ERROR\]\ Configure\ (.*)\ in\ \.env\ before\ starting\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Configurare %s in .env prima dell'"'"'avvio.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Configure WPS_UUID in .env')
                    pdw_regex='^\[ERROR\]\ Configure\ WPS_UUID\ in\ \.env$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Configurare WPS_UUID in .env'
                    fi
                    ;;
                '[ERROR] Environment variable '"'"''*''"'"' is not defined.')
                    pdw_regex='^\[ERROR\]\ Environment\ variable\ '"'"'(.*)'"'"'\ is\ not\ defined\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Variabile d'"'"'ambiente '"'"'%s'"'"' non definita.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Privileged mode is required.')
                    pdw_regex='^\[ERROR\]\ Privileged\ mode\ is\ required\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Manca la privileged mode.'
                    fi
                    ;;
                '[WARNING] check_nsswitch.sh failed (continuing)')
                    pdw_regex='^\[WARNING\]\ check_nsswitch\.sh\ failed\ \(continuing\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARNING] check_nsswitch.sh errore (continuo)'
                    fi
                    ;;
                '[ERROR] Interface '*' does not exist!')
                    pdw_regex='^\[ERROR\]\ Interface\ (.*)\ does\ not\ exist!$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Interfaccia %s non esiste!' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] '*' has an IP address.')
                    pdw_regex='^\[INFO\]\ (.*)\ has\ an\ IP\ address\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] %s ha un IP.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARNING] '*' has no IP address. DNS will still be configured.')
                    pdw_regex='^\[WARNING\]\ (.*)\ has\ no\ IP\ address\.\ DNS\ will\ still\ be\ configured\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARNING] %s senza IP. DNS verrà comunque fissato.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] DNS set to 192.168.4.1.')
                    pdw_regex='^\[INFO\]\ DNS\ set\ to\ 192\.168\.4\.1\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] DNS fissato su 192.168.4.1.'
                    fi
                    ;;
                '[INFO] '*' is already enabled')
                    pdw_regex='^\[INFO\]\ (.*)\ is\ already\ enabled$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] %s già attivo' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] '*' enabled')
                    pdw_regex='^\[INFO\]\ (.*)\ enabled$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] %s attivato' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] /bin/iptables-rules.sh not found')
                    pdw_regex='^\[ERROR\]\ /bin/iptables\-rules\.sh\ not\ found$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] /bin/iptables-rules.sh non trovato'
                    fi
                    ;;
                '[ERROR] Failed to unblock Wi-Fi')
                    pdw_regex='^\[ERROR\]\ Failed\ to\ unblock\ Wi\-Fi$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Sblocco WiFi fallito'
                    fi
                    ;;
                '[INFO] Wi-Fi unblocked: '*'')
                    pdw_regex='^\[INFO\]\ Wi\-Fi\ unblocked:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] WiFi sbloccato: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] No Wi-Fi interfaces are blocked.')
                    pdw_regex='^\[INFO\]\ No\ Wi\-Fi\ interfaces\ are\ blocked\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Nessuna interfaccia WiFi bloccata.'
                    fi
                    ;;
                '[INFO] br0 exists; recreating it...')
                    pdw_regex='^\[INFO\]\ br0\ exists;\ recreating\ it\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] br0 esiste, ricreo...'
                    fi
                    ;;
                '[ERROR] Failed to create br0')
                    pdw_regex='^\[ERROR\]\ Failed\ to\ create\ br0$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Creazione br0 fallita'
                    fi
                    ;;
                '[INFO] Bridge br0 created.')
                    pdw_regex='^\[INFO\]\ Bridge\ br0\ created\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Bridge br0 creato.'
                    fi
                    ;;
                '[INFO] skip_check is present; skipping hostapd')
                    pdw_regex='^\[INFO\]\ skip_check\ is\ present;\ skipping\ hostapd$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] skip_check presente, salto hostapd'
                    fi
                    ;;
                '[ERROR] CONFIG_FILES is empty')
                    pdw_regex='^\[ERROR\]\ CONFIG_FILES\ is\ empty$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] CONFIG_FILES vuota'
                    fi
                    ;;
                '[ERROR] Hostapd did not start (exit code '*')')
                    pdw_regex='^\[ERROR\]\ Hostapd\ did\ not\ start\ \(exit\ code\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Hostapd non avviato (exit code %s)' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Interfaces did not join the bridge within '*s)
                    pdw_regex='^\[ERROR\]\ Interfaces\ did\ not\ join\ the\ bridge\ within\ (.*)s$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Interfacce non nel bridge dopo %ss' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] hostapd exited during bridge initialization')
                    pdw_regex='^\[ERROR\]\ hostapd\ exited\ during\ bridge\ initialization$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] hostapd morto durante init bridge'
                    fi
                    ;;
                '[WARN]   '*' → br0 MISSING')
                    pdw_regex='^\[WARN\]\ \ \ (.*)\ →\ br0\ MISSING$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN]   %s → br0 MANCANTE' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Dnsmasq and DHCP socket ready after '*s.)
                    pdw_regex='^\[INFO\]\ Dnsmasq\ and\ DHCP\ socket\ ready\ after\ (.*)s\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Dnsmasq e socket DHCP pronti dopo %ss.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Failed to start dnsmasq (exit code '*')')
                    pdw_regex='^\[ERROR\]\ Failed\ to\ start\ dnsmasq\ \(exit\ code\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Avvio dnsmasq fallito (exit code %s)' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] DHCP is not ready after '*s)
                    pdw_regex='^\[ERROR\]\ DHCP\ is\ not\ ready\ after\ (.*)s$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] DHCP non pronto dopo %ss' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] fcgiwrap socket was not created')
                    pdw_regex='^\[ERROR\]\ fcgiwrap\ socket\ was\ not\ created$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] fcgiwrap socket non creato'
                    fi
                    ;;
                '[INFO] fcgiwrap started')
                    pdw_regex='^\[INFO\]\ fcgiwrap\ started$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] fcgiwrap avviato'
                    fi
                    ;;
                '[ERROR] nginx did not start')
                    pdw_regex='^\[ERROR\]\ nginx\ did\ not\ start$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] nginx non partito'
                    fi
                    ;;
                '[INFO] nginx started on port 8888 (sign-in and log rotation enabled)')
                    pdw_regex='^\[INFO\]\ nginx\ started\ on\ port\ 8888\ \(sign\-in\ and\ log\ rotation\ enabled\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] nginx avviato su porta 8888 (login e rotazione log attivi)'
                    fi
                    ;;
                '[ERROR] Healthcheck is unhealthy. Terminating...')
                    pdw_regex='^\[ERROR\]\ Healthcheck\ is\ unhealthy\.\ Terminating\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Healthcheck unhealthy. Terminazione...'
                    fi
                    ;;
                '[INFO] Cleanup in progress...')
                    pdw_regex='^\[INFO\]\ Cleanup\ in\ progress\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Cleanup in corso...'
                    fi
                    ;;
                '[INFO] Cleanup completed.')
                    pdw_regex='^\[INFO\]\ Cleanup\ completed\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Cleanup completato.'
                    fi
                    ;;
                '[ERROR] Received '*' after a confirmed local fault; controlled container shutdown.')
                    pdw_regex='^\[ERROR\]\ Received\ (.*)\ after\ a\ confirmed\ local\ fault;\ controlled\ container\ shutdown\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Ricevuto %s dopo un guasto locale confermato; arresto controllato.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Received '*'; shutdown requested, not an INIT error.')
                    pdw_regex='^\[INFO\]\ Received\ (.*);\ shutdown\ requested,\ not\ an\ INIT\ error\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Ricevuto %s; arresto richiesto, non un errore INIT.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'Check variables')
                    pdw_regex='^Check\ variables$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Verifica variabili'
                    fi
                    ;;
                'Check nsswitch')
                    pdw_regex='^Check\ nsswitch$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Verifica nsswitch'
                    fi
                    ;;
                'Configure DNS')
                    pdw_regex='^Configure\ DNS$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configurazione DNS'
                    fi
                    ;;
                'Configure NAT')
                    pdw_regex='^Configure\ NAT$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configurazione NAT'
                    fi
                    ;;
                'Unblock Wi-Fi')
                    pdw_regex='^Unblock\ Wi\-Fi$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Sblocco WiFi'
                    fi
                    ;;
                'Iptables rules')
                    pdw_regex='^Iptables\ rules$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Regole iptables'
                    fi
                    ;;
                'Configure bridge')
                    pdw_regex='^Configure\ bridge$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configurazione bridge'
                    fi
                    ;;
                'Start hostapd')
                    pdw_regex='^Start\ hostapd$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Avvio hostapd'
                    fi
                    ;;
                'Start dnsmasq')
                    pdw_regex='^Start\ dnsmasq$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Avvio dnsmasq'
                    fi
                    ;;
                'LAN Routes')
                    pdw_regex='^LAN\ Routes$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Rotte LAN'
                    fi
                    ;;
                '[INFO] === INIT completed in '*'s ===')
                    pdw_regex='^\[INFO\]\ ===\ INIT\ completed\ in\ (.*)s\ ===$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] === INIT completata in %ss ===' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'Start web server')
                    pdw_regex='^Start\ web\ server$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Avvio webserver'
                    fi
                    ;;
                '[WARN] Web server did not start — dashboard offline')
                    pdw_regex='^\[WARN\]\ Web\ server\ did\ not\ start\ —\ dashboard\ offline$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Webserver non partito — dashboard offline'
                    fi
                    ;;
                '[ERROR] Cannot publish the current startup marker.')
                    pdw_regex='^\[ERROR\]\ Cannot\ publish\ the\ current\ startup\ marker\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Impossibile pubblicare il marcatore di avvio corrente.'
                    fi
                    ;;
                '[INFO] === All services started ===')
                    pdw_regex='^\[INFO\]\ ===\ All\ services\ started\ ===$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] === Tutti i servizi avviati ==='
                    fi
                    ;;
                '[WARN] All monitoring processes have exited.')
                    pdw_regex='^\[WARN\]\ All\ monitoring\ processes\ have\ exited\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Tutti i processi di monitoraggio sono terminati.'
                    fi
                    ;;
                '[ERROR] Waiting for runtime processes ended (exit code '*').')
                    pdw_regex='^\[ERROR\]\ Waiting\ for\ runtime\ processes\ ended\ \(exit\ code\ (.*)\)\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Attesa dei processi runtime terminata (exit code %s).' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Startup is not complete; skipping healthcheck')
                    pdw_regex='^\[INFO\]\ Startup\ is\ not\ complete;\ skipping\ healthcheck$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Startup non completato, salto healthcheck'
                    fi
                    ;;
                '[INFO] Restart in progress; skipping healthcheck')
                    pdw_regex='^\[INFO\]\ Restart\ in\ progress;\ skipping\ healthcheck$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Restart in corso, salto healthcheck'
                    fi
                    ;;
                '[INFO] hostapd terminated')
                    pdw_regex='^\[INFO\]\ hostapd\ terminated$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] hostapd terminato'
                    fi
                    ;;
                '[WARN] '*' is down or missing '*'; attempting recovery...')
                    pdw_regex='^\[WARN\]\ (.*)\ is\ down\ or\ missing\ (.*);\ attempting\ recovery\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] %s inattivo o senza %s, tento recovery...' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] '*' state and address restored successfully')
                    pdw_regex='^\[INFO\]\ (.*)\ state\ and\ address\ restored\ successfully$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] %s stato e indirizzo ripristinati con successo' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Cannot recover '*'')
                    pdw_regex='^\[ERROR\]\ Cannot\ recover\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] %s non recuperabile' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] hostapd is not running')
                    pdw_regex='^\[ERROR\]\ hostapd\ is\ not\ running$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] hostapd non in esecuzione'
                    fi
                    ;;
                '[WARN] Missing hostapd socket for '*'')
                    pdw_regex='^\[WARN\]\ Missing\ hostapd\ socket\ for\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Socket hostapd mancante per %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] hostapd is not responding on '*'')
                    pdw_regex='^\[WARN\]\ hostapd\ is\ not\ responding\ on\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] hostapd non risponde su %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] Radio '*' is not operational')
                    pdw_regex='^\[WARN\]\ Radio\ (.*)\ is\ not\ operational$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Radio %s non operativa' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] '*' is down or not attached to '*'')
                    pdw_regex='^\[WARN\]\ (.*)\ is\ down\ or\ not\ attached\ to\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] %s inattiva o non collegata a %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] dnsmasq recovered on its own')
                    pdw_regex='^\[INFO\]\ dnsmasq\ recovered\ on\ its\ own$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] dnsmasq tornato attivo da solo'
                    fi
                    ;;
                '[ERROR] dnsmasq exists but DHCP is not listening; not starting a duplicate')
                    pdw_regex='^\[ERROR\]\ dnsmasq\ exists\ but\ DHCP\ is\ not\ listening;\ not\ starting\ a\ duplicate$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] dnsmasq presente ma DHCP non in ascolto; nessun avvio duplicato'
                    fi
                    ;;
                '[ERROR] dnsmasq exited and br0 has no IP address — skipping recovery')
                    pdw_regex='^\[ERROR\]\ dnsmasq\ exited\ and\ br0\ has\ no\ IP\ address\ —\ skipping\ recovery$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] dnsmasq morto e br0 senza IP — skip recovery'
                    fi
                    ;;
                '[WARN] dnsmasq is not running; restarting...')
                    pdw_regex='^\[WARN\]\ dnsmasq\ is\ not\ running;\ restarting\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] dnsmasq non attivo, riavvio...'
                    fi
                    ;;
                '[INFO] dnsmasq restarted with logging and rotation')
                    pdw_regex='^\[INFO\]\ dnsmasq\ restarted\ with\ logging\ and\ rotation$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] dnsmasq riavviato con log + rotazione'
                    fi
                    ;;
                '[ERROR] Cannot recover dnsmasq')
                    pdw_regex='^\[ERROR\]\ Cannot\ recover\ dnsmasq$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] dnsmasq non recuperabile'
                    fi
                    ;;
                '[OK] Local Wi-Fi/DHCP/routes are healthy; Ethernet: '*'. This healthcheck does not verify Internet access.')
                    pdw_regex='^\[OK\]\ Local\ Wi\-Fi/DHCP/routes\ are\ healthy;\ Ethernet:\ (.*)\.\ This\ healthcheck\ does\ not\ verify\ Internet\ access\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[OK] Servizi locali Wi-Fi/DHCP/rotte sani; Ethernet: %s. Internet non verificata da questo healthcheck.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] Local Wi-Fi/DHCP/routes are healthy; Ethernet is degraded: '*'. The LAN will not restart for an upstream fault.')
                    pdw_regex='^\[WARN\]\ Local\ Wi\-Fi/DHCP/routes\ are\ healthy;\ Ethernet\ is\ degraded:\ (.*)\.\ The\ LAN\ will\ not\ restart\ for\ an\ upstream\ fault\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Servizi locali Wi-Fi/DHCP/rotte sani; Ethernet degradata: %s. Nessun riavvio della LAN per un guasto a monte.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] Problems: '*' (failure '*/*')')
                    pdw_regex='^\[WARN\]\ Problems:\ (.*)\ \(failure\ (.*)/(.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Problemi: %s (fallimento %s/%s)' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
                    fi
                    ;;
                '[INFO] dnsmasq is already running; not starting a duplicate.')
                    pdw_regex='^\[INFO\]\ dnsmasq\ is\ already\ running;\ not\ starting\ a\ duplicate\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] dnsmasq già attivo, nessun avvio duplicato.'
                    fi
                    ;;
                '[ERROR] Invalid dnsmasq_start argument')
                    pdw_regex='^\[ERROR\]\ Invalid\ dnsmasq_start\ argument$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Argomento dnsmasq_start non valido'
                    fi
                    ;;
                '[ERROR] br0 has no valid address; dnsmasq will not start.')
                    pdw_regex='^\[ERROR\]\ br0\ has\ no\ valid\ address;\ dnsmasq\ will\ not\ start\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] br0 senza indirizzo corretto; dnsmasq non verrà avviato.'
                    fi
                    ;;
                '[INFO] dnsmasq stopped normally.')
                    pdw_regex='^\[INFO\]\ dnsmasq\ stopped\ normally\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] dnsmasq arrestato regolarmente.'
                    fi
                    ;;
                '[WARN] dnsmasq exited unexpectedly (exit code '*')')
                    pdw_regex='^\[WARN\]\ dnsmasq\ exited\ unexpectedly\ \(exit\ code\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] dnsmasq terminato inaspettatamente (exit code %s)' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Invalid server-routes argument')
                    pdw_regex='^\[ERROR\]\ Invalid\ server\-routes\ argument$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Argomento server-routes non valido'
                    fi
                    ;;
                '[INFO] Configuring routes...')
                    pdw_regex='^\[INFO\]\ Configuring\ routes\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Avvio configurazione routes...'
                    fi
                    ;;
                '[INFO] OK: '*' via '*' is already configured.')
                    pdw_regex='^\[INFO\]\ OK:\ (.*)\ via\ (.*)\ is\ already\ configured\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] OK: %s via %s è già configurata.' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] Route set: '*' via '*'')
                    pdw_regex='^\[INFO\]\ Route\ set:\ (.*)\ via\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Rotta impostata: %s via %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[ERROR] Cannot set '*' via '*'. Check permissions/connectivity.')
                    pdw_regex='^\[ERROR\]\ Cannot\ set\ (.*)\ via\ (.*)\.\ Check\ permissions/connectivity\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Impossibile impostare %s via %s. Verifica permessi/connettività.' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] Ethernet '*' configured: '*', gateway '*'. Ethernet recovery is integrated into this container through NetworkManager.')
                    pdw_regex='^\[INFO\]\ Ethernet\ (.*)\ configured:\ (.*),\ gateway\ (.*)\.\ Ethernet\ recovery\ is\ integrated\ into\ this\ container\ through\ NetworkManager\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Ethernet %s configurata: %s, gateway %s. Recupero Ethernet integrato in questo container tramite NetworkManager.' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
                    fi
                    ;;
                '[WARN] Ethernet '*': no carrier. Wi-Fi/LAN remain active; waiting for the physical link without repeated resets.')
                    pdw_regex='^\[WARN\]\ Ethernet\ (.*):\ no\ carrier\.\ Wi\-Fi/LAN\ remain\ active;\ waiting\ for\ the\ physical\ link\ without\ repeated\ resets\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Ethernet %s: carrier assente. Wi-Fi/LAN mantenuti; attendo il collegamento fisico, nessun reset ciclico.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] Ethernet '*': '*'. Wi-Fi/LAN remain active; integrated recovery uses NetworkManager to restore the uplink.')
                    pdw_regex='^\[WARN\]\ Ethernet\ (.*):\ (.*)\.\ Wi\-Fi/LAN\ remain\ active;\ integrated\ recovery\ uses\ NetworkManager\ to\ restore\ the\ uplink\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Ethernet %s: %s. Wi-Fi/LAN mantenuti; Il recupero integrato gestisce il ripristino tramite NetworkManager.' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '[INFO] The '"'"'hosts:'"'"' line was replaced successfully through redirection.')
                    pdw_regex='^\[INFO\]\ The\ '"'"'hosts:'"'"'\ line\ was\ replaced\ successfully\ through\ redirection\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Riga '"'"'hosts:'"'"' sostituita con successo tramite reindirizzamento.'
                    fi
                    ;;
                '[ERROR] Cannot overwrite '*'. Insufficient permissions or read-only filesystem.')
                    pdw_regex='^\[ERROR\]\ Cannot\ overwrite\ (.*)\.\ Insufficient\ permissions\ or\ read\-only\ filesystem\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Impossibile sovrascrivere %s. Permessi insufficienti o file system RO.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Final verification: the configuration is correct.')
                    pdw_regex='^\[INFO\]\ Final\ verification:\ the\ configuration\ is\ correct\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Verifica finale: la configurazione è corretta.'
                    fi
                    ;;
                '[ERROR] The change succeeded, but final verification failed.')
                    pdw_regex='^\[ERROR\]\ The\ change\ succeeded,\ but\ final\ verification\ failed\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] La modifica ha avuto esito, ma la verifica finale ha fallito.'
                    fi
                    ;;
                '[ERROR] sed failed on the temporary file.')
                    pdw_regex='^\[ERROR\]\ sed\ failed\ on\ the\ temporary\ file\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Errore durante l'"'"'esecuzione di sed sul file temporaneo.'
                    fi
                    ;;
                '[FATAL] Missing file: '*'')
                    pdw_regex='^\[FATAL\]\ Missing\ file:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[FATAL] File mancante: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[WARN] The '"'"'hosts:'"'"' line is missing. Adding/replacing it.')
                    pdw_regex='^\[WARN\]\ The\ '"'"'hosts:'"'"'\ line\ is\ missing\.\ Adding/replacing\ it\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[WARN] Riga '"'"'hosts:'"'"' assente. Procedendo con l'"'"'aggiunta/sostituzione.'
                    fi
                    ;;
                '[INFO] Nsswitch is already correct. No changes needed.')
                    pdw_regex='^\[INFO\]\ Nsswitch\ is\ already\ correct\.\ No\ changes\ needed\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Nsswitch già corretto. Nessuna modifica necessaria.'
                    fi
                    ;;
                '[INFO] Nsswitch is incorrect. Replacing it with the new line.')
                    pdw_regex='^\[INFO\]\ Nsswitch\ is\ incorrect\.\ Replacing\ it\ with\ the\ new\ line\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Nsswitch non è corretto. Sostituendola con la nuova riga.'
                    fi
                    ;;
                '[INFO] Backup created successfully: '*'')
                    pdw_regex='^\[INFO\]\ Backup\ created\ successfully:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Backup creato correttamente: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Cannot create the backup. Aborting for safety.')
                    pdw_regex='^\[ERROR\]\ Cannot\ create\ the\ backup\.\ Aborting\ for\ safety\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Impossibile creare il backup. Aborto per sicurezza.'
                    fi
                    ;;
                '[ERROR] Update failed. The backup is available in '*.)
                    pdw_regex='^\[ERROR\]\ Update\ failed\.\ The\ backup\ is\ available\ in\ (.*)\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] L'"'"'aggiornamento è fallito. Il backup è disponibile in %s.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Update failed. Manual restoration is recommended.')
                    pdw_regex='^\[ERROR\]\ Update\ failed\.\ Manual\ restoration\ is\ recommended\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Aggiornamento fallito. Ripristino manuale consigliato.'
                    fi
                    ;;
                '[INFO] Nsswitch configuration updated and verified.')
                    pdw_regex='^\[INFO\]\ Nsswitch\ configuration\ updated\ and\ verified\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Configurazione Nsswitch aggiornato e verificato.'
                    fi
                    ;;
                '[ERROR] CONFIG_FILES is not defined!')
                    pdw_regex='^\[ERROR\]\ CONFIG_FILES\ is\ not\ defined!$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Variabile CONFIG_FILES non definita!'
                    fi
                    ;;
                '[INFO] Starting hostapd with configuration: '*'')
                    pdw_regex='^\[INFO\]\ Starting\ hostapd\ with\ configuration:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Avvio hostapd con config: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[INFO] Hostapd started and is responding (PID '*').')
                    pdw_regex='^\[INFO\]\ Hostapd\ started\ and\ is\ responding\ \(PID\ (.*)\)\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[INFO] Hostapd partito e risponde (PID %s).' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '[ERROR] Hostapd is not ready (exit code: '*')')
                    pdw_regex='^\[ERROR\]\ Hostapd\ is\ not\ ready\ \(exit\ code:\ (.*)\)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '[ERROR] Hostapd non pronto (exit code: %s)' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'All required packages are already installed.')
                    pdw_regex='^All\ required\ packages\ are\ already\ installed\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Tutti i pacchetti richiesti sono già installati.'
                    fi
                    ;;
                'Installing missing packages: '*'')
                    pdw_regex='^Installing\ missing\ packages:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Installo pacchetti mancanti: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '  ✔ Packages installed.')
                    pdw_regex='^\ \ ✔\ Packages\ installed\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ Pacchetti installati.'
                    fi
                    ;;
                '  ✖ ERROR: package installation failed. Continuing, but some features may fail.')
                    pdw_regex='^\ \ ✖\ ERROR:\ package\ installation\ failed\.\ Continuing,\ but\ some\ features\ may\ fail\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✖ ERRORE: installazione pacchetti fallita. Continuo ma alcune funzioni potrebbero fallire.'
                    fi
                    ;;
                'Wi-Fi MAC addresses are unavailable → retrying at the next boot')
                    pdw_regex='^Wi\-Fi\ MAC\ addresses\ are\ unavailable\ →\ retrying\ at\ the\ next\ boot$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'MAC WiFi non disponibili → rimando al prossimo boot'
                    fi
                    ;;
                ''*' is already configured: keeping its current value.')
                    pdw_regex='^(.*)\ is\ already\ configured:\ keeping\ its\ current\ value\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '%s già configurato: mantengo il valore esistente.' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                '  ✔ irq-pin.sh v1 installed/updated.')
                    pdw_regex='^\ \ ✔\ irq\-pin\.sh\ v1\ installed/updated\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ irq-pin.sh v1 installato/aggiornato.'
                    fi
                    ;;
                'irq-pin.sh v1 is already present; skipping it.')
                    pdw_regex='^irq\-pin\.sh\ v1\ is\ already\ present;\ skipping\ it\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'irq-pin.sh v1 già presente, salto.'
                    fi
                    ;;
                '  ✔ irq-affinity service created/updated (UNIT_VERSION=1).')
                    pdw_regex='^\ \ ✔\ irq\-affinity\ service\ created/updated\ \(UNIT_VERSION=1\)\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ Servizio irq-affinity creato/aggiornato (UNIT_VERSION=1).'
                    fi
                    ;;
                '  ✔ irq-affinity applied.')
                    pdw_regex='^\ \ ✔\ irq\-affinity\ applied\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ irq-affinity applicato.'
                    fi
                    ;;
                'Configuring Avahi on '*' for interfaces: '*'')
                    pdw_regex='^Configuring\ Avahi\ on\ (.*)\ for\ interfaces:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configurazione Avahi su %s per interfacce: %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                'ERROR: cannot install avahi-daemon')
                    pdw_regex='^ERROR:\ cannot\ install\ avahi\-daemon$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'ERRORE: impossibile installare avahi-daemon'
                    fi
                    ;;
                'ERROR: '*' not found')
                    pdw_regex='^ERROR:\ (.*)\ not\ found$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'ERRORE: %s non trovato' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'Configuration written. Restarting avahi-daemon...')
                    pdw_regex='^Configuration\ written\.\ Restarting\ avahi\-daemon\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configurazione scritta. Riavvio avahi-daemon...'
                    fi
                    ;;
                'Configuration completed on '*'')
                    pdw_regex='^Configuration\ completed\ on\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configurazione completata su %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'WARN: avahi-daemon restart failed on '*'')
                    pdw_regex='^WARN:\ avahi\-daemon\ restart\ failed\ on\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'WARN: avahi-daemon restart fallito su %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
                'Configuring Avahi reflector on '*' (interfaces: '*')...')
                    pdw_regex='^Configuring\ Avahi\ reflector\ on\ (.*)\ \(interfaces:\ (.*)\)\.\.\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Configuro Avahi reflector su %s (interfacce: %s)...' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                '  ✔ Configuration succeeded on localhost.')
                    pdw_regex='^\ \ ✔\ Configuration\ succeeded\ on\ localhost\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✔ Configurazione riuscita su localhost.'
                    fi
                    ;;
                '  ✖ WARN: configuration failed on localhost.')
                    pdw_regex='^\ \ ✖\ WARN:\ configuration\ failed\ on\ localhost\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE '  ✖ WARN: configurazione fallita su localhost.'
                    fi
                    ;;
                'A reboot is required to apply the kernel changes.')
                    pdw_regex='^A\ reboot\ is\ required\ to\ apply\ the\ kernel\ changes\.$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Reboot necessario per applicare le modifiche al kernel.'
                    fi
                    ;;
                'Consecutive failure '*': '*'')
                    pdw_regex='^Consecutive\ failure\ (.*):\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Fallimento consecutivo %s: %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    fi
                    ;;
                'LAN routes')
                    pdw_regex='^LAN\ routes$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'rotte LAN'
                    fi
                    ;;
                'DASHBOARD_PASSWORD is missing')
                    pdw_regex='^DASHBOARD_PASSWORD\ is\ missing$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'DASHBOARD_PASSWORD mancante'
                    fi
                    ;;
                'PIHOLE_PASSWORD is missing')
                    pdw_regex='^PIHOLE_PASSWORD\ is\ missing$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'PIHOLE_PASSWORD mancante'
                    fi
                    ;;
                'Missing web asset: '*'')
                    pdw_regex='^Missing\ web\ asset:\ (.*)$'
                    if [[ "$PDW_MESSAGE" =~ $pdw_regex ]]; then
                        printf -v PDW_MESSAGE 'Web asset mancante: %s' "${BASH_REMATCH[1]}"
                    fi
                    ;;
            esac
            ;;
    esac
    return 0
}

# IT: Solo output umano; non usare per generare configurazioni o dati di stato.
# EN: Human-facing output only; do not use to generate configuration or state data.
pdw_echo() {
    pdw_translate "$*"
    printf '%s\n' "$PDW_MESSAGE"
}

# IT: Legge la sola scelta di lingua da .env senza eseguirlo come codice shell.
# EN: Read only the language choice from .env without executing it as shell code.
pdw_load_language() {
    if [[ -z "${APP_LANGUAGE+x}" && -f "$1" ]]; then
        local pdw_line pdw_value
        while IFS= read -r pdw_line || [[ -n "$pdw_line" ]]; do
            if [[ "$pdw_line" =~ ^[[:space:]]*APP_LANGUAGE[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                pdw_value=${BASH_REMATCH[1]}
                pdw_value=${pdw_value%%#*}
                pdw_value=${pdw_value//[[:space:]]/}
                pdw_value=${pdw_value//\'/}
                pdw_value=${pdw_value//\"/}
                APP_LANGUAGE=$pdw_value
            fi
        done < "$1"
    fi
    APP_LANGUAGE=${APP_LANGUAGE:-it}
    case "$APP_LANGUAGE" in it|en) ;; *) pdw_echo "APP_LANGUAGE must be it or en" >&2; return 1 ;; esac
    export APP_LANGUAGE
}

pdw_translate ""
