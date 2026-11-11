[← README](../../README.md) · [Installazione](GUIDA.md) · [Hardware](HARDWARE.md) · [English](../en/NETWORK.md)

# DHCP, DNS e firewall

**File completi, regole esplicite e personalizzazione della rete.**

[DHCP/DNS](#dhcp-e-dns) · [Firewall](#iptables-ed-ebtables) · [Cambiare rete](#personalizzare-la-rete-di-esempio) · [Diagnostica](#verifica-senza-modifiche)

Questi file sono conservati come configurazioni modificabili, non sostituiti con un insieme ridotto di opzioni. Le regole originali restano nell’ordine originale. La copia sostituisce gli identificativi personali con esempi/variabili; non decide la rete dell’utente al suo posto.

## DHCP e DNS

File: `config/dhcp/dnsmasq.conf`.

| Direttiva | Significato e personalizzazione |
|---|---|
| `interface=br0` | Il servizio DHCP/DNS è associato al bridge LAN; le radio confluiscono nel bridge |
| `bind-dynamic` | Segue la disponibilità dell’interfaccia invece di richiedere che tutti gli indirizzi siano pronti all’avvio |
| `dhcp-range=10.42.0.50,10.42.0.250,12h` | Pool dinamico inclusivo e durata del lease. Cambiare entrambi gli estremi insieme alla subnet del router |
| `dhcp-option=3,10.42.0.1` | Router predefinito annunciato ai client |
| `dhcp-option=6,10.42.0.1` | DNS annunciato ai client; il client usa la porta standard 53 |
| `dhcp-option=tag:no_route,121,...` | Variante originale delle rotte classless per client marcati `no_route`: soltanto default route |
| `dhcp-option=tag:!no_route,121,...` | Variante originale per gli altri client: default route più rete aggiuntiva tramite il next-hop LAN |
| `dhcp-host=MAC,set:no_route,IP,NOME` | Prenotazione che assegna anche il tag usato per scegliere la variante 121 |
| `server=10.42.0.1#15353` | dnsmasq inoltra le richieste a Pi-hole sulla porta dedicata, senza competere per la 53 |
| `no-resolv` | Non legge resolver dell’host, evitando che l’inoltro ricada su se stesso |
| `domain=local`, `local=/local/` | Dominio locale originale; cambiarlo in modo coerente se si sceglie un altro dominio |
| `rebind-domain-ok=/nat/` | Eccezione originale per quel suffisso, non una disattivazione generale della protezione |
| `expand-hosts` | Espande i nomi locali usando il dominio configurato |
| `dhcp-leasefile=...` | Stato dinamico dei lease, montato dall’host; inizialmente vuoto |
| `log-queries`, `log-dhcp` | Log DNS e DHCP: utili alla diagnosi ma contengono dati dell’utente, quindi esclusi dalla pubblicazione |

Tutte le **25 prenotazioni** originali restano come righe di esempio commentate, con MAC fittizi e nomi `example-device-NN`. I tag `set:no_route` sono conservati. Prima di attivarne una, sostituire MAC, IP e nome; non usare i MAC di esempio su dispositivi reali. Le assegnazioni devono essere univoche e coerenti con eventuali IP statici.

Le due varianti originali dell’opzione 121 sono conservate e commentate finché il proprietario non imposta la rete e il next-hop reali. Nell’esempio `192.0.2.0/24` è uno spazio riservato alla documentazione: va sostituito. Se si abilita l’opzione 121, includere la default route nella stessa istanza; alcuni client che ricevono 121 ignorano l’opzione router 3. Non spezzare l’elenco in due direttive 121 concorrenti. Il tag `no_route` significa “niente rotta aggiuntiva”, non “nessun gateway”.

`server-routes.sh` configura invece rotte **sul router**, non sui client DHCP. `EXTRA_ROUTES` mantiene la possibilità di indicare `RETE/CIDR,GATEWAY;RETE/CIDR,GATEWAY`. Una route annunciata ai client e una route installata sul router hanno ruoli distinti: verificare next-hop e percorso di ritorno.

## Iptables ed ebtables

File: `config/iptables/iptables-rules.sh`. Sono conservati tutti i **49 comandi originali** di regole/tuning; le due serie per dispositivi specifici sono attivate compilando `ISOLATED_DEVICE_1_IP` e `ISOLATED_DEVICE_2_IP`. Lasciarli vuoti disattiva solo quei due blocchi.

| Blocco originale | Cosa fa e perché l’ordine conta |
|---|---|
| 1, mangle `-N/-F/-C/-I` | Crea, svuota e aggancia soltanto `pi-dock-wifi-mangle`; non esegue un flush globale della tabella |
| MSS clamp | Per pacchetti TCP SYN/RST applica `TCPMSS --clamp-mss-to-pmtu`, utile con MTU ridotte di tunnel/exit node |
| 1, filter | Crea/svuota la catena dedicata e la aggancia a FORWARD; le altre catene host restano fuori da questo flush |
| 1, nat | Catena dedicata in PREROUTING per i reindirizzamenti DNS |
| Pulizia MASQUERADE | Rimuove la precedente regola specifica su uplink e `wt0` prima di aggiungerla di nuovo |
| Pulizia INPUT | Rimuove le precedenti regole delle sole porte/interfacce elencate; non cambia la policy generale INPUT |
| 2.1 | Accetta `RELATED,ESTABLISHED`, cioè risposte e traffico correlato a connessioni già note |
| DHCP rogue | Ebtables blocca risposte UDP sorgente 67 inoltrate a livello bridge. Il DHCP generato localmente non attraversa questo FORWARD |
| 2.2 | Ammette nuove connessioni uplink→LAN. La topologia originale delega il filtraggio perimetrale al modem a monte |
| 2.3 e 2.4 | Per ciascun IP configurato: permette traffico da/verso NetBird, permette destinazioni LAN, poi rifiuta il restante traffico sorgente. Il REJECT precede l’ACCEPT generale LAN→uplink |
| 2.5 | Consente LAN→uplink per gli altri dispositivi |
| 2.6 | Consente inoltro fra uplink, `wt0` e `br0`; le ACL dei peer NetBird restano una configurazione distinta |
| 2.7 | Mantiene INPUT per loopback e connessioni stabilite; apre DNS Pi-hole e le porte HTTP indicate sulle interfacce originali |
| 3.1 | Masquerade sull’uplink: l’indirizzo sorgente diventa quello dell’interfaccia d’uscita |
| 3.2 | Masquerade su `wt0`: i peer vedono la sorgente del router VPN |
| 3.3 | Redirect DNS TCP/UDP in ingresso da `wt0`, porta 53→15353. Non cambia la porta DNS configurata nei client |
| 3.4 | Spazio per annotare regole di dispositivi gestite da altri componenti, senza duplicarle nel router |
| 4 | Conserva timeout conntrack UDP 120/180 secondi e tuning GRO su Ethernet/bridge; ethtool è tollerante se l’hardware non supporta l’opzione |

La porta HTTP 80 nelle regole è conservata dall’originale: non equivale alla porta della dashboard 8888 o a Pi-hole 8090. `INPUT` riguarda servizi del router, `FORWARD` traffico che lo attraversa, `PREROUTING` la trasformazione prima dell’instradamento e `POSTROUTING` quella successiva. Un ACCEPT di FORWARD non apre automaticamente un servizio locale.

La regola ebtables originale interessa FORWARD del bridge host, non una nuova catena isolata; la conservazione non va interpretata come un cambio di politica. Valutarla se l’host ha altri bridge. Le restrizioni per IP dipendono dall’identità di rete configurata: associare prenotazioni corrette e non considerarle sostitutive di VLAN, autenticazione o ACL complete.

## Personalizzare la rete di esempio

Una rete diversa da `10.42.0.0/24` richiede aggiornamenti coerenti:

| File | Valori da adeguare |
|---|---|
| `config/dhcp/dnsmasq.conf` | Pool, gateway, DNS, prenotazioni e next-hop delle rotte DHCP |
| `config/start-scripts/dnsmasq_start.sh` | Indirizzo/prefisso di `br0` e controllo di disponibilità |
| `config/entrypoint.sh` | Resolver fissato durante l’inizializzazione |
| `config/healthcheck.sh` | `BRIDGE_ADDRESS` atteso |
| `config/dhcp/dhclient.conf` | Resolver del file di riferimento |
| `config/iptables/iptables-rules.sh` | Subnet LAN delle restrizioni; interfacce uplink e VPN |
| `.env` | IP dei due dispositivi isolati e rotte aggiuntive |
| `config/recovery/config.json` | Rete/gateway **dell’uplink**, separati dalla LAN |

### Controllo prima dell’avvio

- Rete LAN di esempio `10.42.0.0/24`, gateway `10.42.0.1`, pool, prenotazioni e next-hop.
- Interfacce `eth0`, `br0`, `wlan0`, `wlan1`, `wt0` e capacità reali delle radio.
- I due IP opzionali dei dispositivi isolati, senza indirizzi di persone estranee.
- Rotte DHCP opzione 121, tag `no_route`, rotte del router e percorso di ritorno.
- Resolver, dominio locale, eccezioni DNS e porte effettivamente esposte.
- Policy del modem/firewall perimetrale, senza assumere che questa copia l’abbia sostituita.

## Verifica senza modifiche

```sh
iptables-save
iptables -t nat -S
iptables -t mangle -S
ebtables -L
ip -4 route
ss -lntup
```

> [!NOTE]
> Questi output possono contenere indirizzi e configurazioni personali: conservarli privatamente. Non usare flush generali per rimuovere o “ripulire” il progetto.
