#!/bin/bash

# Critical rule failures must reach entrypoint; optional tuning stays optional.
# Traduzione / Translation: Gli errori delle regole critiche devono raggiungere l’entrypoint; il tuning opzionale resta non fatale
set -eo pipefail

# =======================================================================
# --- 1. PREPARAZIONE, PULIZIA E TABELLA MANGLE ---
# Traduzione / Translation: 1. PREPARATION, CLEANUP AND MANGLE TABLE
# =======================================================================

# Catena MANGLE dedicata invece di flush globale:
# evita di cancellare eventuali regole di Docker/tc/altri servizi.
# Traduzione / Translation: Use a dedicated MANGLE chain instead of globally flushing Docker, tc or other service rules

iptables -t mangle -N pi-dock-wifi-mangle 2>/dev/null || iptables -t mangle -S pi-dock-wifi-mangle >/dev/null
iptables -t mangle -F pi-dock-wifi-mangle
iptables -t mangle -C FORWARD -j pi-dock-wifi-mangle 2>/dev/null || iptables -t mangle -I FORWARD 1 -j pi-dock-wifi-mangle

# MSS CLAMPING - fondamentale per Exit Node / NetBird.
# Traduzione / Translation: MSS CLAMPING is important for exit-node and NetBird paths
iptables -t mangle -A pi-dock-wifi-mangle -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu


# -----------------------------------------------------------------------
# Catena FILTER
# Traduzione / Translation: FILTER chain
# -----------------------------------------------------------------------

iptables -N pi-dock-wifi-filter 2>/dev/null || iptables -S pi-dock-wifi-filter >/dev/null
iptables -F pi-dock-wifi-filter
iptables -C FORWARD -j pi-dock-wifi-filter 2>/dev/null || iptables -I FORWARD 1 -j pi-dock-wifi-filter


# -----------------------------------------------------------------------
# Catena NAT
# Traduzione / Translation: NAT chain
# -----------------------------------------------------------------------

iptables -t nat -N pi-dock-wifi-nat 2>/dev/null || iptables -t nat -S pi-dock-wifi-nat >/dev/null
iptables -t nat -F pi-dock-wifi-nat
iptables -t nat -C PREROUTING -j pi-dock-wifi-nat 2>/dev/null || iptables -t nat -I PREROUTING 1 -j pi-dock-wifi-nat


# -----------------------------------------------------------------------
# Pulizia chirurgica MASQUERADE
# Traduzione / Translation: Targeted MASQUERADE cleanup
# -----------------------------------------------------------------------

iptables -t nat -D POSTROUTING -o "$INTERNET" -j MASQUERADE 2>/dev/null || true
iptables -t nat -D POSTROUTING -o wt0 -j MASQUERADE 2>/dev/null || true


# -----------------------------------------------------------------------
# Pulizia chirurgica INPUT
# Traduzione / Translation: Targeted INPUT cleanup
# -----------------------------------------------------------------------

iptables -D INPUT -i wt0 -p udp --dport 15353 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -i wt0 -p tcp --dport 15353 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -i wt0 -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -i br0 -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -i br0 -p udp --dport 15353 -j ACCEPT 2>/dev/null || true


# =======================================================================
# --- 2. REGOLE DI FILTRO ---
# Traduzione / Translation: 2. FILTER RULES
# =======================================================================

# -----------------------------------------------------------------------
# 2.1 Connessioni già stabilite
# Traduzione / Translation: 2.1 Already established connections
# -----------------------------------------------------------------------

iptables -A pi-dock-wifi-filter -m state --state RELATED,ESTABLISHED -j ACCEPT


# -----------------------------------------------------------------------
# Protezione DHCP rogue
# Traduzione / Translation: Rogue DHCP protection
# -----------------------------------------------------------------------
#
# Le risposte del dnsmasq locale non attraversano FORWARD.
# Vengono bloccate solo risposte DHCP inoltrate da altri dispositivi.
# Traduzione / Translation: Local dnsmasq replies do not cross FORWARD; block only DHCP replies forwarded from other devices

ebtables -D FORWARD -p IPv4 --ip-proto udp --ip-sport 67 -j DROP 2>/dev/null || true
ebtables -A FORWARD -p IPv4 --ip-proto udp --ip-sport 67 -j DROP


