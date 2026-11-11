[← README](../../README.md) · [Kernel](KERNEL.md) · [Hardware](HARDWARE.md) · [DHCP e firewall](RETE.md) · [English](../en/GUIDE.md)

# Installazione e configurazione

**Percorso:** preparare → configurare → costruire → avviare → verificare.

[Requisiti](#prima-di-iniziare) · [Installazione](#installazione-passo-per-passo) · [Variabili](#variabili-compose) · [File](#mappa-dei-file) · [Lingue](#lingua-di-interfaccia-e-log) · [Manutenzione](#aggiornamenti-e-arresto)

## Prima di iniziare

| Serve | Verifica |
|---|---|
| Linux ARM64 e kernel compatibile | Due radio rilevate, modalità AP e combinazioni supportate in `iw list` |
| Docker Engine + Compose | `docker version` e `docker compose version` |
| Uplink Ethernet gestito dall’host | Profilo NetworkManager e gateway funzionanti |
| Accesso di recupero | Console o collegamento locale disponibile |
| Porte libere | Controllare i listener con `ss -lntup` |

Il riferimento hardware è descritto nella [distinta](HARDWARE.md). La [configurazione del kernel](HARDWARE.md#configurazione-del-kernel-inclusa) è inclusa; per preparare e installare il binario seguire la **[guida kernel](KERNEL.md)** prima di avviare lo stack. Docker non sostituisce un driver radio mancante nell’host.

> [!IMPORTANT]
> I container condividono la rete host; il principale è privilegiato e modifica interfacce, bridge, firewall e resolver. La topologia originale ammette uplink→LAN e delega il filtro perimetrale al modem a monte. Non avviare lo stack in parallelo a un’altra copia sullo stesso host.

### Porte e responsabilità

| Porta | Servizio | Uso |
|---|---|---|
| `53` TCP/UDP | dnsmasq | DNS della LAN |
| `67` UDP | dnsmasq | Unico DHCP della LAN |
| `15353` TCP/UDP | Pi-hole | DNS filtrato, chiamato da dnsmasq |
| `8090` HTTP | Pi-hole | Pannello e API |
| `8888` HTTP | nginx | Dashboard e accesso al terminale |
| `3000`, solo loopback | ttyd | Backend del terminale, tramite nginx |

## Installazione passo per passo

### 1. Preparare la configurazione

Dalla cartella del progetto:

```sh
cp .env.example .env
chmod 600 .env
```

Compilare **tutti i `CHANGE_ME`**: password distinte, SSID e UUID WPS. Generare l’UUID una volta con `uuidgen`, oppure:

```sh
python3 -c 'import uuid; print(uuid.uuid4())'
```

Per il WPS comune le due radio condividono UUID, SSID e password. Impostare `APP_LANGUAGE=it` oppure `en`.

> [!NOTE]
> `.env` usa la sintassi di Compose, non quella di uno script. Per password contenenti `$` usare valori letterali fra apici singoli. `docker compose config` può mostrare i segreti: per il controllo usare `--quiet`.

### 2. Definire rete e uplink

La LAN predefinita è `192.168.4.0/24`, router `192.168.4.1`, come nel progetto originale e nei suoi script di avvio e controllo. Deve essere distinta dalla rete dell’uplink. Per cambiarla, seguire l’elenco delle [occorrenze da aggiornare](RETE.md#personalizzare-la-rete-di-esempio): modificare una sola riga non basta.

```sh
cp config/recovery/config.json.example config/recovery/config.json
nmcli -f NAME,UUID,TYPE,DEVICE connection show
```

In `config.json` impostare interfaccia Ethernet, UUID del profilo NetworkManager, rete IPv4 e gateway attesi. Il worker usa il profilo esistente dell’host: **non avvia un secondo client DHCP** e non è un watchdog UPS.

### 3. Preparare lo stato persistente

```sh
mkdir -p state/uplink logs services/pihole/etc-pihole services/ttyd/home config/dhcp/leases
touch config/dhcp/leases/dnsmasq.leases
```

Le deny list sono inizialmente vuote. Non copiare credenziali, dati Pi-hole o lease da un’installazione altrui. Le 25 prenotazioni originali sono conservate come esempi anonimi commentati.

### 4. Verificare la chiave SSH

Il terminale usa `StrictHostKeyChecking=yes`. Sul router confrontare le due fingerprint:

```sh
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
ssh-keyscan -t ed25519 127.0.0.1 > /tmp/router_known_hosts
ssh-keygen -lf /tmp/router_known_hosts
```

**Solo se corrispondono**, salvare il file:

```sh
cp /tmp/router_known_hosts config/ttyd/router_known_hosts
```

L’esempio corrisponde a `SSH_HOST=127.0.0.1`, porta 22. Se la destinazione cambia, acquisire e verificare la chiave della destinazione effettiva. `ssh-keyscan` raccoglie una chiave: da solo non ne dimostra l’identità. Non usare chiavi private nel file.

### 5. Preparare l’host, se necessario

Leggere prima `start_system.sh` e [config.txt](HARDWARE.md#configurazione-del-boot). Lo script conserva le fasi locali dell’originale: pacchetti, nomi persistenti delle radio, overlay, frequenze mancanti, IRQ/NAPI, rfkill, NetworkManager e Avahi.

```sh
bash start_system.sh
```

> [!WARNING]
> Eseguirlo **sul router**, da una sessione di recupero: può interrompere la rete e riavviare il Raspberry se modifica il boot. Non eseguirlo sul Mac o sul NAS. Non configura backup, altri host o spegnimenti UPS.

### 6. Costruire e avviare

```sh
docker compose config --quiet
docker compose build
docker compose up -d
docker compose ps
```

La build riguarda `pi-dock-wifi` e `ttyd`. Pi-hole usa direttamente **`pihole/pihole:2026.10.1`**: Compose scarica l’immagine ufficiale se manca.

| Aprire dalla LAN | Credenziale |
|---|---|
| `http://192.168.4.1:8888` | `DASHBOARD_PASSWORD` |
| `http://192.168.4.1:8090/admin/` | `PIHOLE_PASSWORD` |

Il terminale passa da `/terminal/`; ttyd non viene esposto direttamente. La pagina contiene il riferimento mDNS `pi-dock-wifi.local`: usare un hostname coerente oppure adattare quel riferimento prima della build. Per l’amministrazione remota usare VPN o un reverse proxy TLS gestito dall’installatore.

## Variabili Compose

| Variabile | Funzione |
|---|---|
| `APP_LANGUAGE` | `it`/`en`: interfaccia, login, CGI e log di avvio/runtime |
| `SSID1`, `SSID2` | SSID delle due radio; uguali per WPS comune |
| `WPA_PASSPHRASE1`, `WPA_PASSPHRASE2` | Password WPA di 8–63 caratteri, senza ritorni a capo |
| `DASHBOARD_PASSWORD` | Accesso a dashboard e terminale integrato |
| `PIHOLE_PASSWORD` | API/pannello Pi-hole, condivisa con il CGI della dashboard |
| `SSH_USER`, `SSH_HOST`, `SSH_PASSWORD` | Destinazione e credenziali del terminale |
| `WPS_UUID` | UUID unico e condiviso fra le due radio |
| `LOCAL_DOMAIN` | Dominio web di Pi-hole; non crea DNS pubblici o certificati |
| `PIHOLE_EXTRA_DNS` | Direttive aggiuntive Pi-hole; default `stop-dns-rebind` |
| `EXTRA_ROUTES` | Rotte del router in formato `RETE/CIDR,GATEWAY;...` |
| `ISOLATED_DEVICE_1_IP`, `ISOLATED_DEVICE_2_IP` | Attivano i due blocchi originali per dispositivi specifici; vuoti per default |
| `TRUSTED_PROXY_IP` | Proxy autorizzato a dichiarare HTTPS per il cookie; vuoto per accesso diretto |

Interfacce (`wlan0`, `wlan1`, `eth0`, `wt0`), paese/canali, porte, fuso `Europe/Rome` e rete d’esempio rimangono espliciti nei file, come nell’originale. HT/VHT/HE e `force_ht40` richiedono radio e regolamentazione compatibili; vedere [hardware](HARDWARE.md) e [rete](RETE.md).

## Mappa dei file

Consultazione tecnica per area. I file runtime sono già pronti; non serve una fase npm.

<details>
<summary><strong>Immagini e avvio</strong></summary>

| Percorso | Funzione |
|---|---|
| `docker-compose.yml` | I tre servizi, dipendenze, privilegi, rete host, variabili e bind mount |
| `Dockerfile` | Compila hostapd con patch force-HT40 e fastfetch; installa runtime, nginx/fcgiwrap; incorpora CGI e HTML. Il blocco finale aggiunge le pagine inglesi senza sostituire la struttura originale |
| `start_system.sh` | Pacchetti host, nomi persistenti radio, overlay del boot, frequenze mancanti, IRQ/NAPI, rfkill, NetworkManager e Avahi locale. Nessun provisioning di altri host o backup |
| `services/ttyd/Dockerfile` | Dockerfile separato con struttura originale e commenti bilingui: scarica ttyd 1.7.7, compila passh, incorpora i launcher SSH e ttyd |

</details>

<details>
<summary><strong>Rete e servizi</strong></summary>

| Percorso | Funzione |
|---|---|
| `config/entrypoint.sh` | Fasi INIT/runtime, bridge, hostapd, DHCP, web, processi di controllo e cleanup; controlla lingua e segnaposto prima di proseguire |
| `config/healthcheck.sh` | Controlli socket/processi, tentativi di riparazione, contatori e riavvio come ultima risorsa |
| `config/logger.sh` | Timestamp, log, rotazione e sincronizzazione fra processi |
| `config/start-scripts/start_hostapd.sh` | Avvio delle due istanze/configurazioni radio, attese e log |
| `config/start-scripts/dnsmasq_start.sh` | Configurazione IP br0, lancio DHCP/DNS, PID, rotazione e recupero senza reset del bridge |
| `config/start-scripts/server-routes.sh` | Applica le sole rotte esplicitamente configurate, con `ip route replace` |
| `config/start-scripts/monitor_ip.sh` | Supervisione IP/uplink e worker di recupero, senza nuovi demoni DHCP |
| `config/start-scripts/check_nsswitch.sh` | Coerenza risoluzione nomi dell’host |
| `config/hostapd/*.template` | `interface`, `bridge`, `driver`, SSID, paese/canale, HT/VHT/HE, WPA e WPS delle due radio |
| `config/hostapd/4w.deny`, `6w.deny` | Deny list persistite sul filesystem host, vuote alla distribuzione |
| `config/dhcp/dnsmasq.conf` | `interface=br0`, pool/lease, opzioni DHCP 3/6/121, forward DNS a 15353, dominio locale, prenotazioni e log |
| `config/dhcp/dhclient.conf` | Opzioni del client DHCP e DNS di riferimento; l’uplink resta gestito da NetworkManager |
| `config/iptables/iptables-rules.sh` | Catene dedicate mangle/filter/NAT, MSS clamp, DHCP rogue, routing uplink/LAN/NetBird, client isolati, masquerade e tuning UDP |
| `config/recovery/recovery.py` | Letture link/indirizzo/route, decisioni con conferma/backoff, chiamate al profilo NetworkManager specifico |
| `config/recovery/worker.py` | Lock, selezione UUID non ambigua e ciclo del recupero Ethernet |
| `config/recovery/config.json.example` | Solo schema d’esempio: ruolo Ethernet, interfaccia, UUID, rete/gateway attesi, grace period |
| `config/ttyd/sshconnect` | Connessione SSH con verifica chiave host, credenziali da ambiente/stato privato |
| `config/ttyd/start-ttyd` | ttyd in loopback:3000 con verifica Origin e scrittura terminale |

</details>

<details>
<summary><strong>Dati, lingue e hardware</strong></summary>

| Percorso | Funzione |
|---|---|
| `config/dhcp/leases` | Lease runtime: da creare vuoti, non distribuire quelli di altri utenti |
| `config/ttyd/router_known_hosts` | Chiavi pubbliche host verificate, create dall’installatore; escluso da Git |
| `services/pihole/etc-pihole` | Dati Pi-hole, password/DB/lista client: privati e non distribuiti |
| `services/ttyd/home` | Directory persistente del terminale originale, inizialmente vuota |
| `state/uplink` | Stato e backoff del recupero Ethernet, creati dal worker; non eliminare mentre lavora |
| `logs` | Log runtime, ruotati; nessuno storico personale incluso |
| `i18n/en.json` | Catalogo italiano→inglese dei testi dell’interfaccia |
| `i18n/en` | HTML e CGI inglesi generati dal Dockerfile originale |
| `hardware/boot/config.reference.txt` | Riferimento boot tecnico, da leggere prima di adattarlo al proprio hardware |
| `hardware/kernel/config.reference` | `.config` completo del kernel `6.18.60wifi+`, verificato rispetto al modulo installato; configurazione di compilazione distinta dal file di boot |
| `hardware/3d` | Quattro STL e tre SCAD forniti dal proprietario |
| `config/i18n.sh` | Testi dei log italiani/inglesi e selezione sicura della lingua; nessun processo esterno per riga |
| `config/recovery/runtime_i18n.py` | Traduzione dei messaggi diagnostici Python; codici di stato invariati |
| `i18n/logs.json`, `i18n/en.json` | Cataloghi di riferimento delle traduzioni; i file runtime pronti sono già distribuiti |

</details>

## Lingua di interfaccia e log

```dotenv
APP_LANGUAGE=en
```

```sh
docker compose up -d --force-recreate
```

Un semplice restart non aggiorna le variabili Compose. La scelta copre nuove righe di avvio, healthcheck, DNS/DHCP, hostapd, bootstrap web e recupero Ethernet.

- `config/i18n.sh` traduce i messaggi Bash senza un processo esterno per riga.
- `config/recovery/runtime_i18n.py` gestisce la diagnostica Python.
- I commenti sono bilingui e le opzioni disattivate restano leggibili.
- JSON/codici macchina, output nativo dei programmi terzi e sessione SSH mantengono il proprio formato; lo storico non viene riscritto.
- `start_system.sh` legge la lingua da `.env` come dati; una variabile già esportata ha precedenza.

Le traduzioni e i cataloghi di riferimento sono inclusi. Per personalizzare i testi, modificare i file runtime interessati: HTML italiano nel Dockerfile, risorse inglesi in `i18n/en`, log Bash in `config/i18n.sh`, diagnostica Python in `runtime_i18n.py`. Non occorrono Node.js, npm o generatori per installare o avviare la release.

## Aggiornamenti e arresto

```sh
# Immagine ufficiale Pi-hole: il tag resta quello dichiarato nel Compose.
docker compose pull pihole

# Immagini custom: ricompilazione con le patch del progetto.
docker compose build --pull pi-dock-wifi ttyd
docker compose up -d
```

Per cambiare versione Pi-hole aggiornare prima il tag nel Compose e leggere le note della release. Un pull da solo non ricompila il codice custom. I metodi di build originali sono conservati e includono riferimenti upstream mobili: non è dichiarata riproducibilità binaria.

```sh
docker compose down
```

Questo arresta i container, non cancella i dati persistenti. Durante la normale manutenzione conservare `.env`, deny list, lease e directory Pi-hole. Backup e spegnimento elettrico dell’homelab restano fuori dal progetto pubblico.

## Se qualcosa non funziona

| Sintomo | Primo controllo |
|---|---|
| Container principale in riavvio | `docker compose logs --tail=100 pi-dock-wifi`; segnaposto `.env`, radio e porte |
| Wi-Fi assente | `iw dev`, driver/firmware e configurazione radio; attendere eventuale CAC DFS |
| Client senza IP | dnsmasq, listener 67, bridge e presenza di altri DHCP |
| DNS non risolve | Catena dnsmasq:53 → Pi-hole:15353 → resolver upstream |
| Terminale non si apre | Chiave host verificata, credenziali SSH e log `ttyd` |
| Recupero uplink sospeso | UUID, interfaccia e rete/gateway di `config.json` |

Gli output possono contenere nomi, IP, query e credenziali: conservarli privatamente. Per analizzare il firewall usare i [comandi di sola lettura](RETE.md#verifica-senza-modifiche).