# -----------------------------------------------------------------------
# 2.2 UPSTREAM ROUTER -> LAN
# Traduzione / Translation: 2.2 ROUTER A MONTE → LAN
# -----------------------------------------------------------------------
#
# Topologia:
# Traduzione / Translation: Topology
#
# UPSTREAM ROUTER
#   br0  = 192.0.2.1
#   eth1 = collegamento Ethernet verso pi-router
# Traduzione / Translation: Router a monte: br0 192.0.2.1; eth1 collega questo router tramite Ethernet
#
# THIS ROUTER
#   $INTERNET / eth0 = 192.0.2.2
#   br0              = 192.168.4.1
# Traduzione / Translation: Questo router: uplink $INTERNET/eth0 192.0.2.2; LAN br0 192.168.4.1
#
# Il modem è il firewall perimetrale e inoltra verso la LAN i servizi
# pubblicati su Internet. Questa regola consente anche NUOVE connessioni
# provenienti dal modem verso i servizi della LAN.
# Traduzione / Translation: The modem is the perimeter firewall and forwards published Internet services to the LAN. This rule
# IT/EN: also permits NEW modem-to-LAN connections.

iptables -A pi-dock-wifi-filter -i "$INTERNET" -o br0 -j ACCEPT


# Original device rules: configure the placeholder to activate this block.
# Traduzione / Translation: Regole originali del dispositivo: compilare il segnaposto per attivare il blocco
if [[ -n "${ISOLATED_DEVICE_1_IP:-}" ]]; then
# -----------------------------------------------------------------------
# 2.3 Webcam ${ISOLATED_DEVICE_1_IP}
# Traduzione / Translation: 2.3 Videocamera ${ISOLATED_DEVICE_1_IP}
# -----------------------------------------------------------------------
#
# La webcam deve:
# - essere raggiungibile dalla LAN;
# - essere raggiungibile da NetBird, incluso HTTP/80;
# - poter comunicare con LAN e NetBird;
# - NON poter uscire liberamente su Internet.
# Traduzione / Translation: The camera must be reachable from LAN and NetBird, including HTTP/80; it may communicate with
# IT/EN: LAN/NetBird but must not access the Internet freely.
#
# Il REJECT deve precedere la regola generale LAN -> Internet.
# Traduzione / Translation: The REJECT must precede the general LAN-to-Internet acceptance

iptables -A pi-dock-wifi-filter -i wt0 -d "${ISOLATED_DEVICE_1_IP}" -j ACCEPT
iptables -A pi-dock-wifi-filter -o wt0 -s "${ISOLATED_DEVICE_1_IP}" -j ACCEPT
iptables -A pi-dock-wifi-filter -s "${ISOLATED_DEVICE_1_IP}" -d 192.168.4.0/24 -j ACCEPT
iptables -A pi-dock-wifi-filter -s "${ISOLATED_DEVICE_1_IP}" -j REJECT


fi

# Original device rules: configure the placeholder to activate this block.
# Traduzione / Translation: Regole originali del dispositivo: compilare il segnaposto per attivare il blocco
if [[ -n "${ISOLATED_DEVICE_2_IP:-}" ]]; then
# -----------------------------------------------------------------------
# 2.4 Webcam ${ISOLATED_DEVICE_2_IP}
# Traduzione / Translation: 2.4 Videocamera ${ISOLATED_DEVICE_2_IP}
# -----------------------------------------------------------------------

iptables -A pi-dock-wifi-filter -i wt0 -d "${ISOLATED_DEVICE_2_IP}" -j ACCEPT
iptables -A pi-dock-wifi-filter -o wt0 -s "${ISOLATED_DEVICE_2_IP}" -j ACCEPT
iptables -A pi-dock-wifi-filter -s "${ISOLATED_DEVICE_2_IP}" -d 192.168.4.0/24 -j ACCEPT
iptables -A pi-dock-wifi-filter -s "${ISOLATED_DEVICE_2_IP}" -j REJECT


fi

# -----------------------------------------------------------------------
# 2.5 LAN -> UPSTREAM ROUTER / INTERNET
# Traduzione / Translation: 2.5 LAN → ROUTER A MONTE / INTERNET
# -----------------------------------------------------------------------
#
# IMPORTANTE: questa regola viene DOPO i REJECT delle webcam.
# Traduzione / Translation: This rule must follow the camera REJECT rules
#
# Permette ai normali dispositivi LAN:
# - accesso al pi-modem 192.0.2.1;
# - navigazione Internet tramite il pi-modem.
# Traduzione / Translation: Allow ordinary LAN clients to reach the example upstream modem at 192.0.2.1 and use it for Internet
# IT/EN: access

iptables -A pi-dock-wifi-filter -i br0 -o "$INTERNET" -j ACCEPT


# -----------------------------------------------------------------------
# 2.6 Traffico NetBird
# Traduzione / Translation: 2.6 NetBird traffic
# -----------------------------------------------------------------------
#
# Le ACL NetBird restano il livello di autorizzazione
# applicato alla tailnet.
# Traduzione / Translation: NetBird ACLs remain the authorization layer applied to the tailnet

iptables -A pi-dock-wifi-filter -i "$INTERNET" -o wt0 -j ACCEPT
iptables -A pi-dock-wifi-filter -i wt0 -o "$INTERNET" -j ACCEPT
iptables -A pi-dock-wifi-filter -i wt0 -o br0 -j ACCEPT
iptables -A pi-dock-wifi-filter -i br0 -o wt0 -j ACCEPT


# -----------------------------------------------------------------------
# 2.7 INPUT - traffico destinato al pi-router
# Traduzione / Translation: 2.7 INPUT: traffic addressed to this router
# -----------------------------------------------------------------------

iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -A INPUT -i lo -j ACCEPT
iptables -C INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT


# DNS Pi-hole da NetBird.
# I client interrogano il DNS del router su 53; il NAT redirige verso 15353.
# Traduzione / Translation: Pi-hole DNS from NetBird: clients use router port 53 and NAT redirects to 15353

iptables -A INPUT -i wt0 -p udp --dport 15353 -j ACCEPT
iptables -A INPUT -i wt0 -p tcp --dport 15353 -j ACCEPT


# HTTP locale del router.
# NON riguarda HTTP/80 delle webcam, che passa attraverso FORWARD.
# Traduzione / Translation: Router-local HTTP; camera HTTP/80 instead crosses FORWARD

iptables -A INPUT -i wt0 -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -i br0 -p tcp --dport 80 -j ACCEPT


# DNS Pi-hole dalla LAN.
# Traduzione / Translation: Pi-hole DNS from LAN

iptables -A INPUT -i br0 -p udp --dport 15353 -j ACCEPT


# =======================================================================
# --- 3. REGOLE NAT ---
# Traduzione / Translation: 3. NAT RULES
# =======================================================================

# -----------------------------------------------------------------------
# 3.1 MASQUERADE generale verso UPSTREAM ROUTER / Internet
# Traduzione / Translation: 3.1 General masquerade towards upstream router / Internet
# -----------------------------------------------------------------------

iptables -t nat -A POSTROUTING -o "$INTERNET" -j MASQUERADE


# -----------------------------------------------------------------------
# 3.2 MASQUERADE LAN -> NetBird
# Traduzione / Translation: 3.2 LAN-to-NetBird masquerade
# -----------------------------------------------------------------------
#
# I peer NetBird vedono il traffico proveniente dalla LAN come
# proveniente dal pi-router NetBird.
# Traduzione / Translation: NetBird peers see LAN traffic with the router’s NetBird source address

iptables -t nat -A POSTROUTING -o wt0 -j MASQUERADE


# -----------------------------------------------------------------------
# 3.3 DNS NetBird -> Pi-hole
# Traduzione / Translation: 3.3 DNS NetBird → Pi-hole
# -----------------------------------------------------------------------
#
# Il DNS del router è distribuito ai peer dalla configurazione NetBird.
# Pi-hole ascolta localmente sulla porta 15353.
# Traduzione / Translation: NetBird configuration distributes router DNS to peers; Pi-hole listens locally on port 15353

iptables -t nat -A pi-dock-wifi-nat -i wt0 -p udp --dport 53 -j REDIRECT --to-ports 15353
iptables -t nat -A pi-dock-wifi-nat -i wt0 -p tcp --dport 53 -j REDIRECT --to-ports 15353

# DNS NetBird: stesso ingresso standard 53 e listener Pi-hole 15353.
# Traduzione / Translation: NetBird DNS keeps standard incoming port 53 and Pi-hole listener 15353


# Le regole VPN locali sono mantenute qui, sul router.
# Le policy tra peer restano gestite da NetBird.
# Traduzione / Translation: Local VPN rules remain on this router; NetBird manages policies between peers

# -----------------------------------------------------------------------
# 3.4 Regole aggiuntive di dispositivi: mantenere la relativa tabella dedicata.
# Non duplicare qui regole installate da un altro componente.
# Traduzione / Translation: 3.4 Extra device rules: retain their dedicated table and do not duplicate rules installed by another
# IT/EN: component

# =======================================================================
# --- 4. OTTIMIZZAZIONI KERNEL ---
# Traduzione / Translation: 4. KERNEL TUNING
# =======================================================================

# Stabilità conntrack UDP / Exit Node.
# Traduzione / Translation: UDP conntrack and exit-node stability

echo 120 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout
echo 180 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream


# UDP GRO forwarding.
# Traduzione / Translation: Inoltro UDP con GRO

ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
ethtool -K br0 rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
