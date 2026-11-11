# ==============================================================================
# Dockerfile - Pi-Dock-Wifi Router
# Traduzione / Translation: Dockerfile del router Pi-Dock-Wifi
# ==============================================================================
# Multi-stage build:
#   1. Builder stage: compiles hostapd (with force_ht40 patch) and fastfetch
#   2. Production stage: lightweight runtime with nginx web dashboard
# Traduzione / Translation: Build multistadio: 1. compilazione di hostapd con patch force_ht40 e fastfetch; 2. ambiente runtime
# IT/EN: leggero con dashboard nginx.
# ==============================================================================


# ==============================================================================
# STAGE 1: Build environment
# Traduzione / Translation: FASE 1: ambiente di compilazione
# ==============================================================================
FROM debian:latest AS builder

LABEL stage=builder

# Disable interactive prompts during package installation
# Traduzione / Translation: Disabilita le richieste interattive durante l’installazione dei pacchetti
ARG DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
# Install build dependencies for hostapd and fastfetch
# Traduzione / Translation: Installa le dipendenze necessarie a compilare hostapd e fastfetch
# ------------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    cmake \
    gcc \
    g++ \
    make \
    patch \
    pkg-config \
    libnl-3-dev \
    libnl-genl-3-dev \
    libssl-dev \
    libreadline-dev \
    libdbus-1-dev \
    libpci-dev \
    libdrm-dev \
    libx11-dev \
    libxcb1-dev \
    libxcb-randr0-dev \
    libxcb-res0-dev \
    libxcb-util-dev \
    libxcb-xfixes0-dev \
    libwayland-dev \
    libgl1-mesa-dev \
    && rm -rf /var/lib/apt/lists/*


# ------------------------------------------------------------------------------
# Clone hostapd source
# Traduzione / Translation: Clona i sorgenti di hostapd
# ------------------------------------------------------------------------------
RUN git config --global http.postBuffer 524288000 && \
    git clone --depth 1 https://git.w1.fi/hostap.git /wpa

WORKDIR /wpa


# ------------------------------------------------------------------------------
# Apply force_ht40 patch
# This patch allows forcing 40MHz channel width even when neighboring
# BSSes advertise 20/40 intolerance (violates IEEE 802.11-2012 10.15.3.2)
# Traduzione / Translation: Applica la patch force_ht40: consente di forzare 40 MHz anche quando i BSS vicini segnalano
# IT/EN: intolleranza 20/40; questo comportamento viola IEEE 802.11-2012, 10.15.3.2.
# ------------------------------------------------------------------------------
RUN tee /wpa/upstream-hostapd-force-ht40-mode.patch > /dev/null <<'END_SCRIPT'
diff -Naurp -x '*.o' -x '*.d' ./hostapd/config_file.c ../../hostapd-force-ht40/hostapd-2.9/hostapd/config_file.c
--- ./hostapd/config_file.c	2019-08-07 19:25:25.000000000 +0600
+++ ../../hostapd-force-ht40/hostapd-2.9/hostapd/config_file.c	2020-04-25 23:30:11.860816115 +0600
@@ -3419,6 +3419,8 @@ static int hostapd_config_fill(struct ho
 				   line);
 			return 1;
 		}
+	} else if (os_strcmp(buf, "force_ht40") == 0) {
+		conf->force_ht40 = atoi(pos);
 	} else if (os_strcmp(buf, "require_ht") == 0) {
 		conf->require_ht = atoi(pos);
 	} else if (os_strcmp(buf, "obss_interval") == 0) {
diff -Naurp -x '*.o' -x '*.d' ./hostapd/hostapd.conf ../../hostapd-force-ht40/hostapd-2.9/hostapd/hostapd.conf
--- ./hostapd/hostapd.conf	2019-08-07 19:25:25.000000000 +0600
+++ ../../hostapd-force-ht40/hostapd-2.9/hostapd/hostapd.conf	2020-04-25 23:26:58.523807018 +0600
@@ -594,6 +594,14 @@ wmm_ac_vo_acm=0
 # L-SIG TXOP protection support: [LSIG-TXOP-PROT] (disabled if not set)
 #ht_capab=[HT40-][SHORT-GI-20][SHORT-GI-40]
 
+
+# Skip checks for 40 MHz intolerance or overlapping stations and force
+# 40 MHz channel width
+# Please note that this violates IEEE Std 802.11-2012, 10.15.3.2
+# 0 = disabled (default)
+# 1 = enabled
+#force_ht40=0
+
 # Require stations to support HT PHY (reject association if they do not)
 #require_ht=1
 
diff -Naurp -x '*.o' -x '*.d' ./src/ap/ap_config.c ../../hostapd-force-ht40/hostapd-2.9/src/ap/ap_config.c
--- ./src/ap/ap_config.c	2019-08-07 19:25:25.000000000 +0600
+++ ../../hostapd-force-ht40/hostapd-2.9/src/ap/ap_config.c	2020-04-25 23:32:57.706657234 +0600
@@ -225,6 +225,8 @@ struct hostapd_config * hostapd_config_d
 
 	conf->ht_capab = HT_CAP_INFO_SMPS_DISABLED;
 
+	conf->force_ht40 = 0;
+
 	conf->ap_table_max_size = 255;
 	conf->ap_table_expiration_time = 60;
 	conf->track_sta_max_age = 180;
diff -Naurp -x '*.o' -x '*.d' ./src/ap/ap_config.h ../../hostapd-force-ht40/hostapd-2.9/src/ap/ap_config.h
--- ./src/ap/ap_config.h	2019-08-07 19:25:25.000000000 +0600
+++ ../../hostapd-force-ht40/hostapd-2.9/src/ap/ap_config.h	2020-04-25 23:33:24.546357399 +0600
@@ -932,6 +932,7 @@ struct hostapd_config {
 
 	int ht_op_mode_fixed;
 	u16 ht_capab;
+	int force_ht40;
 	int ieee80211n;
 	int secondary_channel;
 	int no_pri_sec_switch;
diff -Naurp -x '*.o' -x '*.d' ./src/ap/hw_features.c ../../hostapd-force-ht40/hostapd-2.9/src/ap/hw_features.c
--- ./src/ap/hw_features.c	2019-08-07 19:25:25.000000000 +0600
+++ ../../hostapd-force-ht40/hostapd-2.9/src/ap/hw_features.c	2020-04-26 15:45:57.265177510 +0600
@@ -310,7 +310,7 @@ static void ieee80211n_check_scan(struct
 	wpa_scan_results_free(scan_res);
 
 	iface->secondary_ch = iface->conf->secondary_channel;
-	if (!oper40) {
+	if (!iface->conf->force_ht40 && !oper40) {
 		wpa_printf(MSG_INFO, "20/40 MHz operation not permitted on "
 			   "channel pri=%d sec=%d based on overlapping BSSes",
 			   iface->conf->channel,
diff -Naurp -x '*.o' -x '*.d' ./src/ap/ieee802_11_ht.c ../../hostapd-force-ht40/hostapd-2.9/src/ap/ieee802_11_ht.c
--- ./src/ap/ieee802_11_ht.c	2019-08-07 19:25:25.000000000 +0600
+++ ../../hostapd-force-ht40/hostapd-2.9/src/ap/ieee802_11_ht.c	2020-04-25 23:38:43.842733174 +0600
@@ -207,6 +207,9 @@ static int is_40_allowed(struct hostapd_
 	if (iface->current_mode->mode != HOSTAPD_MODE_IEEE80211G)
 		return 1;
 
+	if (iface->conf->force_ht40)
+		return 1;
+
 	pri_freq = hostapd_hw_get_freq(iface->bss[0], iface->conf->channel);
 
 	if (iface->conf->secondary_channel > 0)
@@ -299,7 +302,7 @@ void hostapd_2040_coex_action(struct hos
 			       HOSTAPD_MODULE_IEEE80211,
 			       HOSTAPD_LEVEL_DEBUG,
 			       "20 MHz BSS width request bit is set in BSS coexistence information field");
-		is_ht40_allowed = 0;
+		is_ht40_allowed = iface->conf->force_ht40;
 	}
 
 	if (bc_ie->coex_param & WLAN_20_40_BSS_COEX_40MHZ_INTOL) {
@@ -309,7 +312,7 @@ void hostapd_2040_coex_action(struct hos
 			       HOSTAPD_MODULE_IEEE80211,
 			       HOSTAPD_LEVEL_DEBUG,
 			       "40 MHz intolerant bit is set in BSS coexistence information field");
-		is_ht40_allowed = 0;
+		is_ht40_allowed = iface->conf->force_ht40;
 	}
 
 	/* 20/40 BSS Intolerant Channel Report element (zero or more times) */
@@ -341,7 +344,7 @@ void hostapd_2040_coex_action(struct hos
 				       HOSTAPD_LEVEL_DEBUG,
 				       "20_40_INTOLERANT channel %d reported",
 				       chan);
-			is_ht40_allowed = 0;
+			is_ht40_allowed = iface->conf->force_ht40;
 		}
 
 		data += 2 + ielen;
END_SCRIPT

RUN patch -p0 < upstream-hostapd-force-ht40-mode.patch


# ------------------------------------------------------------------------------
# Hostapd build configuration
# Traduzione / Translation: Configurazione di compilazione hostapd
# ------------------------------------------------------------------------------
WORKDIR /wpa/hostapd

RUN tee /wpa/hostapd/.config > /dev/null <<'END_SCRIPT'
# Example hostapd build time configuration
# Traduzione / Translation: Esempio di configurazione per la compilazione di hostapd
#
# This file lists the configuration options that are used when building the
# hostapd binary. All lines starting with # are ignored. Configuration option
# lines must be commented out complete, if they are not to be included, i.e.,
# just setting VARIABLE=n is not disabling that variable.
# Traduzione / Translation: Il file elenca le opzioni usate per compilare hostapd. Le righe che iniziano con # sono ignorate: per
# IT/EN: escludere un’opzione va commentata l’intera riga; VARIABLE=n non la disabilita.
#
# This file is included in Makefile, so variables like CFLAGS and LIBS can also
# be modified from here. In most cass, these lines should use += in order not
# to override previous values of the variables.
# Traduzione / Translation: Il Makefile include questo file; è possibile modificare CFLAGS e LIBS. Di norma usare += per non
# IT/EN: sovrascrivere valori già assegnati alle variabili.

# Driver interface for Host AP driver
# Traduzione / Translation: Interfaccia del driver Host AP
CONFIG_DRIVER_HOSTAP=y

# Driver interface for wired authenticator
# Traduzione / Translation: Interfaccia del driver per autenticatore su rete cablata
#CONFIG_DRIVER_WIRED=y

# Driver interface for drivers using the nl80211 kernel interface
# Traduzione / Translation: Interfaccia dei driver che usano l’API kernel nl80211
CONFIG_DRIVER_NL80211=y

# QCA vendor extensions to nl80211
# Traduzione / Translation: Estensioni QCA a nl80211
#CONFIG_DRIVER_NL80211_QCA=y

# driver_nl80211.c requires libnl. If you are compiling it yourself
# you may need to point hostapd to your version of libnl.
# Traduzione / Translation: driver_nl80211.c richiede libnl. Compilando manualmente può essere necessario indicare il percorso
# IT/EN: della propria versione di libnl.
#
#CFLAGS += -I$<path to libnl include files>
#LIBS += -L$<path to libnl library files>

# Use libnl v2.0 (or 3.0) libraries.
# Traduzione / Translation: Usa librerie libnl 2.0 oppure 3.0
#CONFIG_LIBNL20=y

# Use libnl 3.2 libraries (if this is selected, CONFIG_LIBNL20 is ignored)
# Traduzione / Translation: Usa libnl 3.2; selezionando questa opzione CONFIG_LIBNL20 viene ignorato
CONFIG_LIBNL32=y


# Driver interface for FreeBSD net80211 layer (e.g., Atheros driver)
# Traduzione / Translation: Interfaccia driver per il livello net80211 di FreeBSD, per esempio Atheros
#CONFIG_DRIVER_BSD=y
#CFLAGS += -I/usr/local/include
#LIBS += -L/usr/local/lib
#LIBS_p += -L/usr/local/lib
#LIBS_c += -L/usr/local/lib

# Driver interface for no driver (e.g., RADIUS server only)
# Traduzione / Translation: Interfaccia senza driver, per esempio per un server solo RADIUS
#CONFIG_DRIVER_NONE=y

# WPA2/IEEE 802.11i RSN pre-authentication
# Traduzione / Translation: Preautenticazione RSN WPA2/IEEE 802.11i
CONFIG_RSN_PREAUTH=y

# Support Operating Channel Validation
# Traduzione / Translation: Supporto alla verifica del canale operativo, Operating Channel Validation
CONFIG_OCV=y

# Integrated EAP server
# Traduzione / Translation: Server EAP integrato
CONFIG_EAP=y

# EAP Re-authentication Protocol (ERP) in integrated EAP server
# Traduzione / Translation: Protocollo di riautenticazione EAP, ERP, nel server EAP integrato
CONFIG_ERP=y

# EAP-MD5 for the integrated EAP server
# Traduzione / Translation: EAP-MD5 per il server EAP integrato
CONFIG_EAP_MD5=y

# EAP-TLS for the integrated EAP server
# Traduzione / Translation: EAP-TLS per il server EAP integrato
CONFIG_EAP_TLS=y

# EAP-MSCHAPv2 for the integrated EAP server
# Traduzione / Translation: EAP-MSCHAPv2 per il server EAP integrato
CONFIG_EAP_MSCHAPV2=y

# EAP-PEAP for the integrated EAP server
# Traduzione / Translation: EAP-PEAP per il server EAP integrato
CONFIG_EAP_PEAP=y

# EAP-GTC for the integrated EAP server
# Traduzione / Translation: EAP-GTC per il server EAP integrato
CONFIG_EAP_GTC=y

# EAP-TTLS for the integrated EAP server
# Traduzione / Translation: EAP-TTLS per il server EAP integrato
CONFIG_EAP_TTLS=y

# EAP-SIM for the integrated EAP server
# Traduzione / Translation: EAP-SIM per il server EAP integrato
#CONFIG_EAP_SIM=y

# EAP-AKA for the integrated EAP server
# Traduzione / Translation: EAP-AKA per il server EAP integrato
#CONFIG_EAP_AKA=y

# EAP-AKA' for the integrated EAP server
# This requires CONFIG_EAP_AKA to be enabled, too.
# Traduzione / Translation: EAP-AKA’ per il server EAP integrato; richiede anche CONFIG_EAP_AKA
#CONFIG_EAP_AKA_PRIME=y

# EAP-PAX for the integrated EAP server
# Traduzione / Translation: EAP-PAX per il server EAP integrato
#CONFIG_EAP_PAX=y

# EAP-PSK for the integrated EAP server (this is _not_ needed for WPA-PSK)
# Traduzione / Translation: EAP-PSK per il server EAP integrato; non è necessario per WPA-PSK
#CONFIG_EAP_PSK=y

# EAP-pwd for the integrated EAP server (secure authentication with a password)
# Traduzione / Translation: EAP-pwd per il server EAP integrato, autenticazione sicura tramite password
#CONFIG_EAP_PWD=y

# EAP-SAKE for the integrated EAP server
# Traduzione / Translation: EAP-SAKE per il server EAP integrato
#CONFIG_EAP_SAKE=y

# EAP-GPSK for the integrated EAP server
# Traduzione / Translation: EAP-GPSK per il server EAP integrato
#CONFIG_EAP_GPSK=y
# Include support for optional SHA256 cipher suite in EAP-GPSK
# Traduzione / Translation: Include il supporto opzionale alla suite crittografica SHA256 in EAP-GPSK
#CONFIG_EAP_GPSK_SHA256=y

# EAP-FAST for the integrated EAP server
# Traduzione / Translation: EAP-FAST per il server EAP integrato
#CONFIG_EAP_FAST=y

# EAP-TEAP for the integrated EAP server
# Note: The current EAP-TEAP implementation is experimental and should not be
# enabled for production use. The IETF RFC 7170 that defines EAP-TEAP has number
# of conflicting statements and missing details and the implementation has
# vendor specific workarounds for those and as such, may not interoperate with
# any other implementation. This should not be used for anything else than
# experimentation and interoperability testing until those issues has been
# resolved.
# Traduzione / Translation: EAP-TEAP per il server EAP integrato. Questa implementazione è sperimentale e non va abilitata in
# IT/EN: produzione: RFC 7170 contiene contraddizioni e dettagli mancanti, gestiti con soluzioni specifiche dei
# IT/EN: produttori che possono impedire l’interoperabilità. Usarla solo per sperimentazione e test finché tali
# IT/EN: problemi non sono risolti.
#CONFIG_EAP_TEAP=y

# Wi-Fi Protected Setup (WPS)
# Traduzione / Translation: Configurazione Wi-Fi protetta, WPS
CONFIG_WPS=y
# Enable UPnP support for external WPS Registrars
# Traduzione / Translation: Abilita UPnP per registrar WPS esterni
#CONFIG_WPS_UPNP=y
# Enable WPS support with NFC config method
# Traduzione / Translation: Abilita WPS con metodo di configurazione NFC
#CONFIG_WPS_NFC=y

# EAP-IKEv2
# Traduzione / Translation: EAP-IKEv2
#CONFIG_EAP_IKEV2=y

# Trusted Network Connect (EAP-TNC)
# Traduzione / Translation: Trusted Network Connect, EAP-TNC
#CONFIG_EAP_TNC=y

# EAP-EKE for the integrated EAP server
# Traduzione / Translation: EAP-EKE per il server EAP integrato
#CONFIG_EAP_EKE=y

# PKCS#12 (PFX) support (used to read private key and certificate file from
# a file that usually has extension .p12 or .pfx)
# Traduzione / Translation: Supporto PKCS#12/PFX per leggere chiave privata e certificato da un unico file, solitamente .p12 o
# IT/EN: .pfx
CONFIG_PKCS12=y

# RADIUS authentication server. This provides access to the integrated EAP
# server from external hosts using RADIUS.
# Traduzione / Translation: Server di autenticazione RADIUS: espone il server EAP integrato agli host esterni tramite RADIUS
#CONFIG_RADIUS_SERVER=y

# Build IPv6 support for RADIUS operations
# Traduzione / Translation: Compila il supporto IPv6 per le operazioni RADIUS
CONFIG_IPV6=y

# Include support fo RADIUS/TLS into the RADIUS client
# Traduzione / Translation: Include RADIUS/TLS nel client RADIUS
#CONFIG_RADIUS_TLS=y

# IEEE Std 802.11r-2008 (Fast BSS Transition)
# Traduzione / Translation: IEEE 802.11r-2008, transizione rapida fra BSS
#CONFIG_IEEE80211R=y

# Use the hostapd's IEEE 802.11 authentication (ACL), but without
# the IEEE 802.11 Management capability (e.g., FreeBSD/net80211)
# Traduzione / Translation: Usa l’autenticazione IEEE 802.11 di hostapd, ACL comprese, senza la capacità di gestione IEEE 802.11;
# IT/EN: per esempio su FreeBSD/net80211
#CONFIG_DRIVER_RADIUS_ACL=y

# Wireless Network Management (IEEE Std 802.11v-2011)
# Note: This is experimental and not complete implementation.
# Traduzione / Translation: Gestione della rete wireless IEEE 802.11v-2011; implementazione sperimentale e incompleta
#CONFIG_WNM=y

# IEEE 802.11ac (Very High Throughput) support
# Traduzione / Translation: Supporto IEEE 802.11ac, Very High Throughput
CONFIG_IEEE80211AC=y

# IEEE 802.11ax HE support
# Traduzione / Translation: Supporto HE IEEE 802.11ax
CONFIG_IEEE80211AX=y

# IEEE 802.11be EHT support
# CONFIG_IEEE80211AX is mandatory for setting CONFIG_IEEE80211BE.
# Note: This is experimental and work in progress. The definitions are still
# subject to change and this should not be expected to interoperate with the
# final IEEE 802.11be version.
# Traduzione / Translation: Supporto EHT IEEE 802.11be: richiede CONFIG_IEEE80211AX. È sperimentale, ancora in sviluppo e soggetto
# IT/EN: a modifiche; non garantisce interoperabilità con lo standard definitivo.
CONFIG_IEEE80211BE=y

# Simultaneous Authentication of Equals (SAE), WPA3-Personal
# Traduzione / Translation: Autenticazione simultanea fra pari, SAE, WPA3-Personal
CONFIG_SAE=y

# SAE Public Key, WPA3-Personal
# Traduzione / Translation: Chiave pubblica SAE, WPA3-Personal
#CONFIG_SAE_PK=y

# Remove debugging code that is printing out debug messages to stdout.
# This can be used to reduce the size of the hostapd considerably if debugging
# code is not needed.
# Traduzione / Translation: Rimuove il codice che stampa messaggi di debug su stdout; riduce sensibilmente la dimensione di
# IT/EN: hostapd quando il debug non serve.
#CONFIG_NO_STDOUT_DEBUG=y

# Add support for writing debug log to a file: -f /tmp/hostapd.log
# Disabled by default.
# Traduzione / Translation: Abilita il salvataggio del debug su file con -f /tmp/hostapd.log; disabilitato per default.
#CONFIG_DEBUG_FILE=y

# Send debug messages to syslog instead of stdout
# Traduzione / Translation: Invia i messaggi di debug a syslog anziché a stdout
#CONFIG_DEBUG_SYSLOG=y

# Add support for sending all debug messages (regardless of debug verbosity)
# to the Linux kernel tracing facility. This helps debug the entire stack by
# making it easy to record everything happening from the driver up into the
# same file, e.g., using trace-cmd.
# Traduzione / Translation: Invia tutti i messaggi di debug, indipendentemente dalla verbosità, al tracciamento del kernel Linux:
# IT/EN: consente di registrare driver e livelli superiori nello stesso file, per esempio con trace-cmd.
#CONFIG_DEBUG_LINUX_TRACING=y

# Remove support for RADIUS accounting
# Traduzione / Translation: Rimuove il supporto all’accounting RADIUS
#CONFIG_NO_ACCOUNTING=y

# Remove support for RADIUS
# Traduzione / Translation: Rimuove il supporto RADIUS
#CONFIG_NO_RADIUS=y

# Remove support for VLANs
# Traduzione / Translation: Rimuove il supporto VLAN
#CONFIG_NO_VLAN=y

# Enable support for fully dynamic VLANs. This enables hostapd to
# automatically create bridge and VLAN interfaces if necessary.
# Traduzione / Translation: Abilita VLAN completamente dinamiche: hostapd può creare automaticamente bridge e interfacce VLAN
# IT/EN: quando necessario.
#CONFIG_FULL_DYNAMIC_VLAN=y

# Use netlink-based kernel API for VLAN operations instead of ioctl()
# Note: This requires libnl 3.1 or newer.
# Traduzione / Translation: Usa l’API kernel netlink per le operazioni VLAN anziché ioctl(); richiede libnl 3.1 o successivo.
#CONFIG_VLAN_NETLINK=y

# Remove support for dumping internal state through control interface commands
# This can be used to reduce binary size at the cost of disabling a debugging
# option.
# Traduzione / Translation: Rimuove i comandi dell’interfaccia di controllo che esportano lo stato interno; riduce il binario
# IT/EN: rinunciando a una funzione di debug.
#CONFIG_NO_DUMP_STATE=y

# Enable tracing code for developer debugging
# This tracks use of memory allocations and other registrations and reports
# incorrect use with a backtrace of call (or allocation) location.
# Traduzione / Translation: Abilita il tracciamento per gli sviluppatori: controlla allocazioni di memoria e altre registrazioni,
# IT/EN: segnalando usi errati con la traccia delle chiamate o delle allocazioni.
#CONFIG_WPA_TRACE=y
# For BSD, comment out these.
# Traduzione / Translation: Su BSD commentare queste righe
#LIBS += -lexecinfo
#LIBS_p += -lexecinfo
#LIBS_c += -lexecinfo

# Use libbfd to get more details for developer debugging
# This enables use of libbfd to get more detailed symbols for the backtraces
# generated by CONFIG_WPA_TRACE=y.
# Traduzione / Translation: Usa libbfd per ottenere simboli più dettagliati nelle tracce prodotte da CONFIG_WPA_TRACE=y
#CONFIG_WPA_TRACE_BFD=y
# For BSD, comment out these.
# Traduzione / Translation: Su BSD commentare queste righe
#LIBS += -lbfd -liberty -lz
#LIBS_p += -lbfd -liberty -lz
#LIBS_c += -lbfd -liberty -lz

# hostapd depends on strong random number generation being available from the
# operating system. os_get_random() function is used to fetch random data when
# needed, e.g., for key generation. On Linux and BSD systems, this works by
# reading /dev/urandom. It should be noted that the OS entropy pool needs to be
# properly initialized before hostapd is started. This is important especially
# on embedded devices that do not have a hardware random number generator and
# may by default start up with minimal entropy available for random number
# generation.
# Traduzione / Translation: hostapd richiede casualità crittograficamente robusta dal sistema operativo. os_get_random() legge
# IT/EN: dati, per esempio per le chiavi; su Linux/BSD usa /dev/urandom. Il pool di entropia deve essere
# IT/EN: inizializzato prima dell’avvio, soprattutto su sistemi embedded privi di generatore hardware e con
# IT/EN: poca entropia iniziale.
#
# As a safety net, hostapd is by default trying to internally collect
# additional entropy for generating random data to mix in with the data
# fetched from the OS. This by itself is not considered to be very strong, but
# it may help in cases where the system pool is not initialized properly.
# However, it is very strongly recommended that the system pool is initialized
# with enough entropy either by using hardware assisted random number
# generator or by storing state over device reboots.
# Traduzione / Translation: Per sicurezza hostapd raccoglie anche entropia interna da mescolare ai dati del sistema. Non è una
# IT/EN: sorgente robusta da sola, ma può aiutare se il pool del sistema non è inizializzato. È fortemente
# IT/EN: consigliato inizializzarlo tramite hardware o conservando stato fra i riavvii.
#
# hostapd can be configured to maintain its own entropy store over restarts to
# enhance random number generation. This is not perfect, but it is much more
# secure than using the same sequence of random numbers after every reboot.
# This can be enabled with -e<entropy file> command line option. The specified
# file needs to be readable and writable by hostapd.
# Traduzione / Translation: hostapd può conservare un proprio archivio di entropia fra riavvii con -e<file>. Non è perfetto ma è
# IT/EN: più sicuro che ripetere la stessa sequenza casuale a ogni boot. Il file deve essere leggibile e
# IT/EN: scrivibile da hostapd.
#
# If the os_get_random() is known to provide strong random data (e.g., on
# Linux/BSD, the board in question is known to have reliable source of random
# data from /dev/urandom), the internal hostapd random pool can be disabled.
# This will save some in binary size and CPU use. However, this should only be
# considered for builds that are known to be used on devices that meet the
# requirements described above.
# Traduzione / Translation: Se os_get_random() è una sorgente sicuramente robusta, per esempio /dev/urandom affidabile sulla
# IT/EN: scheda usata, è possibile disabilitare il pool interno per ridurre dimensione e CPU. Valutarlo solo su
# IT/EN: dispositivi che rispettano i requisiti di entropia descritti.
#CONFIG_NO_RANDOM_POOL=y

# Should we attempt to use the getrandom(2) call that provides more reliable
# yet secure randomness source than /dev/random on Linux 3.17 and newer.
# Requires glibc 2.25 to build, falls back to /dev/random if unavailable.
# Traduzione / Translation: Prova getrandom(2), disponibile su Linux 3.17+, come sorgente casuale più affidabile. Richiede glibc
# IT/EN: 2.25 per compilare; ripiega su /dev/random se non disponibile.
#CONFIG_GETRANDOM=y

# Should we use poll instead of select? Select is used by default.
# Traduzione / Translation: Usare poll al posto di select? Il default è select.
#CONFIG_ELOOP_POLL=y

# Should we use epoll instead of select? Select is used by default.
# Traduzione / Translation: Usare epoll al posto di select? Il default è select.
#CONFIG_ELOOP_EPOLL=y

# Should we use kqueue instead of select? Select is used by default.
# Traduzione / Translation: Usare kqueue al posto di select? Il default è select.
#CONFIG_ELOOP_KQUEUE=y

# Select TLS implementation
# Traduzione / Translation: Seleziona l’implementazione TLS
# openssl = OpenSSL (default)
# gnutls = GnuTLS
# internal = Internal TLSv1 implementation (experimental)
# linux = Linux kernel AF_ALG and internal TLSv1 implementation (experimental)
# none = Empty template
#CONFIG_TLS=openssl

# TLS-based EAP methods require at least TLS v1.0. Newer version of TLS (v1.1)
# can be enabled to get a stronger construction of messages when block ciphers
# are used.
# Traduzione / Translation: I metodi EAP basati su TLS richiedono almeno TLS 1.0. TLS 1.1 offre una costruzione più robusta dei
# IT/EN: messaggi quando sono usati cifrari a blocchi.
#CONFIG_TLSV11=y

# TLS-based EAP methods require at least TLS v1.0. Newer version of TLS (v1.2)
# can be enabled to enable use of stronger crypto algorithms.
# Traduzione / Translation: I metodi EAP basati su TLS richiedono almeno TLS 1.0. TLS 1.2 consente algoritmi crittografici più
# IT/EN: robusti.
#CONFIG_TLSV12=y

# Select which ciphers to use by default with OpenSSL if the user does not
# specify them.
# Traduzione / Translation: Seleziona i cifrari predefiniti di OpenSSL quando l’utente non li specifica
#CONFIG_TLS_DEFAULT_CIPHERS="DEFAULT:!EXP:!LOW"

# If CONFIG_TLS=internal is used, additional library and include paths are
# needed for LibTomMath. Alternatively, an integrated, minimal version of
# LibTomMath can be used. See beginning of libtommath.c for details on benefits
# and drawbacks of this option.
# Traduzione / Translation: CONFIG_TLS=internal richiede percorsi aggiuntivi per librerie e include di LibTomMath. In alternativa
# IT/EN: è disponibile una versione minima integrata; vantaggi e limiti sono descritti all’inizio di
# IT/EN: libtommath.c.
#CONFIG_INTERNAL_LIBTOMMATH=y
#ifndef CONFIG_INTERNAL_LIBTOMMATH
#LTM_PATH=/usr/src/libtommath-0.39
# Traduzione / Translation: Esempio condizionale del percorso LTM_PATH per LibTomMath esterna
#CFLAGS += -I$(LTM_PATH)
#LIBS += -L$(LTM_PATH)
#LIBS_p += -L$(LTM_PATH)
#endif
# At the cost of about 4 kB of additional binary size, the internal LibTomMath
# can be configured to include faster routines for exptmod, sqr, and div to
# speed up DH and RSA calculation considerably
# Traduzione / Translation: Con circa 4 kB aggiuntivi nel binario, LibTomMath interna può includere routine exptmod, sqr e div più
# IT/EN: veloci, accelerando notevolmente DH e RSA.
#CONFIG_INTERNAL_LIBTOMMATH_FAST=y

# Interworking (IEEE 802.11u)
# This can be used to enable functionality to improve interworking with
# external networks.
# Traduzione / Translation: Interworking IEEE 802.11u: funzionalità per migliorare l’interazione con reti esterne
#CONFIG_INTERWORKING=y

# Hotspot 2.0
# Traduzione / Translation: Hotspot 2.0
CONFIG_HS20=y

# Enable SQLite database support in hlr_auc_gw, EAP-SIM DB, and eap_user_file
# Traduzione / Translation: Abilita SQLite per hlr_auc_gw, database EAP-SIM ed eap_user_file
#CONFIG_SQLITE=y

# Enable Fast Session Transfer (FST)
# Traduzione / Translation: Abilita Fast Session Transfer, FST
CONFIG_FST=y

# Enable CLI commands for FST testing
# Traduzione / Translation: Abilita i comandi CLI di test FST
#CONFIG_FST_TEST=y

# Testing options
# This can be used to enable some testing options (see also the example
# configuration file) that are really useful only for testing clients that
# connect to this hostapd. These options allow, for example, to drop a
# certain percentage of probe requests or auth/(re)assoc frames.
# Traduzione / Translation: Opzioni di test utili per provare i client: per esempio scartare una percentuale di probe request o
# IT/EN: frame di autenticazione/(ri)associazione; vedere anche la configurazione di esempio.
#
#CONFIG_TESTING_OPTIONS=y

# Automatic Channel Selection
# This will allow hostapd to pick the channel automatically when channel is set
# to "acs_survey" or "0". Eventually, other ACS algorithms can be added in
# similar way.
# Traduzione / Translation: Selezione automatica del canale: hostapd sceglie il canale se channel vale acs_survey oppure 0;
# IT/EN: possono essere aggiunti altri algoritmi ACS.
#
# Automatic selection is currently only done through initialization, later on
# we hope to do background checks to keep us moving to more ideal channels as
# time goes by. ACS is currently only supported through the nl80211 driver and
# your driver must have survey dump capability that is filled by the driver
# during scanning.
# Traduzione / Translation: La selezione automatica avviene attualmente solo all’inizializzazione; i controlli successivi sono
# IT/EN: previsti come sviluppo. ACS richiede nl80211 e un driver che popoli i risultati survey durante la
# IT/EN: scansione.
#
# You can customize the ACS survey algorithm with the hostapd.conf variable
# acs_num_scans.
# Traduzione / Translation: Personalizza l’algoritmo survey ACS con acs_num_scans in hostapd.conf
#
# Supported ACS drivers:
# * ath9k
# * ath5k
# * ath10k
# Traduzione / Translation: Driver ACS supportati: ath9k, ath5k, ath10k
#
# For more details refer to:
# https://wireless.wiki.kernel.org/en/users/documentation/acs
# Traduzione / Translation: Per maggiori dettagli consultare https://wireless.wiki.kernel.org/en/users/documentation/acs
#
CONFIG_ACS=y

# Multiband Operation support
# These extensions facilitate efficient use of multiple frequency bands
# available to the AP and the devices that may associate with it.
# Traduzione / Translation: Supporto multibanda: estensioni per usare efficacemente più bande disponibili all’AP e ai client
CONFIG_MBO=y

# Client Taxonomy
# Has the AP retain the Probe Request and (Re)Association Request frames from
# a client, from which a signature can be produced which can identify the model
# of client device like "Nexus 6P" or "iPhone 5s".
# Traduzione / Translation: Tassonomia dei client: conserva frame Probe Request e (Re)Association Request, dai quali ricavare una
# IT/EN: firma del modello del dispositivo, per esempio Nexus 6P o iPhone 5s.
CONFIG_TAXONOMY=y

# Fast Initial Link Setup (FILS) (IEEE 802.11ai)
# Traduzione / Translation: Fast Initial Link Setup, FILS, IEEE 802.11ai
#CONFIG_FILS=y
# FILS shared key authentication with PFS
# Traduzione / Translation: Autenticazione FILS a chiave condivisa con PFS
#CONFIG_FILS_SK_PFS=y

# Include internal line edit mode in hostapd_cli. This can be used to provide
# limited command line editing and history support.
# Traduzione / Translation: Include nell’hostapd_cli l’editor di riga interno, con funzioni limitate di modifica e cronologia
#CONFIG_WPA_CLI_EDIT=y

# Opportunistic Wireless Encryption (OWE)
# Experimental implementation of draft-harkins-owe-07.txt
# Traduzione / Translation: Opportunistic Wireless Encryption, OWE: implementazione sperimentale della bozza
# IT/EN: draft-harkins-owe-07.txt
#CONFIG_OWE=y

# Airtime policy support
# Traduzione / Translation: Supporto alle politiche di airtime
#CONFIG_AIRTIME_POLICY=y

# Override default value for the wpa_disable_eapol_key_retries configuration
# parameter. See that parameter in hostapd.conf for more details.
# Traduzione / Translation: Sovrascrive il default di wpa_disable_eapol_key_retries; vedere la descrizione del parametro in
# IT/EN: hostapd.conf
#CFLAGS += -DDEFAULT_WPA_DISABLE_EAPOL_KEY_RETRIES=1

# Wired equivalent privacy (WEP)
# WEP is an obsolete cryptographic data confidentiality algorithm that is not
# considered secure. It should not be used for anything anymore. The
# functionality needed to use WEP is available in the current hostapd
# release under this optional build parameter. This functionality is subject to
# be completely removed in a future release.
# Traduzione / Translation: WEP è un algoritmo di riservatezza obsoleto e non sicuro: non va più usato. Il supporto resta
# IT/EN: disponibile come opzione di compilazione, ma può essere rimosso in futuro.
#CONFIG_WEP=y

# Remove all TKIP functionality
# TKIP is an old cryptographic data confidentiality algorithm that is not
# considered secure. It should not be used anymore. For now, the default hostapd
# build includes this to allow mixed mode WPA+WPA2 networks to be enabled, but
# that functionality is subject to be removed in the future.
# Traduzione / Translation: Rimuove tutte le funzionalità TKIP. TKIP è obsoleto e non sicuro; il default lo include per
# IT/EN: compatibilità WPA/WPA2 mista, ma tale funzionalità può essere rimossa in futuro.
#CONFIG_NO_TKIP=y

# Pre-Association Security Negotiation (PASN)
# Experimental implementation based on IEEE P802.11z/D2.6 and the protocol
# design is still subject to change. As such, this should not yet be enabled in
# production use.
# Traduzione / Translation: Negoziazione di sicurezza prima dell’associazione, PASN: implementazione sperimentale basata su IEEE
# IT/EN: P802.11z/D2.6, ancora soggetta a modifiche e non destinata alla produzione.
#CONFIG_PASN=y

# Device Provisioning Protocol (DPP) (also known as Wi-Fi Easy Connect)
# Traduzione / Translation: Device Provisioning Protocol, DPP, noto anche come Wi-Fi Easy Connect
CONFIG_DPP=y
# DPP version 2 support
# Traduzione / Translation: Supporto DPP versione 2
CONFIG_DPP2=y
# DPP version 3 support (experimental and still changing; do not enable for
# production use)
# Traduzione / Translation: Supporto DPP versione 3, sperimentale e ancora in modifica: non abilitare in produzione
#CONFIG_DPP3=y

# Wi-Fi Aware unsynchronized service discovery (NAN USD)
# Traduzione / Translation: Scoperta servizi Wi-Fi Aware non sincronizzata, NAN USD
CONFIG_NAN_USD=y
END_SCRIPT


# ------------------------------------------------------------------------------
# Compile hostapd
# Traduzione / Translation: Compila hostapd
# ------------------------------------------------------------------------------
RUN make clean && make -j$(nproc)


# ------------------------------------------------------------------------------
# Build fastfetch (system info tool)
# Traduzione / Translation: Compila fastfetch, strumento di informazioni sul sistema
# ------------------------------------------------------------------------------
RUN git clone https://github.com/fastfetch-cli/fastfetch.git /opt/fastfetch && \
    mkdir -p /opt/fastfetch/build && \
    cd /opt/fastfetch/build && \
    cmake .. && \
    make -j$(nproc)


# ==============================================================================
# STAGE 2: Production environment
# Traduzione / Translation: FASE 2: ambiente di produzione
# ==============================================================================
FROM debian:latest

ENV container=docker

# Disable interactive prompts during package installation
# Traduzione / Translation: Disabilita le richieste interattive durante l’installazione dei pacchetti
ARG DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
# Install runtime dependencies
# - Locale: it_IT.UTF-8
# - Networking: iptables, iproute2, dnsmasq, dhcpcd, iw, rfkill
# - Web server: nginx
# - Utilities: jq, aha, procps, nano
# Traduzione / Translation: Installa dipendenze runtime: locale it_IT.UTF-8; rete iptables, iproute2, dnsmasq, dhcpcd, iw e
# IT/EN: rfkill; server web nginx; strumenti jq, aha, procps e nano.
# ------------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends locales && \
    sed -i -e '/it_IT.UTF-8/s/^# //g' -e '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen it_IT.UTF-8 en_US.UTF-8 && \
    update-locale LANG=it_IT.UTF-8 LC_ALL=it_IT.UTF-8 && \
    apt-get install -y --no-install-recommends \
        bash iputils-ping iw nano rfkill gettext e2fsprogs dnsutils \
        iptables net-tools dhcpcd-base isc-dhcp-client procps nginx fcgiwrap spawn-fcgi \
        jq dnsmasq-base iproute2 libnl-3-dev libnl-genl-3-dev libssl-dev aha curl ethtool && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=it_IT.UTF-8
ENV LC_ALL=it_IT.UTF-8


# ------------------------------------------------------------------------------
# Copy compiled binaries from builder stage
# Traduzione / Translation: Copia i binari compilati dalla fase builder
# ------------------------------------------------------------------------------
COPY --from=builder /wpa/hostapd/hostapd /usr/local/bin/hostapd
COPY --from=builder /wpa/hostapd/hostapd_cli /usr/local/bin/hostapd_cli
COPY --from=builder /opt/fastfetch/build/fastfetch /usr/local/bin/fastfetch


# ==============================================================================
# CGI SCRIPTS - Web dashboard backend
# Traduzione / Translation: SCRIPT CGI: backend della dashboard web
# ==============================================================================
RUN mkdir -p /var/www/status/cgi-bin


# ------------------------------------------------------------------------------
# Shared client identity resolver - DHCP, reservations and local neighbours
# No DNS requests or network scans are performed while refreshing the dashboard.
# Traduzione / Translation: Risolutore condiviso dell’identità dei client: DHCP, prenotazioni e neighbor locali. Il refresh non
# IT/EN: esegue query DNS o scansioni di rete.
# ------------------------------------------------------------------------------
RUN mkdir -p /opt/pi-dock-wifi-web
RUN tee /opt/pi-dock-wifi-web/client-identities.sh > /dev/null <<'END_CLIENT_IDENTITIES'
#!/bin/bash
# Resolve clients from local, already available data. No DNS, ping or LAN scan.
# A reservation is explicitly marked as unconfirmed until a valid lease or
# an unambiguous neighbour entry agrees. Shared proxy/bridge MACs are never
# resolved to an arbitrary downstream address.
# Traduzione / Translation: Identifica i client usando dati locali già disponibili, senza DNS, ping o scansioni LAN. Le
# IT/EN: prenotazioni restano non confermate finché non coincidono con un lease valido o un neighbor univoco.
# IT/EN: Un MAC condiviso da proxy/bridge non viene associato arbitrariamente a un indirizzo a valle.
set -o pipefail
export LC_ALL=C
[[ ! -r "${CGI_ENV_FILE:-/etc/cgi-env.sh}" ]] || . "${CGI_ENV_FILE:-/etc/cgi-env.sh}"
now=${CLIENT_NOW:-$(date +%s)}
[[ "$now" =~ ^[0-9]+$ ]] || exit 1
configs=("${DHCP_CONFIG_FILE:-/etc/dnsmasq.conf}")
for file in "${DHCP_CONFIG_DIR:-/etc/dnsmasq.d}"/*.conf; do
    [[ ! -f "$file" ]] || configs+=("$file")
done
{
    printf '__LEASES__\n'
    cat "${DHCP_LEASES_FILE:-/var/lib/misc/dnsmasq.leases}" 2>/dev/null || :
    printf '\n__CONFIG__\n'
    for file in "${configs[@]}"; do [[ ! -r "$file" ]] || cat "$file"; printf '\n'; done
    # dnsmasq can keep reservations and host records in separate local files.
    # Traduzione / Translation: dnsmasq può conservare prenotazioni e record host in file locali separati
    for file in "${configs[@]}"; do
        [[ -r "$file" ]] || continue
        while IFS= read -r line; do
            line=${line%%#*}
            if [[ "$line" =~ ^[[:space:]]*dhcp-hostsfile[[:space:]]*=[[:space:]]*([^[:space:]]+)[[:space:]]*$ ]]; then
                extra=${BASH_REMATCH[1]}
                [[ -f "$extra" && -r "$extra" ]] || continue
                sed 's/^[[:space:]]*/dhcp-host=/' "$extra"
                printf '\n'
            fi
        done <"$file"
    done
    printf '__HOSTS__\n'
    cat "${CLIENT_HOSTS_FILE:-/etc/hosts}" 2>/dev/null || :
    for file in "${configs[@]}"; do
        [[ -r "$file" ]] || continue
        while IFS= read -r line; do
            line=${line%%#*}
            if [[ "$line" =~ ^[[:space:]]*addn-hosts[[:space:]]*=[[:space:]]*([^[:space:]]+)[[:space:]]*$ ]]; then
                extra=${BASH_REMATCH[1]}
                [[ ! -f "$extra" || ! -r "$extra" ]] || cat "$extra"
                printf '\n'
            fi
        done <"$file"
    done
    printf '\n__NEIGHBOURS__\n'
    if [[ -n "${CLIENT_NEIGHBOURS_FILE:-}" ]]; then
        cat "$CLIENT_NEIGHBOURS_FILE" 2>/dev/null || :
    else
        timeout 1 ip -4 neigh show 2>/dev/null || :
    fi
} | awk -v now="$now" -v devices="${CLIENT_LAN_INTERFACE:-br0} ${AP_INTERFACE1:-wlan0} ${AP_INTERFACE2:-wlan1}" '
function trim(s) {gsub(/^[ \t]+|[ \t\r]+$/, "", s); return s}
function ipv4(s, a,n,i) {
    n=split(s,a,"."); if(n!=4)return 0;
    for(i=1;i<=4;i++)if(a[i]!~/^[0-9]+$/ || a[i]+0>255)return 0;
    return a[1]+0>0 && a[1]+0<224 && a[1]+0!=127
}
function mac(s) {return s~/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/}
function hostname(s) {return s!="" && s!="*" && s!~/[[:space:][:cntrl:]]/}
$0=="__LEASES__" {mode=1;next}
$0=="__CONFIG__" {mode=2;next}
$0=="__HOSTS__" {mode=3;next}
$0=="__NEIGHBOURS__" {mode=4;next}
mode==1 && NF>=4 {
    m=tolower($2); expiry=$1;
    if(!mac(m) || !ipv4($3) || expiry!~/^[0-9]+$/ || (expiry!=0 && expiry<=now))next;
    score=(expiry==0?1e15:expiry+0);
    if(score>=lease_score[m]) {lease_score[m]=score;lip[m]=$3;lname[m]=$4;all[m]=1}
    next
}
mode==2 {
    line=$0;sub(/#.*/,"",line);line=trim(line);
    if(line~/^dhcp-host[ \t]*=/) {
        sub(/^[^=]*=/,"",line);n=split(line,a,",");p="";h="";disabled=0;nm=0;
        for(i=1;i<=n;i++) {
            v=trim(a[i]);l=tolower(v);
            if(mac(l)) {ms[++nm]=l}
            else if(ipv4(v))p=v;
            else if(v=="ignore")disabled=1;
            else if(v!~/^(set:|tag:|id:|net:)/ && v!~/^[0-9]+[smhdw]?$/ && v!="infinite" && hostname(v))h=v;
        }
        if(!disabled && p!="")for(i=1;i<=nm;i++) {m=ms[i];rip[m]=p;rname[m]=h;all[m]=1}
    } else if(line~/^host-record[ \t]*=/) {
        sub(/^[^=]*=/,"",line);n=split(line,a,",");h="";
        for(i=1;i<=n;i++){v=trim(a[i]);if(ipv4(v)&&h!="")hosts[v]=h;else if(h==""&&hostname(v)&&v!~/:/)h=v}
    }
    next
}
mode==3 {
    sub(/#.*/,"");if(ipv4($1)&&hostname($2))hosts[$1]=$2;next
}
mode==4 {
    p=$1;m="";dev="";bad=0;
    for(i=2;i<=NF;i++) {
        if($i=="lladdr")m=tolower($(i+1));
        if($i=="dev")dev=$(i+1);
        if($i=="FAILED"||$i=="INCOMPLETE")bad=1;
    }
    if(!ipv4(p)||!mac(m)||bad||index(" " devices " "," " dev " ")==0)next;
    k=m SUBSEP p;
    if(!(k in seen_neigh)){seen_neigh[k]=1;ncount[m]++;nip[m]=p}
    all[m]=1;next
}
END {
    # Active leases take precedence, including over cached proxy ARP entries.
    # Traduzione / Translation: I lease attivi hanno precedenza anche sulle voci proxy ARP in cache
    for(m in lip)owner[lip[m]]=m;
    for(m in all) {
        p="";src="none";confirmed=0;h="";hs="none";
        if(m in lip){p=lip[m];src="lease";confirmed=1}
        else if((m in rip) && (!(rip[m] in owner)||owner[rip[m]]==m)) {
            p=rip[m];src="reservation";
            if(ncount[m]==1 && nip[m]==p){src="neighbor";confirmed=1}
        } else if(ncount[m]==1 && (!(nip[m] in owner)||owner[nip[m]]==m)) {
            p=nip[m];src="neighbor";confirmed=1
        }
        if(hostname(rname[m])){h=rname[m];hs="reservation"}
        else if(hostname(lname[m])){h=lname[m];hs="dhcp"}
        else if(p!=""&&hostname(hosts[p])){h=hosts[p];hs="hosts"}
        # Tabs cannot occur in validated fields; jq supplies full JSON escaping.
        # Traduzione / Translation: I campi validati non contengono tab; jq applica l’escaping JSON completo
        printf "%s\t%s\t%s\t%s\t%d\t%s\n",m,p,h,src,confirmed,hs
    }
}' | jq -Rsc 'split("\n")|map(select(length>0)|split("\t")|{mac:.[0],ip:.[1],hostname:.[2],ip_source:.[3],ip_confirmed:(.[4]=="1"),hostname_source:.[5]})|sort_by(.mac)'
END_CLIENT_IDENTITIES
RUN chmod 755 /opt/pi-dock-wifi-web/client-identities.sh

# ------------------------------------------------------------------------------
# CGI: stats.sh - Local system and wireless snapshot, refreshed every two seconds
# Traduzione / Translation: CGI stats.sh: istantanea locale del sistema e delle radio, aggiornata ogni due secondi
# ------------------------------------------------------------------------------
RUN tee /var/www/status/cgi-bin/stats.sh > /dev/null <<'END_SCRIPT'
#!/bin/bash
# Read each wireless snapshot and the DHCP leases once per response.
# Traduzione / Translation: Legge una sola volta per risposta ogni istantanea radio e i lease DHCP
export LC_ALL=C
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
umask 077
. "${CGI_ENV_FILE:-/etc/cgi-env.sh}"
: "${AP_INTERFACE1:?Missing AP_INTERFACE1}"
: "${INTERNET:?Missing INTERNET}"
AP_INTERFACE2=${AP_INTERFACE2:-}

cpu_cached() {
    local value=0
    [[ ! -r /tmp/cpu_usage_cache ]] || read -r value </tmp/cpu_usage_cache
    [[ "$value" =~ ^[0-9]+$ && "$value" -le 100 ]] || value=0
    printf '%s' "$value"
}
get_cpu() {
    local label cpu_user cpu_nice cpu_sys cpu_idle cpu_io cpu_irq cpu_soft cpu_steal rest
    local total previous_total previous_idle previous_time now delta busy value temp
    exec 201>/tmp/.cpu_calc_lock || { cpu_cached; return; }
    flock -w 2 201 || { cpu_cached; return; }
    read -r label cpu_user cpu_nice cpu_sys cpu_idle cpu_io cpu_irq cpu_soft cpu_steal rest </proc/stat
    total=$((cpu_user + cpu_nice + cpu_sys + cpu_idle + cpu_io + cpu_irq + cpu_soft + cpu_steal))
    read -r now rest </proc/uptime; now=${now%.*}
    value=$(cpu_cached)
    if [[ -r /tmp/cpu_usage_state ]]; then
        read -r previous_total previous_idle previous_time </tmp/cpu_usage_state
        if [[ "$previous_total $previous_idle $previous_time" =~ ^[0-9]+\ [0-9]+\ [0-9]+$ ]]; then
            (( now > previous_time )) || { printf '%s' "$value"; return; }
            delta=$((total - previous_total))
            busy=$((delta - cpu_idle + previous_idle))
            if (( delta > 0 && busy >= 0 && busy <= delta )); then value=$((busy * 100 / delta)); fi
        fi
    fi
    temp=$(mktemp /tmp/cpu_usage_state.XXXXXX) || { printf '%s' "$value"; return; }
    printf '%s %s %s\n' "$total" "$cpu_idle" "$now" >"$temp"
    mv -f "$temp" /tmp/cpu_usage_state
    temp=$(mktemp /tmp/cpu_usage_cache.XXXXXX) || { printf '%s' "$value"; return; }
    printf '%s\n' "$value" >"$temp"; mv -f "$temp" /tmp/cpu_usage_cache
    printf '%s' "$value"
}
get_bytes() {
    local value=0 path="/sys/class/net/$1/statistics/${2}_bytes"
    [[ ! -r "$path" ]] || read -r value <"$path"
    [[ "$value" =~ ^[0-9]+$ ]] || value=0
    printf '%s' "$value"
}
get_wifi_temp() {
    local phy file value
    phy=$(readlink -f "/sys/class/net/$1/phy80211" 2>/dev/null)
    if [[ -n "$phy" ]]; then
        for file in "$phy"/hwmon*/temp1_input; do
            [[ -r "$file" ]] || continue
            read -r value <"$file"
            [[ "$value" =~ ^-?[0-9]+$ ]] || continue
            awk -v t="$value" 'BEGIN {printf "%.1f",t/1000}'; return
        done
    fi
    printf null
}

# One shared local resolver for both the live table and the hosts endpoint.
# Traduzione / Translation: La tabella live e l’endpoint hosts usano lo stesso risolutore locale condiviso
IDENTITIES_JSON=$("${CLIENT_IDENTITIES_HELPER:-/opt/pi-dock-wifi-web/client-identities.sh}") || IDENTITIES_JSON='[]'
wifi='{}'; clients='{}'
for iface in "$AP_INTERFACE1" "$AP_INTERFACE2"; do
    [[ -n "$iface" ]] || continue
    info=$(iw dev "$iface" info 2>/dev/null)
    stations=$(iw dev "$iface" station dump 2>/dev/null)
    ssid=$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*ssid[[:space:]]\+//p')
    channel=$(printf '%s\n' "$info" | awk '$1=="channel" {print $2;exit}')
    width=$(printf '%s\n' "$info" | sed -n 's/.*width: \([0-9]*\).*/\1/p')
    freq=$(printf '%s\n' "$info" | awk '$1=="channel" {gsub(/[^0-9]/,"",$3);print $3;exit}')
    standard=802.11
    if [[ "$freq" =~ ^[0-9]+$ ]]; then
        if (( freq >= 5000 )); then standard='802.11ac/ax (5GHz)'; elif (( freq >= 2400 )); then standard='802.11n/ax (2.4GHz)'; fi
    fi
    records=$(printf '%s\n' "$stations" | awk '
        $1=="Station" {m=tolower($2);order[++n]=m;next}
        $1=="signal:" {signal[m]=$2}
        END {for(i=1;i<=n;i++){m=order[i];r=signal[m];if(r!~/^-?[0-9]+$/)r=-999;
            printf "%s\t%s\n",m,r}}')
    list=$(printf '%s' "$records" | jq -Rsc --argjson known "$IDENTITIES_JSON" '
        ($known|map({key:.mac,value:.})|from_entries) as $names |
        split("\n")|map(select(length>0)|split("\t")|
            . as $row | ($names[$row[0]]//{mac:$row[0],ip:"",hostname:"",ip_source:"none",ip_confirmed:false,hostname_source:"none"}) +
            {rssi:($row[1]|tonumber)})')
    count=$(printf '%s' "$list" | jq length)
    deny="/etc/hostapd/$iface.deny"
    if [[ ! -f "$deny" ]]; then
        if [[ "$iface" == "$AP_INTERFACE1" ]]; then deny=/etc/hostapd/4w.deny; else deny=/etc/hostapd/6w.deny; fi
    fi
    deny_count=0
    [[ ! -r "$deny" ]] || deny_count=$(grep -cvE '^[[:space:]]*$|^[[:space:]]*#' "$deny" 2>/dev/null)
    wifi=$(jq -nc --argjson old "$wifi" --arg iface "$iface" --argjson rx "$(get_bytes "$iface" rx)" --argjson tx "$(get_bytes "$iface" tx)" \
        --arg ssid "${ssid:-n/d}" --argjson count "$count" --argjson temp "$(get_wifi_temp "$iface")" \
        --arg channel "${channel:-n/d}" --arg width "${width:-n/d}" --arg standard "$standard" --argjson deny_count "${deny_count:-0}" \
        '$old+{($iface):{rx:$rx,tx:$tx,info:{ssid:$ssid,client_count:$count},temp:$temp,hostapd:{channel:$channel,width:$width,standard:$standard,deny_count:$deny_count}}}')
    clients=$(jq -nc --argjson old "$clients" --arg iface "$iface" --argjson list "$list" '$old+{($iface):$list}')
done

read -r uptime rest </proc/uptime; uptime=${uptime%.*}
formatted="$((uptime/86400))g $((uptime%86400/3600))h $((uptime%3600/60))min"
ram=$(free | awk '/Mem:/ {if($2>0)printf "%.1f",$3/$2*100;else print 0}')
temp_raw=0
[[ ! -r /sys/class/thermal/thermal_zone0/temp ]] || read -r temp_raw </sys/class/thermal/thermal_zone0/temp
[[ "$temp_raw" =~ ^[0-9]+$ ]] || temp_raw=0
temp=$(awk -v t="$temp_raw" 'BEGIN {printf "%.1f",t/1000}')
jq -nc --arg uptime "$formatted" --argjson cpu "$(get_cpu)" --argjson ram "${ram:-0}" --argjson temp "$temp" \
    --argjson wifi "$wifi" --argjson clients "$clients" '{uptime:$uptime,cpu:$cpu,ram:$ram,temp:$temp,wifi:$wifi,clients:$clients}'
END_SCRIPT


# ------------------------------------------------------------------------------
# CGI: readlog.sh - Returns last N lines of system log (newest first)
# Log file is at /tmp/log.tmp, output is reversed via tac
# Traduzione / Translation: CGI readlog.sh: ultime N righe del log di sistema, dalle più recenti; legge /tmp/log.tmp e inverte con
# IT/EN: tac.
# ------------------------------------------------------------------------------
RUN tee /var/www/status/cgi-bin/readlog.sh > /dev/null <<'END_SCRIPT'
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
    printf 'Errore: Il file di log %s non è ancora stato generato.\n' "$LOG_FILE"
fi
END_SCRIPT


# ------------------------------------------------------------------------------
# CGI: fastfetch.sh - Renders system info (OS, CPU, RAM, etc.) as styled HTML
# Uses fastfetch binary compiled in builder stage
# Displayed inside an iframe at the top of the dashboard
# Traduzione / Translation: CGI fastfetch.sh: rende OS, CPU, RAM e altre informazioni come HTML formattato, usando il binario
# IT/EN: compilato nel builder e un iframe nella parte alta della dashboard.
# ------------------------------------------------------------------------------
RUN tee /var/www/status/cgi-bin/fastfetch.sh > /dev/null <<'END_SCRIPT'
#!/bin/bash
echo "Content-type: text/html"
echo
export PATH=/usr/local/bin:/usr/bin:/bin
FASTFETCH_BIN=$(command -v fastfetch 2>/dev/null)
clean_output() { sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' -e 's/\x1b\[?[0-9;]*[a-z]//g'; }

if [[ -x "$FASTFETCH_BIN" ]]; then
    SYSINFO=$($FASTFETCH_BIN --logo none --structure os:host:kernel:cpu:gpu:memory:swap:disk:localip 2>&1)
    SYSINFO_CLEAN=$(echo "$SYSINFO" | clean_output)
else
    SYSINFO_CLEAN="Fastfetch non trovato"
fi

cat <<'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:transparent;color:#c9d1d9;font-family:'SFMono-Regular',Consolas,'Liberation Mono',Menlo,monospace}
body{padding:8px;display:flex;justify-content:center}
.t{display:flex;width:100%;max-width:860px;background:#0a0e14;border-radius:8px;overflow:hidden;box-shadow:0 5px 16px rgba(0,0,0,.5)}
.lp{padding:22px 16px;display:flex;align-items:center;justify-content:center;border-right:1px solid #30363d;flex-shrink:0}
.logo{font-size:11.5px;line-height:1.12;white-space:pre;color:#fff;font-family:'Courier New',Courier,monospace}
.ip{padding:16px;flex:1;min-width:0;background:#0c1015;display:flex;flex-direction:column;align-items:center;justify-content:center}
.hdr{text-align:center;margin-bottom:12px;padding-bottom:9px;border-bottom:1px solid #30363d;width:100%}
.ti{color:#268bd2;font-size:20px;font-weight:bold}
.st{color:#859900;font-size:13px;margin-top:2px}
.bdg{background:#002b36;border:1px solid #073642;padding:4px 9px;border-radius:5px;margin-top:6px;display:inline-block;font-size:10px;color:#c9d1d9}
.g{display:grid;grid-template-columns:auto 1fr;gap:4px 12px;font-size:13px;width:100%;max-width:420px}
.l{color:#859900;text-align:right;font-weight:bold;white-space:nowrap}
.v{color:#fff;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
@media(max-width:800px){
  .lp{display:none}
  body{padding:4px}
  .ip{padding:12px}
  .ti{font-size:17px}
  .st{font-size:11px}
  .bdg{font-size:9px}
  .g{font-size:12px;gap:3px 10px}
  .hdr{margin-bottom:10px;padding-bottom:7px}
}
@media(max-width:500px){
  .ip{padding:8px}
  .ti{font-size:14px}
  .st{font-size:10px}
  .bdg{font-size:8px;padding:3px 6px}
  .g{font-size:10.5px;gap:2px 6px}
  .v{white-space:normal;word-break:break-word}
  .hdr{margin-bottom:8px;padding-bottom:6px}
}
</style></head><body>
<div class="t" id="root">
  <div class="lp"><div class="logo">&#96;.::///+:/-.        --///+//-:&#96;
 &#96;+oooooooooooo:   &#96;+oooooooooooo:
  /oooo++//ooooo:  ooooo+//+ooooo.
  &#96;+ooooooo:-:oo-  +o+::/ooooooo:
   &#96;:oooooooo+&#96;&#96;    &#96;.oooooooo+-
     &#96;:++ooo/.        :+ooo+/.&#96;
        ...&#96;  &#96;.----.&#96; &#96;&#96;..
     .::::-&#96;&#96;:::::::::.&#96;-:::-&#96;
    -:::-&#96;   .:::::::-&#96;  &#96;-:::-
   &#96;::.  &#96;.--.&#96;  &#96;&#96; &#96;.---.&#96;&#96;.::&#96;
       .::::::::&#96;  -::::::::&#96; &#96;
 .::&#96; .:::::::::- &#96;::::::::::&#96;&#96;::.
-:::&#96; ::::::::::.  ::::::::::.&#96;:::-
::::  -::::::::.   &#96;-::::::::  ::::
-::-   .-:::-.&#96;&#96;....&#96;&#96;.-::-.   -::-
 .. &#96;&#96;       .::::::::.     &#96;..&#96;..
   -:::-&#96;   -::::::::::&#96;  .::::&#96;
   :::::::&#96; -::::::::::&#96; :::::::.
   .:::::::  -::::::::. ::::::::
    &#96;-:::::&#96;   ..--.&#96;   ::::::.
      &#96;...&#96;  &#96;...--..&#96;  &#96;...&#96;
            .::::::::::
             &#96;.-::::-&#96;</div></div>
  <div class="ip">
    <div class="hdr">
      <div class="ti">Pi-Router</div>
      <div class="st">Raspberry Pi 5 - Debian 13</div>
      <div class="bdg">System Status Router Pi-Dock-Wifi</div>
    </div>
    <div class="g">
HTMLEOF

if [[ "$SYSINFO_CLEAN" == "Fastfetch non trovato" ]]; then
    echo "<div class='l'>Errore:</div><div class='v'>Fastfetch non installato</div>"
else
    echo "<div class='l'>OS:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/OS:/ {print $2}')</div>"
    echo "<div class='l'>Host:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Host:/ {print $2}')</div>"
    echo "<div class='l'>Kernel:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Kernel:/ {print $2}')</div>"
    echo "<div class='l'>CPU:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/CPU:/ {print $2}')</div>"
    echo "<div class='l'>GPU:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/GPU:/ {print $2}')</div>"
    echo "<div class='l'>Memory:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Memory:/ {print $2}')</div>"
    echo "<div class='l'>Swap:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Swap:/ {print $2}')</div>"
    echo "<div class='l'>Disk (/):</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Disk \(\/\):/ {print $2}')</div>"
    echo "<div class='l'>Local IP:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Local IP/ {print $2}')</div>"
fi

cat <<'HTMLEOF'
    </div>
  </div>
</div>
<script>
function sh(){var h=document.getElementById('root').offsetHeight+16;try{parent.postMessage({type:'fastfetch-height',height:h},'*')}catch(e){}}
sh();window.onresize=sh;setTimeout(sh,500);setTimeout(sh,1500);
</script>
</body></html>
HTMLEOF
END_SCRIPT


# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# CGI: pihole.sh - Proxy per le API di Pi-hole
# Pi-hole gira in un container separato, questo CGI fa da proxy
# Endpoint: /cgi-bin/pihole.sh (restituisce stats JSON)
# NOTA: l'indirizzo di Pi-hole è configurabile via PIHOLE_HOST in cgi-env.sh
#       default: pihole (nome del container Docker)
# Traduzione / Translation: CGI pihole.sh: proxy for the Pi-hole API in its separate container. /cgi-bin/pihole.sh returns JSON
# IT/EN: statistics. PIHOLE_HOST is configurable in cgi-env.sh; the stated default is the Docker container name
# IT/EN: pihole.
# ------------------------------------------------------------------------------
RUN tee /var/www/status/cgi-bin/pihole.sh > /dev/null <<'END_SCRIPT'
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
    echo '{"status": "offline", "error": "Troppe sessioni API Pi-hole aperte. Attendi qualche minuto."}'
else
    echo '{"status": "offline", "error": "Pi-hole non raggiungibile"}'
fi
END_SCRIPT


# ------------------------------------------------------------------------------
# CGI: hostapd_ctl.sh - Gestione container e deny list
# Supporta:
#   GET  (senza params) -> stato attuale + deny list + deny enabled status
#   POST action=restart_container -> kill PID 1, Docker restart: always lo riavvia
#   POST action=add_deny&iface=wlanX&mac=XX:XX:XX:XX:XX:XX -> aggiungi MAC
#   POST action=remove_deny&iface=wlanX&mac=XX:XX:XX:XX:XX:XX -> rimuovi MAC
#   POST action=enable_deny&iface=wlanX -> abilita deny file in hostapd
#   POST action=disable_deny&iface=wlanX -> disabilita deny file in hostapd
# Traduzione / Translation: CGI hostapd_ctl.sh manages container restart and deny lists: GET reports state, list and enabled
# IT/EN: status; POST restart_container terminates PID 1 and Docker restarts it; add_deny/remove_deny
# IT/EN: add/remove a MAC; enable_deny/disable_deny toggle the selected interface’s hostapd deny file.
# ------------------------------------------------------------------------------
RUN tee /var/www/status/cgi-bin/wps.sh > /dev/null <<'END_SCRIPT'
#!/bin/bash
# WPS a pulsante. Autenticazione e controllo Origin sono gestiti da nginx/auth.sh.
# hostapd chiude la finestra dopo 120 secondi: non servono timer in background.
# Traduzione / Translation: Push-button WPS. nginx/auth.sh enforce authentication and Origin checks; hostapd closes the window
# IT/EN: after 120 seconds, without background timers.
set -uo pipefail
umask 077
. "${CGI_ENV_FILE:-/etc/cgi-env.sh}"

ROOT=${HOSTAPD_CONFIG_DIR:-/etc/hostapd}
CLI=${HOSTAPD_CLI:-hostapd_cli}
STATE=${WPS_STATE_DIR:-/run/pi-dock-wifi/wps}
interfaces=("${AP_INTERFACE1:?}")
[[ -z "${AP_INTERFACE2:-}" ]] || interfaces+=("$AP_INTERFACE2")

reply() {
    printf 'Status: %s\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n\r\n%s\n' "$1" "$2"
    exit 0
}
fail() {
    reply "$1" "$(jq -nc --arg error "$2" '{success:false,error:$error}')"
}
exec 200>"${HOSTAPD_LOCK_FILE:-/tmp/hostapd_ctl.lock}"
flock -w 3 -x 200 || fail '409 Conflict' 'Operazione Wi-Fi in corso. Riprova.'

select_interface() {
    local candidate=$1
    [[ "$candidate" =~ ^[a-zA-Z0-9_.:-]{1,15}$ ]] || return 1
    if [[ "$candidate" == "$AP_INTERFACE1" ]]; then
        conf="$ROOT/hostapd_46w.conf"
    elif [[ -n "${AP_INTERFACE2:-}" && "$candidate" == "$AP_INTERFACE2" ]]; then
        conf="$ROOT/hostapd_56w.conf"
    else
        return 1
    fi
    iface=$candidate
    [[ -r "$conf" ]]
}
config_value() {
    awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$conf"
}
cli() {
    timeout 3 "$CLI" -i "$iface" raw "$@" 2>/dev/null
}
cli_ok() {
    local response
    response=$(cli "$@") && [[ "$response" == OK ]]
}
uptime_seconds() {
    awk '{ printf "%.0f\n", int($1) }' /proc/uptime
}

read_status() {
    local output radio started=0 now
    supported=false; ready=false; state=unavailable; last_result=''; remaining=null
    reason='WPS non disponibile su questa rete.'
    output=$(cli WPS_GET_STATUS) || return 0
    [[ "$output" == *'PBC Status: '* ]] || return 0
    supported=true
    radio=$(timeout 3 "$CLI" -i "$iface" status 2>/dev/null) || radio=''
    state=idle; reason=''
    last_result=$(awk -F': ' '$1 == "Last WPS result" { print $2; exit }' <<< "$output")
    if [[ "$(config_value ignore_broadcast_ssid)" == 1 || "$(config_value ignore_broadcast_ssid)" == 2 ]]; then
        state=disabled; reason='WPS richiede che il nome della rete sia visibile.'
    elif [[ "$(config_value wps_state)" != 2 ]]; then
        state=disabled; reason='WPS non abilitato su questa rete.'
    elif [[ "$(config_value config_methods)" != virtual_push_button ||
            "$(config_value ap_setup_locked)" != 1 ||
            -n "$(config_value ap_pin)" ||
            "$(config_value wps_independent)" != 0 ]]; then
        state=disabled; reason='La rete non è configurata per WPS solo a pulsante.'
    elif ! grep -qx 'state=ENABLED' <<< "$radio"; then
        state=disabled; reason='La rete Wi-Fi non è pronta.'
    else
        ready=true
    fi
    if grep -qx 'PBC Status: Active' <<< "$output"; then
        state=active
        { read -r started < "$STATE/$iface.started"; } 2>/dev/null || started=0
        if [[ "$started" =~ ^[0-9]{1,10}$ && "$started" != 0 ]]; then
            now=$(uptime_seconds)
            remaining=$(( 120 - (now - 10#$started) ))
            (( remaining < 0 )) && remaining=0
            (( remaining > 120 )) && remaining=120
        fi
    elif grep -qx 'PBC Status: Overlap' <<< "$output"; then
        state=overlap; reason='Più dispositivi richiedono WPS. Annulla e riprova con uno solo.'
    fi
}
status_json() {
    jq -nc --arg state "$state" --arg reason "$reason" --arg result "$last_result" \
        --argjson supported "$supported" --argjson ready "$ready" --argjson seconds "$remaining" \
        '{state:$state,reason:$reason,last_result:$result,supported:$supported,ready:$ready,remaining_seconds:$seconds}'
}

# Ripetere CANCEL è innocuo e copre anche un'eventuale sessione parziale.
# Traduzione / Translation: Repeating CANCEL is harmless and also covers a partially opened session
cancel_sessions() {
    local candidate failed=false
    for candidate in "${interfaces[@]}"; do
        if select_interface "$candidate" && cli_ok WPS_CANCEL; then
            rm -f -- "$STATE/$candidate.started"
        else
            failed=true
        fi
    done
    [[ "$failed" == false ]]
}

case "${REQUEST_METHOD:-GET}" in
    GET)
        result='{}'
        for candidate in "${interfaces[@]}"; do
            select_interface "$candidate" || fail '503 Service Unavailable' 'Configurazione Wi-Fi non disponibile.'
            read_status
            result=$(jq -nc --argjson all "$result" --arg iface "$iface" --argjson status "$(status_json)" '$all + {($iface):$status}')
        done
        reply '200 OK' "$(jq -nc --argjson interfaces "$result" '{success:true,interfaces:$interfaces}')"
        ;;
    POST)
        [[ "${CONTENT_TYPE:-}" == application/x-www-form-urlencoded* &&
           "${CONTENT_LENGTH:-}" =~ ^[1-9][0-9]{0,2}$ && "$CONTENT_LENGTH" -le 128 ]] ||
            fail '400 Bad Request' 'Richiesta non valida.'
        body=''; IFS= read -r -N "$CONTENT_LENGTH" body || true
        [[ ${#body} -eq "$CONTENT_LENGTH" ]] || fail '400 Bad Request' 'Richiesta incompleta.'
        case "$body" in
            action=start) action=start ;;
            action=cancel) action=cancel ;;
            *) fail '400 Bad Request' 'Azione o parametri non consentiti.' ;;
        esac
        if [[ "$action" == cancel ]]; then
            cancel_sessions || fail '503 Service Unavailable' 'Impossibile annullare WPS su entrambe le bande.'
            reply '200 OK' '{"success":true,"message":"Associazione WPS annullata su entrambe le bande."}'
        fi
        # Il router usa un solo SSID e un solo processo hostapd. Controlliamo
        # entrambe le reti prima di aprire la stessa sessione sulle due radio.
        # Traduzione / Translation: The router uses one SSID and one hostapd process. Check both networks before opening the same pairing
        # IT/EN: session on both radios.
        select_interface "${interfaces[0]}" || fail '503 Service Unavailable' 'Configurazione Wi-Fi non disponibile.'
        declare -A shared
        for key in uuid ssid wpa_passphrase wpa_psk; do
            shared[$key]=$(config_value "$key")
        done
        [[ "${shared[uuid]}" =~ ^[a-f0-9-]{36}$ ]] || fail '409 Conflict' 'Identità WPS comune non configurata.'
        for candidate in "${interfaces[@]}"; do
            select_interface "$candidate" || fail '503 Service Unavailable' 'Configurazione Wi-Fi non disponibile.'
            read_status
            [[ "$ready" == true ]] || fail '409 Conflict' "$reason"
            for key in "${!shared[@]}"; do
                [[ "$(config_value "$key")" == "${shared[$key]}" ]] ||
                    fail '409 Conflict' 'Le due bande non condividono la stessa configurazione Wi-Fi.'
            done
        done
        cancel_sessions || fail '503 Service Unavailable' 'Impossibile chiudere la sessione WPS precedente.'
        mkdir -p "$STATE" && chmod 700 "$STATE" || fail '503 Service Unavailable' 'Impossibile preparare WPS.'
        started=$(uptime_seconds)
        for candidate in "${interfaces[@]}"; do
            printf '%s\n' "$started" > "$STATE/$candidate.started" ||
                fail '503 Service Unavailable' 'Impossibile registrare la sessione WPS.'
        done
        select_interface "${interfaces[0]}"
        # wps_independent=0 fa coordinare a hostapd l'apertura, l'annullamento
        # e la conclusione della sessione sulle due bande dello stesso AP.
        # Traduzione / Translation: and completion of the session on both bands of the same AP
        if ! cli_ok WPS_PBC; then
            cancel_sessions || true
            fail '503 Service Unavailable' 'Impossibile avviare WPS. Riprova.'
        fi
        for candidate in "${interfaces[@]}"; do
            select_interface "$candidate"
            read_status
            if [[ "$state" != active ]]; then
                cancel_sessions || true
                fail '503 Service Unavailable' 'WPS non attivo su entrambe le bande. Sessione annullata.'
            fi
        done
        reply '200 OK' '{"success":true,"message":"WPS aperto su 2,4 e 5 GHz per due minuti. Premi il pulsante WPS del dispositivo."}'

        ;;
    *) fail '405 Method Not Allowed' 'Metodo non consentito.' ;;
esac
END_SCRIPT

RUN tee /var/www/status/cgi-bin/hostapd_ctl.sh > /dev/null <<'END_SCRIPT'
#!/bin/bash
# Persist changes and reconcile hostapd's in-memory ACL without restarting an AP.
# Traduzione / Translation: Salva le modifiche e riconcilia l’ACL in memoria di hostapd senza riavviare l’AP
set -uo pipefail
umask 077
. "${CGI_ENV_FILE:-/etc/cgi-env.sh}"
: "${AP_INTERFACE1:?}" "${AP_INTERFACE2:?}"
ROOT=${HOSTAPD_CONFIG_DIR:-/etc/hostapd}
CLI=${HOSTAPD_CLI:-hostapd_cli}
exec 200>"${HOSTAPD_LOCK_FILE:-/tmp/hostapd_ctl.lock}"
flock -x 200
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
fail() { jq -nc --arg error "$1" '{success:false,error:$error}'; exit 0; }
valid_mac() { [[ "$1" =~ ^([a-f0-9]{2}:){5}[a-f0-9]{2}$ ]]; }
select_iface() {
    case "$1" in
        "$AP_INTERFACE1") stem=46w; deny="$ROOT/4w.deny" ;;
        "$AP_INTERFACE2") stem=56w; deny="$ROOT/6w.deny" ;;
        *) return 1 ;;
    esac
    [[ ! -f "$ROOT/$1.deny" ]] || deny="$ROOT/$1.deny"
    iface=$1
    conf="$ROOT/hostapd_$stem.conf"
    tmpl="$conf.template"
    [[ -f "$deny" && -f "$conf" && -f "$tmpl" ]]
}
read_list() {
    local line mac
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=${line%%#*}
        read -r mac _ <<< "$line"
        [[ -z "$mac" ]] && continue
        mac=${mac,,}
        valid_mac "$mac" || return 1
        printf '%s\n' "$mac"
    done < "$1" | sort -u
}
runtime_list() {
    local output line mac
    output=$("$CLI" -i "$iface" deny_acl SHOW 2>/dev/null) || return 1
    [[ "$output" != *FAIL* && "$output" != *'Could not'* && "$output" != *UNKNOWN* ]] || return 1
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == 'Selected interface '* ]] && continue
        read -r mac _ <<< "$line"
        mac=${mac,,}
        valid_mac "$mac" || return 1
        printf '%s\n' "$mac"
    done <<< "$output" | sort -u
}
cli_ok() {
    local response
    response=$("$CLI" -i "$iface" "$@" 2>/dev/null) || return 1
    [[ "$response" == OK ]]
}
configured_enabled() {
    grep -q '^deny_mac_file=' "$conf" && grep -q '^deny_mac_file=' "$tmpl"
}
sync_acl() {
    local desired=$1 current mac
    current=$(runtime_list) || return 1
    # Add first so previously blocked devices never become temporarily allowed.
    # Traduzione / Translation: Aggiunge prima i blocchi: i dispositivi già bloccati non diventano temporaneamente autorizzati
    while IFS= read -r mac; do
        [[ -z "$mac" ]] && continue
        grep -qxF "$mac" <<< "$current" || cli_ok deny_acl ADD_MAC "$mac" || return 1
    done <<< "$desired"
    while IFS= read -r mac; do
        [[ -z "$mac" ]] && continue
        grep -qxF "$mac" <<< "$desired" || cli_ok deny_acl DEL_MAC "$mac" || return 1
    done <<< "$current"
    current=$(runtime_list) || return 1
    [[ "$current" == "$desired" ]]
}
write_config() {
    local file=$1 enabled=$2
    sed '/^[[:space:]#]*macaddr_acl=/d; /^[[:space:]#]*deny_mac_file=/d' "$file" > "$tx/new" || return 1
    printf '\nmacaddr_acl=0\n' >> "$tx/new"
    [[ "$enabled" == false ]] || printf 'deny_mac_file=%s\n' "$deny" >> "$tx/new"
    # Preserve inode: templates are individual bind mounts.
    # Traduzione / Translation: Conserva l’inode: i template sono bind mount di singoli file
    cat "$tx/new" > "$file" && chmod 600 "$file"
}
json_list() { if [[ -n "$1" ]]; then printf '%s\n' "$1" | jq -R . | jq -s .; else printf '[]'; fi; }
decode() { local s=${1//+/ }; [[ "$s" != *\\* ]] || return 1; printf '%b' "${s//%/\\x}"; }
if [[ "${REQUEST_METHOD:-GET}" == POST ]]; then
    [[ "${CONTENT_LENGTH:-}" =~ ^[0-9]+$ && "$CONTENT_LENGTH" -le 4096 ]] || fail 'Richiesta non valida'
    post=''; IFS= read -r -N "$CONTENT_LENGTH" post || true
    action=''; iface=''; mac=''
    IFS='&' read -ra fields <<< "$post"
    for field in "${fields[@]}"; do
        key=${field%%=*}; value=$(decode "${field#*=}") || fail 'Parametro non valido'
        case "$key" in action) action=$value ;; iface) iface=$value ;; mac) mac=${value,,} ;; esac
    done
    if [[ "$action" == restart_container ]]; then
        printf '{"success":true,"message":"Container in riavvio..."}\n'
        (sleep 1; kill 1) >/dev/null 2>&1 &
        exit 0
    fi
    case "$action" in add_deny|remove_deny|enable_deny|disable_deny) ;; *) fail 'Azione non riconosciuta' ;; esac
    select_iface "$iface" || fail 'Interfaccia o configurazione non valida'
    [[ "$action" != add_deny && "$action" != remove_deny ]] || valid_mac "$mac" || fail 'Formato MAC non valido'
    old_list=$(read_list "$deny") || fail 'Deny list non valida'
    old_acl=$(runtime_list) || fail 'hostapd non raggiungibile'
    enabled=false; configured_enabled && enabled=true
    new_list=$old_list
    case "$action" in
        add_deny)
            grep -qxF "$mac" <<< "$old_list" && fail 'MAC già nella deny list'
            new_list=$(printf '%s\n%s\n' "$old_list" "$mac" | sed '/^$/d' | sort -u)
            ;;
        remove_deny) new_list=$(printf '%s\n' "$old_list" | sed "/^$mac$/d; /^$/d") ;;
        enable_deny) enabled=true ;;
        disable_deny) enabled=false ;;
    esac
    tx=$(mktemp -d /tmp/hostapd-transaction.XXXXXX) || fail 'Impossibile preparare modifica'
    cp "$deny" "$tx/deny" && cp "$conf" "$tx/conf" && cp "$tmpl" "$tx/tmpl" || { rm -rf "$tx"; fail 'Impossibile salvare configurazione'; }
    committed=false
    rollback() {
        local failed=false
        if [[ "$committed" == false ]]; then
            cat "$tx/deny" > "$deny" || failed=true
            cat "$tx/conf" > "$conf" || failed=true
            cat "$tx/tmpl" > "$tmpl" || failed=true
            sync_acl "$old_acl" || failed=true
            [[ "$failed" == false ]] || printf 'hostapd_ctl: ripristino incompleto su %s\n' "$iface" >&2
        fi
        rm -rf "$tx"
    }
    trap rollback EXIT
    trap 'exit 1' TERM INT HUP
    desired=''; [[ "$enabled" == false ]] || desired=$new_list
    sync_acl "$desired" || fail 'Aggiornamento hostapd fallito; ripristino in corso'
    if [[ -n "$new_list" ]]; then printf '%s\n' "$new_list" > "$deny"; else : > "$deny"; fi
    [[ $? == 0 ]] && chmod 600 "$deny" && write_config "$conf" "$enabled" && write_config "$tmpl" "$enabled" || fail 'Salvataggio fallito; ripristino in corso'
    committed=true
    jq -nc --arg action "$action" --arg mac "$mac" --argjson enabled "$enabled" '{success:true,message:(if $action=="enable_deny" then "Deny list abilitata e applicata" elif $action=="disable_deny" then "Deny list disabilitata e applicata" elif $action=="add_deny" then ($mac+" aggiunto"+(if $enabled then " e bloccato" else " alla lista disabilitata" end)) else ($mac+" rimosso") end)}'
    exit 0
fi
[[ "${REQUEST_METHOD:-GET}" == GET ]] || fail 'Metodo non consentito'
result='{}'
for ap in "$AP_INTERFACE1" "$AP_INTERFACE2"; do
    select_iface "$ap" || fail 'Configurazione hostapd mancante'
    list=$(read_list "$deny") || fail 'Deny list non valida'
    enabled=false; configured_enabled && enabled=true
    desired=''; [[ "$enabled" == false ]] || desired=$list
    synchronized=false
    live=$(runtime_list) && [[ "$live" == "$desired" ]] && synchronized=true
    result=$(jq -nc --argjson r "$result" --arg iface "$ap" --arg file "$deny" --argjson list "$(json_list "$list")" --argjson enabled "$enabled" --argjson synced "$synchronized" '$r + {($iface):{deny_file:$file,deny_list:$list,deny_enabled:$enabled,acl_synchronized:$synced}}')
done
jq -nc --argjson interfaces "$result" '{interfaces:$interfaces}'
END_SCRIPT


# ------------------------------------------------------------------------------
# CGI: hosts.sh -— endpoint CGI che espone la mappa IP → hostname del router.
# Traduzione / Translation: CGI hosts.sh: exposes the router’s IP-to-hostname mapping
# ------------------------------------------------------------------------------
RUN tee /var/www/status/cgi-bin/hosts.sh > /dev/null <<'END_SCRIPT'
#!/bin/bash
# Preserve the existing hosts API, using the same resolver as the live table.
# No network name lookups and no separate, inconsistent reservation parser.
# Traduzione / Translation: Conserva l’API hosts usando lo stesso risolutore della tabella live, senza risoluzioni di rete né un
# IT/EN: parser delle prenotazioni separato e incoerente.
printf 'Content-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-store\r\n\r\n'
"${CLIENT_IDENTITIES_HELPER:-/opt/pi-dock-wifi-web/client-identities.sh}" |
    jq '[.[] | select(.ip!="") | {ip,mac,hostname,ip_source,ip_confirmed,hostname_source}]'
END_SCRIPT



# ------------------------------------------------------------------------------
# CGI: auth.sh - Dashboard authentication and session checks
# Credentials remain runtime environment values; no secrets are embedded.
# Traduzione / Translation: CGI auth.sh: autenticazione della dashboard e controllo delle sessioni; le credenziali restano
# IT/EN: variabili runtime, senza segreti incorporati.
# ------------------------------------------------------------------------------
RUN tee /var/www/status/cgi-bin/auth.sh > /dev/null <<'END_DASHBOARD_AUTH'
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
[[ -r "$STATE/password.sha256" ]] || reply '503 Service Unavailable' '' '{"error":"Login non configurato"}'
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
        [[ "${actual%% *}" == "$expected" ]] || reply '401 Unauthorized' '' '{"error":"Password non corretta"}'
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
END_DASHBOARD_AUTH


# ------------------------------------------------------------------------------
# Make all CGI scripts executable
# Traduzione / Translation: Rende eseguibili tutti gli script CGI
# ------------------------------------------------------------------------------
RUN chmod 755 /var/www/status/cgi-bin/*.sh


RUN tee /etc/nginx/nginx.conf > /dev/null <<'END_NGINX'
user www-data;
worker_processes 1;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log warn;
events { worker_connections 256; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    access_log /var/log/nginx/access.log;
    limit_req_zone $binary_remote_addr zone=dashboard_login:1m rate=5r/m;
    server {
        listen 8888;
        server_name _;
        root /var/www/status;
        index index.html;
        client_max_body_size 4k;
        absolute_redirect off;
        auth_request /_dashboard_auth;
        add_header Cache-Control "no-store" always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options SAMEORIGIN always;
        location = /_dashboard_auth {
            internal;
            auth_request off;
            include /etc/nginx/fastcgi_params;
            fastcgi_pass unix:/var/run/fcgiwrap.socket;
            fastcgi_pass_request_body off;
            fastcgi_param CONTENT_LENGTH "";
            fastcgi_param SCRIPT_FILENAME /var/www/status/cgi-bin/auth.sh;
            fastcgi_param AUTH_ACTION check;
            fastcgi_param HTTP_X_ORIGINAL_METHOD $request_method;
            fastcgi_param HTTP_X_ORIGINAL_URI $request_uri;
        }
        location = /login.html { auth_request off; try_files $uri =404; }
        location = /auth/login {
            auth_request off;
            limit_req zone=dashboard_login burst=5 nodelay;
            limit_req_status 429;
            include /etc/nginx/fastcgi_params;
            fastcgi_pass unix:/var/run/fcgiwrap.socket;
            fastcgi_param SCRIPT_FILENAME /var/www/status/cgi-bin/auth.sh;
            fastcgi_param AUTH_ACTION login;
        }
        location = /auth/logout {
            auth_request off;
            include /etc/nginx/fastcgi_params;
            fastcgi_pass unix:/var/run/fcgiwrap.socket;
            fastcgi_param SCRIPT_FILENAME /var/www/status/cgi-bin/auth.sh;
            fastcgi_param AUTH_ACTION logout;
        }
        location = /cgi-bin/auth.sh { return 404; }
        location @dashboard_login { auth_request off; return 303 /login.html; }
        location / {
            error_page 401 = @dashboard_login;
            try_files $uri $uri/ =404;
        }
        location ~ ^/cgi-bin/(stats|readlog|fastfetch|pihole|hostapd_ctl|hosts|wps)\.sh$ {
            gzip off;
            include /etc/nginx/fastcgi_params;
            fastcgi_pass unix:/var/run/fcgiwrap.socket;
            fastcgi_param SCRIPT_FILENAME /var/www/status$fastcgi_script_name;
        }
        location /cgi-bin/ { return 404; }
        location /terminal/ws {
            proxy_pass http://127.0.0.1:3000/ws;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host 127.0.0.1:3000;
            proxy_set_header Origin http://127.0.0.1:3000;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_read_timeout 86400s;
            proxy_send_timeout 86400s;
        }
        location /terminal/ {
            proxy_buffering off;
            proxy_pass http://127.0.0.1:3000/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_read_timeout 86400s;
        }
    }
}
END_NGINX

RUN rm -f /etc/nginx/sites-enabled/default
RUN mkdir -p /var/log/nginx && chown www-data:www-data /var/log/nginx

# ==============================================================================
# WEB DASHBOARD - index.html
# Traduzione / Translation: DASHBOARD WEB: index.html
# ==============================================================================
# Nuove funzionalità:
#   - Segnale WiFi (RSSI) per ogni client nella tabella con barre visive
#   - Pi-hole integration: widget con stats DNS (query, blocchi, top domini)
#   - Notifiche e alert: campanella con badge, tracking connect/disconnect client
#   - Gestione hostapd: info canale/banda/standard, deny list, restart AP
# Miglioramenti precedenti:
#   - Segnale WiFi (RSSI) per ogni client nella tabella
#   - Pi-hole integration: widget con stats DNS (query, blocchi, top domini)
#   - Notifiche e alert: campanella con badge contatore nell'header
#   - Gestione hostapd: pannello con info canale/banda, deny list, restart
#   - Design curato con CSS variables e dark mode toggle
#   - Pausa automatica del refresh quando si seleziona testo
#   - Doppio click su cella tabella = copia negli appunti
#   - Indicatore di stato connessione (pallino verde/rosso)
#   - Stat cards con colori semantici (verde/giallo/rosso per soglie)
#   - Skeleton loading per le stat cards
#   - Parsing JSON robusto (gestisce preamble CGI prima del JSON)
#   - Fix: rimosso riferimento a ethChart inesistente
#   - Fix: tag </body> posizionato correttamente
#   - Log: nessun auto-scroll (i log arrivano già ordinati dal più recente)
#   - Responsive migliorato per mobile
#   - Font: IBM Plex Sans + IBM Plex Mono (caricati da Google Fonts)
# Traduzione / Translation: Features: per-client RSSI bars; Pi-hole DNS statistics; connection notifications; hostapd
# IT/EN: channel/band/standard and deny-list controls. Existing behavior includes dark mode, selection-aware
# IT/EN: refresh pause, double-click copy, connection indicators, threshold colors, loading skeletons, robust
# IT/EN: CGI/JSON parsing, corrected chart/body references, newest-first logs without auto-scroll, mobile
# IT/EN: layout and IBM Plex fonts from Google Fonts.
# ==============================================================================
RUN mkdir -p /var/www/status
RUN tee /var/www/status/index.html > /dev/null <<'END_SCRIPT'
<!DOCTYPE html>
<html lang="it">
<head>
<script>
const originalFetch = window.fetch.bind(window);
let dashboardRedirecting = false;
function dashboardLogin() {
  if (dashboardRedirecting) return;
  dashboardRedirecting = true;
  const terminal = document.getElementById('customIframe');
  if (terminal) terminal.remove();
  window.location.replace('/login.html');
}
window.fetch = async function(input, options) {
  const url = new URL(typeof input === 'string' ? input : input.url, location.href);
  if (url.origin === location.origin) {
    options = Object.assign({}, options);
    options.headers = new Headers(options.headers || (input.headers || {}));
    options.headers.set('X-Dashboard-Request', '1');
  }
  const response = await originalFetch(input, options);
  if (url.origin === location.origin && response.status === 401) dashboardLogin();
  return response;
};
async function logoutDashboard() {
  const response = await fetch('/auth/logout', {method:'POST'});
  await response.text();
  dashboardLogin();
}
</script>

  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Status Router Pi-Dock-Wifi</title>
  <script>
  (function(){
    // Solo se siamo su un IP numerico | IT/EN: Only when the current hostname is a numeric IP address
    if(!/^(\d+\.){3}\d+$/.test(window.location.hostname)) return;
    
    // Se abbiamo già testato in questa sessione, non riprovare | IT/EN: Do not retry if this session has already checked
    try {
      if(sessionStorage.getItem('pi-mdns-failed')) return;
    } catch(e){}
    
    // Testa se pi-dock-wifi.local è raggiungibile prima di fare redirect | IT/EN: Check pi-dock-wifi.local before redirecting
    var testUrl = 'http://pi-dock-wifi.local:' + window.location.port + '/cgi-bin/stats.sh';
    var ctrl = new AbortController();
    var timer = setTimeout(function(){ ctrl.abort(); }, 3000);
    
    fetch(testUrl, { signal: ctrl.signal, mode: 'no-cors' })
      .then(function(){
        clearTimeout(timer);
        window.location.replace('http://pi-dock-wifi.local:' + window.location.port + window.location.pathname);
      })
      .catch(function(){
        clearTimeout(timer);
        try { sessionStorage.setItem('pi-mdns-failed','1'); } catch(e){}
        // Resta sull'IP — nessun redirect | IT/EN: Stay on the IP address without redirecting
      });
  })();
  </script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg:#eef1f5;--bg-card:#ffffff;--bg-card-hover:#f8fafc;--text:#1a2332;--text-muted:#5a6a7e;
      --border:#d8dee6;--accent:#0a6e8a;--accent-light:#e6f4f8;--accent-glow:rgba(10,110,138,0.15);
      --danger:#d94452;--success:#2a9d6e;--warning:#e0a030;
      --shadow-sm:0 1px 3px rgba(0,0,0,0.06);--shadow-md:0 4px 12px rgba(0,0,0,0.08);
      --radius:10px;--font:'IBM Plex Sans',-apple-system,sans-serif;--font-mono:'IBM Plex Mono','Consolas',monospace;
      --transition:0.25s cubic-bezier(0.4,0,0.2,1);
    }
    [data-theme="dark"] {
      --bg:#0f1419;--bg-card:#1a2332;--bg-card-hover:#1f2b3d;--text:#e2e8f0;--text-muted:#8899aa;
      --border:#2a3a4e;--accent:#38bdf8;--accent-light:#0c2a3a;--accent-glow:rgba(56,189,248,0.12);
      --shadow-sm:0 1px 3px rgba(0,0,0,0.2);--shadow-md:0 4px 12px rgba(0,0,0,0.3);
    }
    *{box-sizing:border-box;margin:0;padding:0}
    html,body{overflow-x:hidden}
    body{font-family:var(--font);background:var(--bg);color:var(--text);transition:background var(--transition),color var(--transition);line-height:1.5}

    /* HEADER 
 IT/EN: INTESTAZIONE
*/
    .header{background:var(--bg-card);border-bottom:1px solid var(--border);padding:9px 14px;position:sticky;top:0;z-index:100;box-shadow:var(--shadow-sm);display:flex;align-items:center;justify-content:space-between;gap:8px;flex-wrap:nowrap}
    .header-title{font-size:1em;font-weight:600;color:var(--accent);display:flex;align-items:center;gap:5px;white-space:nowrap;flex-shrink:0}
    .header-title svg{width:18px;height:18px}
    .header-right{display:flex;align-items:center;gap:7px;flex-shrink:1;min-width:0}
    .status-dot{width:7px;height:7px;border-radius:50%;background:var(--success);box-shadow:0 0 5px var(--success);flex-shrink:0}
    .status-dot.error{background:var(--danger);box-shadow:0 0 5px var(--danger)}
    .pause-badge{display:none;align-items:center;gap:3px;background:var(--warning);color:#fff;font-size:0.65em;font-weight:600;padding:2px 7px;border-radius:10px;animation:pulse 1.5s ease-in-out infinite}
    .pause-badge.visible{display:inline-flex}
    @keyframes pulse{0%,100%{opacity:1}50%{opacity:.7}}
    .notif-wrap{position:relative}
    .notif-btn{background:none;border:none;cursor:pointer;color:var(--text-muted);padding:2px}
    .notif-btn svg{width:17px;height:17px}
    .notif-badge{position:absolute;top:-3px;right:-5px;background:var(--danger);color:#fff;font-size:.5em;font-weight:700;min-width:13px;height:13px;border-radius:7px;display:none;align-items:center;justify-content:center;padding:0 2px}
    .notif-badge.visible{display:flex}
    .notif-dropdown{display:none;position:absolute;top:100%;right:0;width:300px;max-height:360px;background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);box-shadow:var(--shadow-md);overflow-y:auto;z-index:200;margin-top:5px}
    .notif-dropdown.open{display:block}
    .notif-dropdown-header{display:flex;align-items:center;justify-content:space-between;padding:7px 10px;border-bottom:1px solid var(--border);font-size:.78em;font-weight:600;color:var(--text-muted)}
    .notif-clear{background:none;border:none;color:var(--accent);cursor:pointer;font-size:.78em}
    .notif-item{padding:7px 10px;border-bottom:1px solid var(--border);font-size:.78em;display:flex;gap:7px;align-items:flex-start}
    .notif-item:last-child{border-bottom:none}
    .ni{width:7px;height:7px;border-radius:50%;flex-shrink:0;margin-top:4px}
    .ni.info{background:var(--accent)}.ni.warn{background:var(--warning)}.ni.error{background:var(--danger)}.ni.success{background:var(--success)}
    .notif-empty{padding:14px;text-align:center;color:var(--text-muted);font-size:.8em}
    #headerClock{font-family:var(--font-mono);font-size:.72em;color:var(--text-muted);white-space:nowrap}
    .theme-toggle{width:36px;height:20px;background:var(--border);border-radius:10px;border:none;cursor:pointer;position:relative;flex-shrink:0}
    .theme-toggle::after{content:'';position:absolute;width:16px;height:16px;background:var(--bg-card);border-radius:50%;top:2px;left:2px;transition:transform var(--transition);box-shadow:0 1px 2px rgba(0,0,0,.2)}
    [data-theme="dark"] .theme-toggle{background:var(--accent)}
    [data-theme="dark"] .theme-toggle::after{transform:translateX(16px)}
    @media(max-width:500px){
      .header{padding:7px 10px}
      .header-title{font-size:.88em}
      #headerClock{font-size:.65em}
    }

    /* MAIN 
 IT/EN: SEZIONE PRINCIPALE
*/
    .main-content{padding:14px;max-width:1200px;margin:0 auto}
    @media(max-width:768px){.main-content{padding:10px}}

    /* FASTFETCH 
 IT/EN: FASTFETCH
*/
    .fastfetch-box{width:100%;overflow:hidden;background:var(--bg)}
    .fastfetch-iframe{width:100%;border:none;display:block;background:transparent;height:540px}
    @media(max-width:800px){.fastfetch-iframe{height:420px}}
    @media(max-width:500px){.fastfetch-iframe{height:auto;min-height:220px}}

    /* STAT CARDS 
 IT/EN: SCHEDE STATISTICHE
*/
    .stat-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:12px 0}
    .stat-card{background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:11px;box-shadow:var(--shadow-sm);display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;min-height:75px}
    .stat-label{font-size:.68em;font-weight:600;text-transform:uppercase;letter-spacing:.4px;color:var(--text-muted);margin-bottom:2px}
    .stat-value{font-size:1.35em;font-weight:600;font-family:var(--font-mono);color:var(--text);line-height:1.2}
    .stat-value.compact{font-size:.9em}.stat-value.warn{color:var(--warning)}.stat-value.danger{color:var(--danger)}.stat-value.ok{color:var(--success)}
    @media(max-width:768px){.stat-grid{grid-template-columns:1fr 1fr;gap:7px;margin:10px 0}.stat-card{padding:8px;min-height:60px}.stat-value{font-size:1.15em}.stat-value.compact{font-size:.82em}}

    /* SECTIONS 
 IT/EN: SEZIONI
*/
    .section{margin-top:20px}
    .section-title{font-size:.92em;font-weight:600;color:var(--text);margin-bottom:10px;display:flex;align-items:center;gap:6px}
    .section-title svg{width:16px;height:16px;color:var(--accent)}

    /* SEARCH 
 IT/EN: RICERCA
*/
    .search-wrap{position:relative;margin-bottom:10px}
    .search-wrap svg{position:absolute;left:10px;top:50%;transform:translateY(-50%);width:14px;height:14px;color:var(--text-muted)}
    #searchInput{width:100%;padding:8px 10px 8px 32px;border:1px solid var(--border);border-radius:var(--radius);background:var(--bg-card);color:var(--text);font-family:var(--font);font-size:.88em;outline:none}
    #searchInput:focus{border-color:var(--accent);box-shadow:0 0 0 3px var(--accent-glow)}

    /* TABLE 
 IT/EN: TABELLA
*/
    .interface-block{margin-top:12px}
    .interface-header{font-size:.8em;font-weight:600;color:var(--accent);background:var(--accent-light);padding:6px 10px;border-radius:var(--radius) var(--radius) 0 0;border:1px solid var(--border);border-bottom:none;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
    .iface-tag{background:var(--accent);color:#fff;padding:2px 6px;border-radius:4px;font-family:var(--font-mono);font-size:.85em}
    table{width:100%;border-collapse:collapse;background:var(--bg-card);border:1px solid var(--border);border-radius:0 0 var(--radius) var(--radius);overflow:hidden;table-layout:fixed}
    th{padding:6px 7px;text-align:left;font-size:.7em;font-weight:600;text-transform:uppercase;color:var(--text-muted);background:var(--bg);border-bottom:1px solid var(--border)}
    td{padding:6px 7px;font-size:.8em;border-bottom:1px solid var(--border);font-family:var(--font-mono);overflow:hidden;text-overflow:ellipsis;word-break:break-all}
    tr:last-child td{border-bottom:none}
    tr:hover td{background:var(--bg-card-hover)}
    .rssi-bar{display:inline-flex;align-items:flex-end;gap:2px;height:13px;vertical-align:middle;margin-right:3px}
    .rssi-bar span{width:3px;background:var(--border);border-radius:1px}
    .rssi-bar span:nth-child(1){height:4px}.rssi-bar span:nth-child(2){height:7px}.rssi-bar span:nth-child(3){height:10px}.rssi-bar span:nth-child(4){height:13px}
    .rssi-bar.excellent span{background:var(--success)}.rssi-bar.good span:nth-child(-n+3){background:var(--success)}.rssi-bar.fair span:nth-child(-n+2){background:var(--warning)}.rssi-bar.weak span:nth-child(1){background:var(--danger)}
    @media(max-width:768px){td,th{padding:4px 3px;font-size:.6em}}

    /* TOAST 
 IT/EN: NOTIFICA TEMPORANEA
*/
    .copy-toast{position:fixed;bottom:18px;left:50%;transform:translateX(-50%) translateY(14px);background:var(--text);color:var(--bg-card);padding:6px 14px;border-radius:7px;font-size:.8em;font-weight:500;opacity:0;pointer-events:none;transition:all .3s ease;z-index:9999}
    .copy-toast.show{opacity:1;transform:translateX(-50%) translateY(0)}

    /* PI-HOLE 
 IT/EN: PI-HOLE
*/
    .pihole-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:9px;margin-bottom:12px}
    .pihole-stat{background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:10px;text-align:center}
    .ph-value{font-size:1.2em;font-weight:600;font-family:var(--font-mono);color:var(--accent)}
    .ph-label{font-size:.68em;text-transform:uppercase;color:var(--text-muted);margin-top:2px}
    .pihole-top-list{background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
    .pihole-top-item{display:flex;justify-content:space-between;align-items:center;padding:6px 10px;border-bottom:1px solid var(--border);font-size:.78em}
    .pihole-top-item:last-child{border-bottom:none}
    .pihole-top-item .domain{font-family:var(--font-mono);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:70%}
    .pihole-top-item .count{font-family:var(--font-mono);color:var(--text-muted)}
    .pihole-offline{text-align:center;padding:14px;color:var(--text-muted);font-size:.85em}


    /* Associazione WPS 
 IT/EN: WPS pairing
*/
    .wps-body{padding:10px}
    .wps-status{font-size:.82em;color:var(--text-muted);margin:0 0 10px;min-height:2.5em}
    .wps-actions{display:flex;gap:8px;flex-wrap:wrap}
    .wps-actions button:disabled{opacity:.5;cursor:default}

    /* HOSTAPD 
 IT/EN: HOSTAPD
*/
    .hostapd-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
    .hostapd-card{background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
    .hostapd-card-header{display:flex;align-items:center;justify-content:space-between;padding:9px 10px;background:var(--accent-light);border-bottom:1px solid var(--border)}
    .ssid-label{font-size:.8em;color:var(--text-muted)}
    .hostapd-info-grid{display:grid;grid-template-columns:auto 1fr;gap:4px 10px;padding:10px;font-size:.83em}
    .hostapd-info-grid .label{color:var(--text-muted);font-weight:500}.hostapd-info-grid .val{font-family:var(--font-mono)}
    .btn-sm{padding:5px 9px;border-radius:5px;border:1px solid var(--border);background:var(--bg-card);color:var(--text);cursor:pointer;font-size:.78em;font-weight:500;transition:all var(--transition)}
    .btn-sm:hover{background:var(--accent-light);border-color:var(--accent);color:var(--accent)}
    .btn-sm.danger{border-color:var(--danger);color:var(--danger)}.btn-sm.danger:hover{background:var(--danger);color:#fff}
    .deny-section{padding:8px 10px 10px;border-top:1px solid var(--border)}
    .deny-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:5px}
    .deny-header h5{font-size:.72em;text-transform:uppercase;color:var(--text-muted);margin:0}
    .deny-toggle{display:flex;align-items:center;gap:4px;font-size:.72em;color:var(--text-muted);cursor:pointer}
    .deny-item{display:flex;align-items:center;justify-content:space-between;padding:3px 6px;font-family:var(--font-mono);font-size:.78em;background:var(--bg);border-radius:3px;margin-bottom:2px}
    .deny-remove{background:none;border:none;color:var(--danger);cursor:pointer;font-size:1em;padding:1px 4px}
    .deny-empty{font-size:.78em;color:var(--text-muted);font-style:italic}
    .deny-add-row{display:flex;gap:4px;margin-top:5px}
    .deny-add-input{flex:1;padding:4px 7px;border:1px solid var(--border);border-radius:5px;background:var(--bg);color:var(--text);font-family:var(--font-mono);font-size:.78em;outline:none}
    .restart-container-bar{background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:7px 10px;margin-bottom:10px;display:flex;align-items:center;justify-content:space-between}
    .restart-container-bar span{font-size:.8em;color:var(--text-muted)}
    @media(max-width:768px){.hostapd-grid{grid-template-columns:1fr}.notif-dropdown{position:fixed!important;left:50%!important;top:58px!important;transform:translateX(-50%)!important;width:92%!important;max-width:340px!important;right:auto!important;margin-top:0!important;z-index:1000!important}.header{overflow:visible!important}}

    /* CHART 
 IT/EN: GRAFICO
*/
    .chart-container{background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:14px;min-width:0}
    .chart-frame{position:relative;height:240px}
    .chart-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:12px}
    .chart-heading{font-size:.85em;font-weight:600;margin-bottom:10px}
    .chart-tools{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-bottom:12px}
    .chart-tools label,.chart-note{font-size:.78em;color:var(--text-muted)}
    .chart-tools select{padding:5px 8px;background:var(--bg-card);color:var(--text);border:1px solid var(--border);border-radius:5px;font:inherit}
    .chart-note{margin-top:10px;line-height:1.5}
    @media(max-width:768px){.chart-grid{grid-template-columns:1fr}.chart-frame{height:210px}}

    /* LOG 
 IT/EN: LOG
*/
    .log-box{background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
    .log-header{display:flex;align-items:center;justify-content:space-between;padding:7px 10px;background:var(--bg);border-bottom:1px solid var(--border)}
    .log-header span{font-size:.72em;font-weight:500;text-transform:uppercase;color:var(--text-muted)}
    #logOutput{padding:10px;font-family:var(--font-mono);font-size:1.1em;line-height:1.5;height:380px;overflow-y:auto;color:var(--text);white-space:pre-wrap;word-break:break-all}

    /* SHELL 
 IT/EN: TERMINALE
*/
    .shell-btn{display:inline-flex;align-items:center;gap:6px;padding:8px 14px;border-radius:var(--radius);font-family:var(--font);font-size:.85em;font-weight:500;cursor:pointer;transition:all var(--transition);text-decoration:none;border:none}
    .shell-btn svg{width:14px;height:14px}
    .shell-btn.primary{background:var(--accent);color:#fff;box-shadow:var(--shadow-sm)}.shell-btn.primary:hover{filter:brightness(1.1)}
    .iframe-wrap{display:none;margin-top:10px;border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
    .iframe-wrap iframe{width:100%;height:500px;border:none;background:#000}
    @media(max-width:768px){.iframe-wrap iframe{height:60vh;min-height:280px}}
    /* Special keys: hidden on desktop, shown on mobile/tablet 
 IT/EN: Tasti speciali: nascosti su desktop, visibili su telefono e tablet
*/
    .special-keys{display:none;flex-wrap:wrap;gap:5px;padding:8px 6px;background:var(--bg-card);border-top:1px solid var(--border)}
    @media(max-width:1024px){.special-keys{display:flex}}
    .sk{padding:7px 11px;min-width:40px;border:1px solid var(--border);border-radius:5px;background:var(--bg-card);color:var(--text);font-family:var(--font-mono);font-size:.78em;font-weight:600;cursor:pointer;text-align:center;user-select:none;-webkit-user-select:none;transition:all .12s;-webkit-tap-highlight-color:transparent}
    .sk:active{background:var(--accent);color:#fff;transform:scale(.95)}
    .sk.mod{background:var(--accent-light);color:var(--accent);border-color:var(--accent)}

    .skeleton{background:linear-gradient(90deg,var(--border) 25%,var(--bg) 50%,var(--border) 75%);background-size:200% 100%;animation:shimmer 1.5s infinite;border-radius:4px}
    @keyframes shimmer{0%{background-position:200% 0}100%{background-position:-200% 0}}
  </style>
</head>
<body>

<div class="header">
  <div class="header-title">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><line x1="6" y1="6" x2="6.01" y2="6"/><line x1="6" y1="18" x2="6.01" y2="18"/></svg>
    Pi-Dock-Wifi <span class="status-dot" id="statusDot"></span>
  </div>
  <div class="header-right">
    <div class="pause-badge" id="pauseBadge"><svg width="9" height="9" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>Pausa</div>
    <div class="notif-wrap">
      <button class="notif-btn" id="notifBtn"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg><span class="notif-badge" id="notifBadge">0</span></button>
      <div class="notif-dropdown" id="notifDropdown"><div class="notif-dropdown-header"><span>Notifiche</span><button class="notif-clear" id="notifClear">Pulisci</button></div><div id="notifList"><div class="notif-empty">Nessuna notifica</div></div></div>
    </div>
    <span id="headerClock"></span>
    <button class="theme-toggle" id="themeToggle"></button>
    <button class="btn-sm" onclick="logoutDashboard()">Esci</button>
  </div>
</div>

<div class="main-content">
  <div class="fastfetch-box"><iframe class="fastfetch-iframe" id="fastfetchIframe" src="/cgi-bin/fastfetch.sh"></iframe></div>

  <div class="stat-grid">
    <div class="stat-card"><span class="stat-label">Uptime</span><span class="stat-value compact" id="uptime">--</span></div>
    <div class="stat-card"><span class="stat-label">CPU</span><span class="stat-value" id="cpu"><span class="skeleton" style="display:inline-block;width:40px;height:1em">&nbsp;</span></span></div>
    <div class="stat-card"><span class="stat-label">RAM</span><span class="stat-value" id="ram"><span class="skeleton" style="display:inline-block;width:40px;height:1em">&nbsp;</span></span></div>
    <div class="stat-card"><span class="stat-label">Temp</span><span class="stat-value" id="temp"><span class="skeleton" style="display:inline-block;width:40px;height:1em">&nbsp;</span></span></div>
  </div>

  <div class="section">
    <div class="section-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>Client Connessi</div>
    <div class="search-wrap"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg><input type="text" id="searchInput" placeholder="Cerca IP, Hostname o MAC..."></div>
    <div id="clientTables"></div>
  </div>

  <div class="section">
    <div class="section-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>Gestione Hostapd</div>
    <div id="hostapdRestart"></div>
    <div class="hostapd-grid" id="hostapdPanel"><div class="hostapd-card"><div style="padding:14px;text-align:center;color:var(--text-muted)">Caricamento...</div></div></div>
  </div>

  <div class="section">
    <div class="section-title">Associazione WPS</div>
    <p class="wps-status">Premi Avvia, poi il pulsante WPS del dispositivo entro due minuti. Puoi annullare in qualsiasi momento.</p>
    <div class="wps-actions" style="margin-bottom:10px">
      <button type="button" class="btn-sm" id="wpsStart" disabled>Avvia WPS su entrambe le bande</button>
      <button type="button" class="btn-sm danger" id="wpsCancel" disabled>Annulla WPS</button>
    </div>
    <div class="hostapd-grid" id="wpsPanel">Caricamento...</div>
  </div>

  <div class="section">
    <div class="section-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>Pi-hole DNS</div>
    <div id="piholeWidget"><div class="pihole-offline">Caricamento...</div></div>
  </div>

  <div class="section">
    <div class="section-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>Traffico WiFi</div>
        <div class="chart-tools"><label for="chartWindow">Intervallo</label><select id="chartWindow"><option value="60">1 minuto</option><option value="300" selected>5 minuti</option><option value="900">15 minuti</option></select><button class="btn-sm" id="chartPause" type="button" aria-pressed="false">Ferma grafici</button></div>
    <div class="chart-container"><div class="chart-heading">Traffico per interfaccia</div><div class="chart-frame"><canvas id="wifiChart" aria-label="Traffico WiFi in KiB al secondo" role="img"></canvas></div></div>
    <div class="chart-grid"><div class="chart-container"><div class="chart-heading">CPU e memoria</div><div class="chart-frame"><canvas id="systemChart" aria-label="Utilizzo CPU e memoria in percentuale" role="img"></canvas></div></div><div class="chart-container"><div class="chart-heading">Temperature</div><div class="chart-frame"><canvas id="tempChart" aria-label="Temperature del sistema e delle radio" role="img"></canvas></div></div></div>
    <div class="chart-note" id="chartNote">Storico raccolto mentre la pagina è aperta. RX = ricevuto dall’AP; TX = inviato dall’AP. Le temperature delle radio appaiono quando disponibili.</div>
  </div>

  <div class="section">
    <div class="section-title"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>Log di sistema</div>
    <div class="log-box"><div class="log-header"><span>Output</span></div><div id="logOutput">Caricamento...</div></div>
  </div>

  <div class="section">
    <button class="shell-btn primary" id="toggleIframeBtn"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>Shell Pi Router</button>
    <div class="iframe-wrap" id="iframeContainer">
      <iframe id="customIframe" allow="fullscreen"></iframe>
      <div class="special-keys" id="specialKeys">
        <button class="sk mod" data-seq="\x03" title="Ctrl+C">Ctrl+C</button>
        <button class="sk mod" data-seq="\x04" title="Ctrl+D">Ctrl+D</button>
        <button class="sk mod" data-seq="\x12" title="Ctrl+R">Ctrl+R</button>
        <button class="sk mod" data-seq="\x0c" title="Ctrl+L">Ctrl+L</button>
        <button class="sk" data-seq="\t" title="Tab">Tab</button>
        <button class="sk" data-seq="\x1b" title="Esc">Esc</button>
        <button class="sk" data-seq="\x1b[A" title="Su">&#9650;</button>
        <button class="sk" data-seq="\x1b[B" title="Giu">&#9660;</button>
        <button class="sk" data-seq="\x1b[D" title="Sinistra">&#9664;</button>
        <button class="sk" data-seq="\x1b[C" title="Destra">&#9654;</button>
        <button class="sk" data-seq="\x01" title="Ctrl+A">^A</button>
        <button class="sk" data-seq="\x05" title="Ctrl+E">^E</button>
        <button class="sk" data-seq="|" title="Pipe">|</button>
        <button class="sk" data-seq="/" title="Slash">/</button>
      </div>
    </div>
  </div>
</div>

<div class="copy-toast" id="copyToast">Copiato!</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
// Requests are shared per endpoint; each response body is consumed once. | IT/EN: Le richieste sono condivise per endpoint; ogni corpo di risposta viene consumato una volta sola
var dashboardRequests=new Map();
function dashboardRead(path,headers){
  if(dashboardRequests.has(path))return dashboardRequests.get(path);
  var ctrl=new AbortController(),timer=setTimeout(function(){ctrl.abort()},path.indexOf('pihole.sh')>=0?20000:8000);
  var request=(async function(){try{var response=await fetch(path,{signal:ctrl.signal,headers:headers||{}});return{response:response,text:response.status===304?'':await response.text()}}finally{clearTimeout(timer);dashboardRequests.delete(path)}})();
  dashboardRequests.set(path,request);return request;
}
function startDashboardPoll(task,interval){
  var timer=null,running=false;
  async function tick(){
    clearTimeout(timer);if(running)return;
    if(document.hidden||dashboardRedirecting){timer=setTimeout(tick,interval);return}
    running=true;try{await task()}catch(e){}finally{running=false;timer=setTimeout(tick,interval)}
  }
  document.addEventListener('visibilitychange',function(){if(!document.hidden&&!running)tick()});tick();
}
function htmlText(value){return String(value==null?'':value).replace(/[&<>"']/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}

// ===== THEME ===== | IT/EN: TEMA
var TT=document.getElementById('themeToggle'),MT=null;
function autoT(){var h=new Date().getHours();return h>=20||h<7?'dark':'light'}
function applyT(){document.documentElement.setAttribute('data-theme',MT||autoT())}
applyT();
TT.onclick=function(){var cur=document.documentElement.getAttribute('data-theme');MT=cur==='dark'?'light':'dark';document.documentElement.setAttribute('data-theme',MT)};
function uClock(){var n=new Date(),d=['Dom','Lun','Mar','Mer','Gio','Ven','Sab'];document.getElementById('headerClock').textContent=d[n.getDay()]+' '+String(n.getDate()).padStart(2,'0')+'/'+String(n.getMonth()+1).padStart(2,'0')+' '+String(n.getHours()).padStart(2,'0')+':'+String(n.getMinutes()).padStart(2,'0')+':'+String(n.getSeconds()).padStart(2,'0')}
uClock();setInterval(uClock,1000);setInterval(function(){if(!MT)applyT()},60000);

// ===== FASTFETCH AUTO-HEIGHT ===== | IT/EN: ALTEZZA AUTOMATICA FASTFETCH
window.addEventListener('message',function(e){if(e.data&&e.data.type==='fastfetch-height'&&e.data.height){document.getElementById('fastfetchIframe').style.height=Math.ceil(e.data.height)+'px'}});

// ===== NOTIFICATIONS ===== | IT/EN: NOTIFICHE
var notifs=[],MN=50,prevMacs=new Set(),fLoad=true;
function addN(t,m){notifs.unshift({type:t,message:m,time:new Date()});if(notifs.length>MN)notifs.pop();rN()}
function rN(){var b=document.getElementById('notifBadge'),l=document.getElementById('notifList');b.textContent=notifs.length;notifs.length?b.classList.add('visible'):b.classList.remove('visible');if(!notifs.length){l.innerHTML='<div class="notif-empty">Nessuna notifica</div>';return}l.innerHTML=notifs.map(function(n){return'<div class="notif-item"><div class="ni '+n.type+'"></div><div style="flex:1">'+htmlText(n.message)+'<div style="font-size:.7em;color:var(--text-muted);margin-top:1px">'+n.time.toLocaleTimeString()+'</div></div></div>'}).join('')}
document.getElementById('notifBtn').onclick=function(e){e.stopPropagation();document.getElementById('notifDropdown').classList.toggle('open')};
document.addEventListener('click',function(){document.getElementById('notifDropdown').classList.remove('open')});
document.getElementById('notifDropdown').onclick=function(e){e.stopPropagation()};
document.getElementById('notifClear').onclick=function(){notifs=[];rN()};rN();

// ===== PAUSE ===== | IT/EN: PAUSA
var rP=false,pT=null;
document.addEventListener('selectionchange',function(){var s=window.getSelection();if(s&&s.toString().trim().length>0){rP=true;document.getElementById('pauseBadge').classList.add('visible');clearTimeout(pT);pT=setTimeout(function(){rP=false;document.getElementById('pauseBadge').classList.remove('visible')},30000)}else{clearTimeout(pT);pT=setTimeout(function(){rP=false;document.getElementById('pauseBadge').classList.remove('visible')},2000)}});

// ===== COPY ===== | IT/EN: COPIA
function showToast(t){var e=document.getElementById('copyToast');e.textContent='Copiato: '+t;e.classList.add('show');setTimeout(function(){e.classList.remove('show')},1500)}
document.getElementById('clientTables').addEventListener('dblclick',function(e){var td=e.target.closest('td');if(!td)return;var copy=td.querySelector('[data-copy]'),t=copy?copy.dataset.copy:td.textContent.trim();if(t&&t!=='*'){navigator.clipboard.writeText(t).then(function(){showToast(t)});var r=document.createRange();r.selectNodeContents(td);var s=window.getSelection();s.removeAllRanges();s.addRange(r)}});

// ===== CHART ===== | IT/EN: GRAFICO
var isDk=function(){return document.documentElement.getAttribute('data-theme')==='dark'};
var chartWindow=300000,chartPaused=false,chartStamp=0,iP={},allC=[],lWD={};
function cOpts(unit,max){
  var c=isDk()?'#cbd5e1':'#475569',g=isDk()?'rgba(255,255,255,.06)':'rgba(0,0,0,.06)';
  return{responsive:true,maintainAspectRatio:false,animation:false,interaction:{mode:'index',intersect:false},plugins:{legend:{position:'bottom',labels:{color:c,usePointStyle:true,boxWidth:8,font:{size:11}}},tooltip:{callbacks:{title:function(items){return items.length?new Date(items[0].parsed.x).toLocaleTimeString('it-IT'):''},label:function(item){return item.dataset.label+': '+Number(item.parsed.y).toLocaleString('it-IT',{maximumFractionDigits:1})+' '+unit}}}},scales:{x:{type:'linear',ticks:{color:c,maxTicksLimit:6,font:{size:10},callback:function(value){return new Date(value).toLocaleTimeString('it-IT',{hour:'2-digit',minute:'2-digit',second:'2-digit'})}},grid:{display:false}},y:{beginAtZero:true,max:max,title:{display:true,text:unit,color:c,font:{size:11}},ticks:{color:c,font:{size:10}},grid:{color:g}}}};
}
function makeChart(id,unit,max){return new Chart(document.getElementById(id),{type:'line',data:{labels:[],datasets:[]},options:cOpts(unit,max)})}
var wC=makeChart('wifiChart','KiB/s'),sC=makeChart('systemChart','%',100),tC=makeChart('tempChart','°C');
var chartList=[wC,sC,tC];
function chartSeries(ch,label,color,dashed){
  var ds=ch.data.datasets.find(function(d){return d.label===label});
  if(!ds){ds={label:label,data:ch.data.datasets.length?ch.data.datasets[0].data.map(function(p){return{x:p.x,y:null}}):[],borderColor:color,backgroundColor:color,borderDash:dashed?[5,4]:[],borderWidth:2,pointRadius:0,pointHoverRadius:4,tension:0,spanGaps:false,fill:false};ch.data.datasets.push(ds)}return ds;
}
function chartNumber(value){if(value==null||value===''||value==='null')return null;var n=Number(value);return Number.isFinite(n)?n:null}
function chartAppend(ch,values,stamp){
  ch.data.datasets.forEach(function(ds){ds.data.push({x:stamp,y:Object.prototype.hasOwnProperty.call(values,ds.label)?values[ds.label]:null});while(ds.data.length>310||ds.data.length>1&&ds.data[0].x<stamp-900000)ds.data.shift()});
}
function redrawCharts(){chartList.forEach(function(ch){if(chartStamp){ch.options.scales.x.min=chartStamp-chartWindow;ch.options.scales.x.max=chartStamp}ch.update('none')})}
function uChart(ch,wifi,stamp){
  var now=performance.now(),cols=['#087fa1','#9b5ce5','#d08a15'],values={};stamp=stamp||Date.now();
  Object.keys(iP).forEach(function(iface){if(!wifi||!wifi[iface])delete iP[iface]});
  Object.keys(wifi||{}).forEach(function(iface,index){
    var rx=chartNumber(wifi[iface].rx),tx=chartNumber(wifi[iface].tx),previous=iP[iface],elapsed=previous?(now-previous.time)/1000:0;
    var rates=[null,null];
    if(rx!=null&&tx!=null&&rx>=0&&tx>=0){
      if(previous&&elapsed>0&&elapsed<=15){rates=[rx>=previous.rx?(rx-previous.rx)/1024/elapsed:null,tx>=previous.tx?(tx-previous.tx)/1024/elapsed:null]}
      iP[iface]={rx:rx,tx:tx,time:now};
    }else{delete iP[iface]}
    [' RX',' TX'].forEach(function(suffix,i){var label=iface+suffix;chartSeries(ch,label,cols[index%cols.length],i===1);values[label]=rates[i]==null?null:Number(rates[i].toFixed(2))});
  });
  chartAppend(ch,values,stamp);
}
function updateCharts(d){
  if(chartPaused){iP={};return}var stamp=Date.now();if(chartStamp&&stamp-chartStamp>15000){chartList.forEach(function(ch){chartAppend(ch,{},chartStamp+3000);chartAppend(ch,{},stamp-1)})}chartStamp=stamp;uChart(wC,d.wifi,stamp);
  chartSeries(sC,'CPU','#087fa1');chartSeries(sC,'RAM','#9b5ce5');
  chartAppend(sC,{CPU:chartNumber(d.cpu),RAM:chartNumber(d.ram)},stamp);
  var temps={Sistema:chartNumber(d.temp)};chartSeries(tC,'Sistema','#de6c45');
  Object.keys(d.wifi||{}).forEach(function(iface,index){var value=chartNumber(d.wifi[iface].temp);if(value!=null||tC.data.datasets.some(function(ds){return ds.label===iface})){chartSeries(tC,iface,['#087fa1','#9b5ce5','#d08a15'][index%3]);temps[iface]=value}});
  chartAppend(tC,temps,stamp);redrawCharts();
}
document.getElementById('chartWindow').addEventListener('change',function(e){var value=Number(e.target.value);if([60,300,900].indexOf(value)>=0){chartWindow=value*1000;redrawCharts()}});
document.getElementById('chartPause').addEventListener('click',function(){chartPaused=!chartPaused;iP={};this.textContent=chartPaused?'Riprendi grafici':'Ferma grafici';this.setAttribute('aria-pressed',String(chartPaused))});
new MutationObserver(function(){wC.options=cOpts('KiB/s');sC.options=cOpts('%',100);tC.options=cOpts('°C');redrawCharts()}).observe(document.documentElement,{attributes:true,attributeFilter:['data-theme']});

// ===== RSSI ===== | IT/EN: RSSI
function rC(r){return r>=-50?'excellent':r>=-60?'good':r>=-70?'fair':'weak'}
function rB(r){r=Number(r);if(!Number.isFinite(r)||r<=-999)return'';return'<span class="rssi-bar '+rC(r)+'"><span></span><span></span><span></span><span></span></span>'+r+' dBm'}
function bL(i){return i==='wlan0'?' (2.4GHz)':i==='wlan1'?' (5GHz)':''}

// ===== CLIENT TABLE ===== | IT/EN: TABELLA CLIENT
// A configured reservation is useful immediately, but is not a lease confirmation. | IT/EN: Una prenotazione configurata è subito utile, ma non conferma un lease
function clientIpLabel(client){
  if(!client.ip)return '<span title="Il client è associato al Wi-Fi; il router non conosce ancora un IP verificabile">IP in attesa</span>';
  var titles={lease:'Lease DHCP valido',neighbor:'Indirizzo rilevato nella tabella di rete locale',reservation:'IP prenotato: utilizzo non ancora confermato'};
  return '<span data-copy="'+htmlText(client.ip)+'" title="'+htmlText(titles[client.ip_source]||'Indirizzo locale')+'">'+htmlText(client.ip)+(client.ip_source==='reservation'?' · prenotato':'')+'</span>';
}
function rCT(clients,wd){if(wd)lWD=wd;var c=document.getElementById('clientTables'),q=document.getElementById('searchInput').value.toLowerCase();var f=clients.filter(function(x){return(x.ip||'').toLowerCase().indexOf(q)!==-1||(x.hostname||'').toLowerCase().indexOf(q)!==-1||(x.mac||'').toLowerCase().indexOf(q)!==-1});var g={};f.forEach(function(x){if(!g[x.iface])g[x.iface]=[];g[x.iface].push(x)});if(!f.length){delete c.dataset.lh;c.innerHTML='<p style="text-align:center;color:var(--text-muted);padding:14px">Nessun client</p>';return}var h='';for(var i in g){var e=g[i],info=lWD[i]?lWD[i].info:null,ssid=info&&info.ssid||'n/d',cc=info&&info.client_count!==undefined?info.client_count:'n/d',tmp=lWD[i]?lWD[i].temp:null,ts=tmp!=null&&tmp!=='null'?' · '+parseFloat(tmp).toFixed(1)+'°C':'';h+='<div class="interface-block"><div class="interface-header"><span class="iface-tag">'+i+bL(i)+'</span><span>SSID: '+htmlText(ssid)+'</span><span>Client: '+cc+ts+'</span></div><table><thead><tr><th>IP</th><th>Hostname</th><th>MAC</th><th>Segnale</th></tr></thead><tbody>';e.forEach(function(x){h+='<tr><td>'+clientIpLabel(x)+'</td><td>'+htmlText(x.hostname||'Nome non comunicato')+'</td><td>'+htmlText(x.mac)+'</td><td>'+rB(x.rssi)+'</td></tr>'});h+='</tbody></table></div>'}if(c.dataset.lh!==h){var s=window.getSelection();if(!(s&&s.toString().trim().length>0&&c.contains(s.anchorNode))){c.innerHTML=h;c.dataset.lh=h}}}
document.getElementById('searchInput').oninput=function(){rCT(allC)};

// ===== STAT ===== | IT/EN: STATISTICHE
function sV(id,v){var el=document.getElementById(id),n=parseFloat(v);if(isNaN(n)){el.textContent='--';el.className='stat-value';return}if(id==='cpu'||id==='ram'){el.textContent=n.toFixed(1)+'%';el.className='stat-value '+(n>85?'danger':n>60?'warn':'ok')}else if(id==='temp'){el.textContent=n.toFixed(1)+'°C';el.className='stat-value '+(n>75?'danger':n>60?'warn':'ok')}else{el.textContent=v;el.className='stat-value'}}

// ===== MAIN REFRESH ===== | IT/EN: AGGIORNAMENTO PRINCIPALE
var fE=0;
async function refresh(){if(rP)return;try{var result=await dashboardRead('/cgi-bin/stats.sh'),r=result.response,t=result.text,j=t.indexOf('{');if(!r.ok)throw 0;if(j===-1)throw 0;var d=JSON.parse(t.substring(j));fE=0;document.getElementById('statusDot').classList.remove('error');document.getElementById('uptime').textContent=d.uptime||'--';sV('cpu',d.cpu);sV('ram',d.ram);sV('temp',d.temp);if(parseFloat(d.cpu)>90)addN('error','CPU '+parseFloat(d.cpu).toFixed(0)+'%');if(parseFloat(d.temp)>80)addN('error','Temp '+parseFloat(d.temp).toFixed(1)+'°C');var cl=[],cm=new Set();Object.keys(d.clients||{}).forEach(function(i){(Array.isArray(d.clients[i])?d.clients[i]:Object.values(d.clients[i]||{})).forEach(function(c){var m=c.mac||'*';cm.add(m);cl.push({ip:c.ip==='non assegnato'?'':c.ip||'',hostname:c.hostname==='*'||c.hostname==='non disponibile'?'':c.hostname||'',mac:m,rssi:c.rssi,iface:i,ip_source:c.ip_source||'none',ip_confirmed:c.ip_confirmed===true})})});if(!fLoad){cm.forEach(function(m){if(!prevMacs.has(m)&&m!=='*'){var x=cl.find(function(c){return c.mac===m});addN('success','Connesso: '+(x&&x.hostname?x.hostname:m))}});prevMacs.forEach(function(m){if(!cm.has(m)&&m!=='*')addN('warn','Disconnesso: '+m)})}fLoad=false;prevMacs=cm;allC=cl;rCT(cl,d.wifi);if(!hLock)rHP(d.wifi);updateCharts(d)}catch(e){fE++;if(fE>=3){document.getElementById('statusDot').classList.add('error');if(fE===3)addN('error','Connessione persa')}}}
startDashboardPoll(refresh,2000);

// ===== HOSTAPD ===== | IT/EN: HOSTAPD
var hDL={},hDE={},hLock=false;
document.getElementById('hostapdPanel').addEventListener('focusin',function(e){if(e.target.classList.contains('deny-add-input'))hLock=true});document.getElementById('hostapdPanel').addEventListener('focusout',function(e){if(e.target.classList.contains('deny-add-input'))hLock=false});
function rHP(wd){var p=document.getElementById('hostapdPanel'),rd=document.getElementById('hostapdRestart');if(!wd)return;rd.innerHTML='<div class="restart-container-bar"><span>Riavvia servizi WiFi</span><button class="btn-sm danger" onclick="restartC()">&#x21bb; Riavvia</button></div>';var h='';for(var i in wd){var w=wd[i],hi=w.hostapd||{},info=w.info||{},de=hDE[i]||false,dl=hDL[i]||[];h+='<div class="hostapd-card"><div class="hostapd-card-header"><span class="iface-tag">'+i+bL(i)+'</span><span class="ssid-label">'+htmlText(info.ssid||'n/d')+'</span></div><div class="hostapd-info-grid"><span class="label">Ch</span><span class="val">'+htmlText(hi.channel||'-')+'</span><span class="label">BW</span><span class="val">'+htmlText(hi.width||'-')+' MHz</span><span class="label">Std</span><span class="val">'+htmlText(hi.standard||'-')+'</span><span class="label">Client</span><span class="val">'+(info.client_count!==undefined?info.client_count:'-')+'</span></div><div class="deny-section"><div class="deny-header"><h5>Deny List</h5><label class="deny-toggle"><input type="checkbox" '+(de?'checked':'')+' onchange="tgDeny(\''+i+'\','+!de+')"> On</label></div>';if(!dl.length)h+='<div class="deny-empty">Vuota</div>';else dl.forEach(function(m){h+='<div class="deny-item"><span>'+m+'</span><button class="deny-remove" onclick="rmDeny(\''+i+'\',\''+m+'\')">&times;</button></div>'});h+='<div class="deny-add-row"><input type="text" class="deny-add-input" id="am-'+i+'" placeholder="XX:XX:XX:XX:XX:XX"><button class="btn-sm" onclick="addDeny(\''+i+'\')">+</button></div></div></div>'}p.innerHTML=h}
async function lDL(){try{var result=await dashboardRead('/cgi-bin/hostapd_ctl.sh'),r=result.response,t=result.text,j=t.indexOf('{');if(!r.ok)throw 0;if(j<0)return;var d=JSON.parse(t.substring(j));if(d.interfaces)for(var i in d.interfaces){hDL[i]=d.interfaces[i].deny_list||[];hDE[i]=d.interfaces[i].deny_enabled||false}}catch(e){}}
startDashboardPoll(lDL,15000);
async function restartC(){if(!confirm('Riavviare?'))return;addN('warn','Riavvio...');try{await fetch('/cgi-bin/hostapd_ctl.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=restart_container'})}catch(e){}setTimeout(function p(){fetch('/cgi-bin/stats.sh').then(function(){addN('success','Riavviato');location.reload()}).catch(function(){setTimeout(p,3000)})},5000)}
async function addDeny(i){var inp=document.getElementById('am-'+i),m=inp.value.trim();if(!m)return;try{var r=await fetch('/cgi-bin/hostapd_ctl.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=add_deny&iface='+i+'&mac='+encodeURIComponent(m)});var t=await r.text(),d=JSON.parse(t.substring(t.indexOf('{')));addN(d.success?'success':'error',d.message||d.error);if(d.success){inp.value='';lDL()}}catch(e){addN('error',e.message)}}
async function rmDeny(i,m){if(!confirm('Rimuovere '+m+'?'))return;hLock=true;try{var r=await fetch('/cgi-bin/hostapd_ctl.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action=remove_deny&iface='+i+'&mac='+m});var t=await r.text(),d=JSON.parse(t.substring(t.indexOf('{')));addN(d.success?'success':'error',d.message||d.error);await lDL();}catch(e){addN('error',e.message)}finally{hLock=false;}}
async function tgDeny(i,en){hLock=true;hDE[i]=en;try{var r=await fetch('/cgi-bin/hostapd_ctl.sh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'action='+(en?'enable_deny':'disable_deny')+'&iface='+i});var t=await r.text(),d=JSON.parse(t.substring(t.indexOf('{')));addN(d.success?'info':'error',d.message||d.error);if(!d.success)hDE[i]=!en;await lDL();}catch(e){hDE[i]=!en;addN('error',e.message)}finally{hLock=false;}}

// ===== WPS: solo associazione a pulsante ===== | IT/EN: WPS: push-button pairing only
var wpsInterfaces = {};
var wpsBusy = false;

function wpsMessage(status) {
  if (status.state === 'active') {
    if (status.expiresAt) {
      var seconds = Math.max(0, Math.ceil((status.expiresAt - Date.now()) / 1000));
      return 'In attesa del dispositivo: ' + seconds + ' s';
    }
    return 'In attesa del dispositivo (massimo due minuti)';
  }
  if (status.reason) return status.reason;
  if (status.last_result === 'Success') return 'Ultima associazione WPS riuscita';
  if (status.last_result === 'Failed') return 'Ultimo tentativo WPS non riuscito';
  return 'Pronto. L’associazione si apre solo premendo Avvia.';
}

function renderWps() {
  var panel = document.getElementById('wpsPanel');
  var fragment = document.createDocumentFragment();
  var interfaces = Object.keys(wpsInterfaces);
  var active = interfaces.some(function (iface) {
    return wpsInterfaces[iface].state === 'active' || wpsInterfaces[iface].state === 'overlap';
  });
  document.getElementById('wpsStart').disabled = wpsBusy || active || !interfaces.length ||
    interfaces.some(function (iface) { return !wpsInterfaces[iface].ready; });
  document.getElementById('wpsCancel').disabled = wpsBusy || !active;
  interfaces.forEach(function (iface, index) {
    var status = wpsInterfaces[iface];
    var card = document.createElement('div');
    card.className = 'hostapd-card';
    var header = document.createElement('div');
    header.className = 'hostapd-card-header';
    var label = document.createElement('span');
    label.className = 'iface-tag';
    label.textContent = (index === 0 ? '2,4 GHz' : '5 GHz') + ' · ' + iface;
    var network = document.createElement('span');
    network.className = 'ssid-label';
    network.textContent = lWD[iface] && lWD[iface].info ? lWD[iface].info.ssid : '';
    header.append(label, network);
    var body = document.createElement('div');
    body.className = 'wps-body';
    var message = document.createElement('p');
    message.className = 'wps-status';
    message.dataset.wpsIface = iface;
    message.setAttribute('role', 'status');
    message.textContent = wpsMessage(status);
    body.appendChild(message);
    card.append(header, body);
    fragment.appendChild(card);
  });
  panel.replaceChildren(fragment);
}

async function loadWpsStatus() {
  if (wpsBusy) return;
  try {
    var result = await dashboardRead('/cgi-bin/wps.sh');
    if (!result.response.ok) throw new Error('Stato WPS non disponibile');
    var data = JSON.parse(result.text);
    if (!data.success || !data.interfaces) throw new Error('Risposta WPS non valida');
    wpsInterfaces = data.interfaces;
    Object.keys(wpsInterfaces).forEach(function (iface) {
      var status = wpsInterfaces[iface];
      if (status.state === 'active' && Number.isFinite(status.remaining_seconds)) {
        status.expiresAt = Date.now() + status.remaining_seconds * 1000;
      }
    });
    renderWps();
  } catch (error) {
    wpsInterfaces = {};
    document.getElementById('wpsPanel').textContent = 'Stato WPS temporaneamente non disponibile.';
    document.getElementById('wpsStart').disabled = true;
    document.getElementById('wpsCancel').disabled = true;
  }
}

async function changeWps(action) {
  if (wpsBusy) return;
  wpsBusy = true;
  renderWps();
  try {
    var body = new URLSearchParams({action: action});
    var response = await fetch('/cgi-bin/wps.sh', {
      method: 'POST',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body.toString()
    });
    var result = await response.json();
    if (!response.ok || !result.success) throw new Error(result.error || 'Operazione WPS non riuscita');
    addN('info', result.message);
  } catch (error) {
    addN('error', error.message);
  } finally {
    wpsBusy = false;
    await loadWpsStatus();
  }
}

document.getElementById('wpsStart').addEventListener('click', function () { changeWps('start'); });
document.getElementById('wpsCancel').addEventListener('click', function () { changeWps('cancel'); });
startDashboardPoll(loadWpsStatus, 5000);
setInterval(function () {
  document.querySelectorAll('[data-wps-iface]').forEach(function (node) {
    var status = wpsInterfaces[node.dataset.wpsIface];
    if (status && status.state === 'active') node.textContent = wpsMessage(status);
  });
}, 1000);

// ===== PI-HOLE ===== | IT/EN: PI-HOLE
async function rPH(){var w=document.getElementById('piholeWidget');try{var result=await dashboardRead('/cgi-bin/pihole.sh'),r=result.response,t=result.text,j=t.indexOf('{');if(!r.ok)throw 0;if(j<0)throw 0;var d=JSON.parse(t.substring(j));if(d.status==='offline'){w.innerHTML='<div class="pihole-offline">Pi-hole offline</div>';return}var h='<div class="pihole-grid"><div class="pihole-stat"><div class="ph-value">'+(d.dns_queries_today||0).toLocaleString()+'</div><div class="ph-label">Query</div></div><div class="pihole-stat"><div class="ph-value">'+(d.ads_blocked_today||0).toLocaleString()+'</div><div class="ph-label">Bloccate</div></div><div class="pihole-stat"><div class="ph-value" style="color:var(--success)">'+(d.ads_percentage_today||0).toFixed(1)+'%</div><div class="ph-label">% Block</div></div><div class="pihole-stat"><div class="ph-value">'+(d.domains_being_blocked||0).toLocaleString()+'</div><div class="ph-label">Domini</div></div></div>';if(d.top_ads){h+='<div class="pihole-top-list">';Object.keys(d.top_ads).slice(0,5).forEach(function(dom){h+='<div class="pihole-top-item"><span class="domain">'+htmlText(dom)+'</span><span class="count">'+d.top_ads[dom]+'</span></div>'});h+='</div>'}w.innerHTML=h}catch(e){w.innerHTML='<div class="pihole-offline">Errore Pi-hole</div>'}}
startDashboardPoll(rPH,30000);

// ===== LOG ===== | IT/EN: LOG
var lC='',logEtag='';async function fLog(){if(rP)return;try{var result=await dashboardRead('/cgi-bin/readlog.sh',logEtag?{'If-None-Match':logEtag}:{}),r=result.response;if(r.status===304)return;if(!r.ok)return;logEtag=r.headers.get('ETag')||'';var t=result.text;if(t!==lC){lC=t;document.getElementById('logOutput').innerHTML='<code>'+htmlText(lC)+'</code>'}}catch(e){}}
startDashboardPoll(fLog,2000);

// ===== SHELL ===== | IT/EN: TERMINALE
// Same-origin via nginx proxy /terminal/ | IT/EN: Stessa origine tramite proxy nginx /terminal/
// Page always runs on pi-dock-wifi.local thanks to auto-redirect | IT/EN: La pagina usa pi-dock-wifi.local grazie al reindirizzamento automatico
var shellOpen=false;
document.getElementById('toggleIframeBtn').onclick=function(){
  var c=document.getElementById('iframeContainer'),f=document.getElementById('customIframe');
  if(!shellOpen){
    c.style.display='block';shellOpen=true;
    if(!f.src) f.src='/terminal/';
    setTimeout(function(){c.scrollIntoView({behavior:'smooth',block:'start'})},100);
  } else {
    c.style.display='none';shellOpen=false;
  }
};

// ===== SPECIAL KEYS (mobile only, visible via CSS media query) ===== | IT/EN: TASTI SPECIALI: solo mobile, visibili tramite media query CSS
// xterm.js processes InputEvent on its hidden textarea. | IT/EN: xterm.js gestisce InputEvent sulla propria textarea nascosta
function sendKeyToTerminal(seq) {
  try {
    var iframe = document.getElementById('customIframe');
    var ta = iframe.contentDocument.querySelector('textarea');
    if (!ta) { console.warn('textarea not found'); return; }
    ta.focus();
    ta.dispatchEvent(new InputEvent('input', {data: seq, inputType: 'insertText', bubbles: true}));
    // Immediately refocus iframe to prevent Chrome Android from suspending WS | IT/EN: Rimetti subito il fuoco sull’iframe per evitare la sospensione WebSocket di Chrome Android
    setTimeout(function(){ iframe.focus(); ta.focus(); }, 50);
  } catch(e) {
    console.warn('Special key error:', e);
  }
}

document.getElementById('specialKeys').addEventListener('click', function(e) {
  var btn = e.target.closest('.sk');
  if (!btn) return;
  e.preventDefault();
  e.stopPropagation();
  var seq = btn.dataset.seq;
  if (!seq) return;
  var unesc = seq.replace(/\\x([0-9a-fA-F]{2})/g, function(_, h) {
    return String.fromCharCode(parseInt(h, 16));
  }).replace(/\\t/g, '\t').replace(/\\n/g, '\n');
  sendKeyToTerminal(unesc);
});

// Gotty has --reconnect built-in, no keep-alive needed | IT/EN: Gotty include --reconnect: non serve un keep-alive
</script>
</body>
</html>
END_SCRIPT




# ------------------------------------------------------------------------------
# WEB: login.html - Router dashboard sign-in
# Same visual theme as the router dashboard, including mobile and dark mode.
# Traduzione / Translation: Pagina login.html: accesso alla dashboard con lo stesso tema grafico, modalità scura e supporto mobile
# ------------------------------------------------------------------------------
RUN tee /var/www/status/login.html > /dev/null <<'END_DASHBOARD_LOGIN'
<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light dark">
  <title>Accedi · Pi-Dock-Wifi</title>
  <script>
    (function () {
      var hour = new Date().getHours();
      document.documentElement.setAttribute('data-theme', hour >= 20 || hour < 7 ? 'dark' : 'light');
    })();
  </script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      color-scheme: light;
      --bg:#eef1f5;--bg-card:#ffffff;--bg-card-hover:#f8fafc;--text:#1a2332;--text-muted:#5a6a7e;
      --border:#d8dee6;--accent:#0a6e8a;--accent-light:#e6f4f8;--accent-glow:rgba(10,110,138,.15);--accent-ink:#fff;
      --danger:#bd2939;--danger-bg:#fff1f2;--warning:#805500;--warning-bg:#fff7df;
      --shadow-sm:0 1px 3px rgba(0,0,0,.06);--shadow-md:0 4px 12px rgba(0,0,0,.08);
      --radius:10px;--font:'IBM Plex Sans',-apple-system,sans-serif;--font-mono:'IBM Plex Mono','Consolas',monospace;
      --transition:.25s cubic-bezier(.4,0,.2,1);
    }
    [data-theme="dark"] {
      color-scheme: dark;
      --bg:#0f1419;--bg-card:#1a2332;--bg-card-hover:#1f2b3d;--text:#e2e8f0;--text-muted:#99aabc;
      --border:#2a3a4e;--accent:#38bdf8;--accent-light:#0c2a3a;--accent-glow:rgba(56,189,248,.12);--accent-ink:#0c2130;
      --danger:#ffacb5;--danger-bg:#36212c;--warning:#f1ce7b;--warning-bg:#302b20;
      --shadow-sm:0 1px 3px rgba(0,0,0,.2);--shadow-md:0 4px 12px rgba(0,0,0,.3);
    }
    *{box-sizing:border-box}
    body{margin:0;min-height:100vh;min-height:100svh;display:flex;flex-direction:column;background:var(--bg);color:var(--text);font:16px/1.5 var(--font);transition:background var(--transition),color var(--transition)}
    button,input{font:inherit}
    button{cursor:pointer}
    svg{width:20px;height:20px;fill:none;stroke:currentColor;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round;flex-shrink:0}
    .header{background:var(--bg-card);border-bottom:1px solid var(--border);padding:12px 24px;box-shadow:var(--shadow-sm);display:flex;align-items:center;justify-content:space-between;gap:16px}
    .brand{font-size:1rem;font-weight:600;color:var(--accent);display:flex;align-items:center;gap:8px;white-space:nowrap}
    .theme-control{display:flex;align-items:center;gap:9px;color:var(--text-muted);font-size:.8rem}
    .theme-toggle{width:36px;height:20px;background:var(--border);border-radius:10px;border:0;position:relative;padding:0;flex-shrink:0}
    .theme-toggle::before{content:'';position:absolute;inset:-12px -6px}
    .theme-toggle::after{content:'';position:absolute;width:16px;height:16px;background:var(--bg-card);border-radius:50%;top:2px;left:2px;transition:transform var(--transition);box-shadow:0 1px 2px rgba(0,0,0,.2)}
    [data-theme="dark"] .theme-toggle{background:var(--accent)}
    [data-theme="dark"] .theme-toggle::after{transform:translateX(16px)}
    button:focus-visible{outline:2px solid var(--accent);outline-offset:5px}
    main{width:100%;max-width:1060px;flex:1;display:grid;grid-template-columns:1fr 420px;align-content:center;align-items:center;gap:80px;padding:64px 32px;margin:0 auto}
    .network-mark{display:grid;place-items:center;width:56px;height:56px;border:1px solid var(--border);border-radius:14px;background:var(--accent-light);color:var(--accent);margin-bottom:26px}
    .network-mark svg{width:30px;height:30px}
    .eyebrow{margin:0 0 12px;color:var(--accent);font:500 .72rem/1.5 var(--font-mono);letter-spacing:.12em;text-transform:uppercase}
    h1{font-size:clamp(2rem,3.7vw,2.8rem);line-height:1.15;letter-spacing:-.035em;font-weight:600;margin:0 0 20px}
    h1 span{display:block;color:var(--accent)}
    .intro{font-size:1rem;color:var(--text-muted);max-width:360px;margin:0;line-height:1.7}
    .features{display:flex;flex-wrap:wrap;gap:16px 24px;padding:24px 0 0;margin:26px 0 0;border-top:1px solid var(--border);list-style:none}
    .features li{display:flex;align-items:center;gap:7px;color:var(--text-muted);font-size:.8rem}
    .features svg{width:16px;height:16px;color:var(--accent)}
    .login-card{min-width:0;background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:32px;box-shadow:var(--shadow-md)}
    .card-heading{display:flex;gap:12px;align-items:center;margin-bottom:24px}
    .lock-mark{display:grid;place-items:center;width:42px;height:42px;border:1px solid var(--border);border-radius:var(--radius);color:var(--accent);background:var(--bg-card-hover);flex-shrink:0}
    h2{font-size:1.35rem;line-height:1.3;letter-spacing:-.02em;font-weight:600;margin:0 0 4px}
    .card-description{margin:0;color:var(--text-muted);font-size:.85rem}
    label{display:block;font-size:.85rem;font-weight:500;margin-bottom:8px}
    .password-wrap{position:relative}
    input{width:100%;min-width:0;height:48px;padding:11px 52px 11px 13px;background:var(--bg);color:var(--text);border:1px solid var(--border);border-radius:7px;transition:border-color var(--transition),box-shadow var(--transition)}
    input::placeholder{color:var(--text-muted);opacity:1;font-size:.88rem}
    input:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px var(--accent-glow)}
    input[aria-invalid="true"]{border-color:var(--danger)}
    .password-toggle{position:absolute;right:3px;top:3px;width:42px;height:42px;padding:0;display:grid;place-items:center;background:transparent;color:var(--text-muted);border:0;border-radius:5px}
    .password-toggle:hover{background:var(--bg-card);color:var(--accent)}
    .password-toggle:focus-visible{outline-offset:-3px}
    .password-toggle svg{width:19px;height:19px}
    .field-hint{margin:10px 0 0;font-size:.76rem;color:var(--text-muted)}
    .caps-warning{margin:10px 0 0;padding:8px 10px;border-radius:6px;background:var(--warning-bg);color:var(--warning);font-size:.8rem}
    .submit{width:100%;min-height:46px;display:flex;justify-content:center;align-items:center;gap:10px;margin-top:24px;padding:11px 16px;border:1px solid transparent;border-radius:7px;background:var(--accent);color:var(--accent-ink);font-weight:600;transition:filter var(--transition)}
    .submit:hover{filter:brightness(1.08)}
    .submit:disabled{opacity:.65;cursor:wait}
    .submit svg{width:18px;height:18px}
    .error{margin:16px 0 0;padding:10px 12px;background:var(--danger-bg);color:var(--danger);border-radius:7px;font-size:.85rem;overflow-wrap:anywhere}
    .card-footer{margin:24px 0 0;padding-top:18px;border-top:1px solid var(--border);font-size:.75rem;color:var(--text-muted);display:flex;align-items:center;gap:7px}
    .card-footer svg{width:15px;height:15px}
    .page-footer{padding:0 24px 24px;text-align:center;font:400 .7rem/1.5 var(--font-mono);color:var(--text-muted)}
    [hidden]{display:none!important}
    @media(max-width:800px){main{max-width:500px;grid-template-columns:1fr;gap:28px;padding:36px 24px}.network-mark{display:none}.eyebrow{margin-bottom:8px}h1{font-size:2rem;margin-bottom:12px}h1 span{display:inline}.intro{font-size:.92rem;max-width:none}.features{display:none}.login-card{padding:28px}.page-footer{padding-bottom:20px}}
    @media(max-width:380px){.header{padding:12px 16px}.theme-label{display:none}main{padding:28px 16px;gap:24px}.login-card{padding:24px}h1{font-size:1.8rem}}
    @media(prefers-reduced-motion:reduce){*,*::before,*::after{transition:none!important}}
  </style>
</head>
<body>
  <header class="header">
    <div class="brand">
      <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><path d="M6 6h.01M6 18h.01"/></svg>
      Pi-Dock-Wifi
    </div>
    <div class="theme-control"><span class="theme-label" aria-hidden="true">Tema scuro</span><button class="theme-toggle" id="themeToggle" type="button" role="switch" aria-checked="false" aria-label="Tema scuro"></button></div>
  </header>

  <main>
    <section aria-labelledby="welcome-title">
      <div class="network-mark"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 8.8a16 16 0 0 1 20 0M5 12.2a11 11 0 0 1 14 0M8.5 15.7a5.5 5.5 0 0 1 7 0"/><circle cx="12" cy="20" r=".75"/></svg></div>
      <p class="eyebrow">Gestione della rete</p>
      <h1 id="welcome-title">Il tuo router, <span>sotto controllo.</span></h1>
      <p class="intro">Una sola dashboard per la rete Wi-Fi, i dispositivi connessi e i servizi del router.</p>
      <ul class="features" aria-label="Funzioni della dashboard">
        <li><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="18" height="13" rx="2"/><path d="M8 21h8m-4-5v5"/></svg>Dispositivi</li>
        <li><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/></svg>Pi-hole DNS</li>
        <li><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="2" y="3" width="20" height="18" rx="2"/><path d="m6 8 4 4-4 4m7 0h5"/></svg>Terminale</li>
      </ul>
    </section>

    <section class="login-card" aria-labelledby="login-title">
      <div class="card-heading">
        <div class="lock-mark"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3m-4 5v2"/></svg></div>
        <div><h2 id="login-title">Accedi al router</h2><p class="card-description">Benvenuto in Pi-Dock-Wifi.</p></div>
      </div>
      <form id="login">
        <label for="password">Password</label>
        <div class="password-wrap">
          <input id="password" name="password" type="password" autocomplete="current-password" placeholder="Inserisci la password" required maxlength="1024" aria-describedby="password-hint" autocapitalize="none" spellcheck="false">
          <button class="password-toggle" id="passwordToggle" type="button" aria-label="Mostra password" aria-pressed="false" aria-controls="password">
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/><path id="eyeSlash" d="m3 3 18 18" hidden/></svg>
          </button>
        </div>
        <p class="field-hint" id="password-hint">Usa la password della dashboard del router.</p>
        <p class="caps-warning" id="capsWarning" role="status" hidden>Blocco maiuscole attivo.</p>
        <button class="submit" id="submit" type="submit"><span id="submitLabel">Accedi</span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14m-6-6 6 6-6 6"/></svg></button>
        <p class="error" id="error" role="alert" hidden></p>
      </form>
      <noscript><p class="error">Per accedere è necessario abilitare JavaScript.</p></noscript>
      <p class="card-footer"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10h.01"/></svg>Accesso alla dashboard e al terminale del router.</p>
    </section>
  </main>
  <footer class="page-footer">Pi-Dock-Wifi · Gestione rete</footer>

  <script>
    (function () {
      const themeToggle = document.getElementById('themeToggle');
      let manualTheme = false;
      function updateTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        themeToggle.setAttribute('aria-checked', String(theme === 'dark'));
      }
      updateTheme(document.documentElement.getAttribute('data-theme'));
      themeToggle.addEventListener('click', function () {
        manualTheme = true;
        updateTheme(document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark');
      });
      setInterval(function () {
        if (manualTheme) return;
        const hour = new Date().getHours();
        updateTheme(hour >= 20 || hour < 7 ? 'dark' : 'light');
      }, 60000);

      const form = document.getElementById('login');
      const password = document.getElementById('password');
      const passwordToggle = document.getElementById('passwordToggle');
      const error = document.getElementById('error');
      const submit = document.getElementById('submit');
      const submitLabel = document.getElementById('submitLabel');
      passwordToggle.addEventListener('click', function () {
        const visible = password.type === 'password';
        password.type = visible ? 'text' : 'password';
        passwordToggle.setAttribute('aria-label', visible ? 'Nascondi password' : 'Mostra password');
        passwordToggle.setAttribute('aria-pressed', String(visible));
        document.getElementById('eyeSlash').toggleAttribute('hidden', !visible);
      });
      function capsState(event) {
        if (event.getModifierState) document.getElementById('capsWarning').hidden = !event.getModifierState('CapsLock');
      }
      password.addEventListener('keydown', capsState);
      password.addEventListener('keyup', capsState);
      password.addEventListener('blur', function () { document.getElementById('capsWarning').hidden = true; });
      password.addEventListener('input', function () { password.removeAttribute('aria-invalid'); });
      function showError(message, invalid) {
        error.textContent = message;
        error.hidden = false;
        if (invalid) password.setAttribute('aria-invalid', 'true');
      }
      form.addEventListener('submit', async function (event) {
        event.preventDefault();
        if (submit.disabled) return;
        submit.disabled = true;
        submitLabel.textContent = 'Accesso in corso…';
        form.setAttribute('aria-busy', 'true');
        error.hidden = true;
        error.textContent = '';
        password.removeAttribute('aria-invalid');
        try {
          const response = await fetch('/auth/login', {
            method: 'POST',
            headers: {'Content-Type': 'application/json', 'X-Dashboard-Request': '1'},
            body: JSON.stringify({password: password.value})
          });
          if (!response.ok) {
            showError(response.status === 429 ? 'Troppi tentativi. Attendi un minuto.' : response.status === 401 ? 'Password non corretta. Riprova.' : 'Accesso temporaneamente non disponibile.', response.status === 401);
            return;
          }
          location.replace('/');
        } catch (exception) {
          showError('Router non raggiungibile. Controlla la connessione e riprova.', false);
        } finally {
          submit.disabled = false;
          submitLabel.textContent = 'Accedi';
          form.removeAttribute('aria-busy');
        }
      });
    })();
  </script>
</body>
</html>
END_DASHBOARD_LOGIN


# ==============================================================================
# WEB STARTUP HELPERS - Embedded alongside the dashboard
# Traduzione / Translation: HELPER DI AVVIO WEB incorporati insieme alla dashboard
# ==============================================================================
# Only runtime secrets and session state are provisioned at startup.
# Traduzione / Translation: All’avvio prepara soltanto i segreti runtime e lo stato delle sessioni
RUN mkdir -p /opt/pi-dock-wifi-web


# ------------------------------------------------------------------------------
# Web authentication bootstrap
# Keep this path compatible with the router entrypoint.
# Traduzione / Translation: Inizializzazione dell’autenticazione web; conserva il percorso atteso dall’entrypoint
# ------------------------------------------------------------------------------
RUN tee /opt/pi-dock-wifi-web/configure.sh > /dev/null <<'END_WEB_CONFIGURE'
#!/bin/bash
set -euo pipefail
umask 077
STATE=/run/pi-dock-wifi
. /bin/i18n.sh
case "${APP_LANGUAGE:-it}" in it|en) ;; *) pdw_echo 'APP_LANGUAGE must be it or en' >&2; exit 1 ;; esac
cp /opt/pi-dock-wifi-web/languages/"${APP_LANGUAGE:-it}"/*.html /var/www/status/
cp /opt/pi-dock-wifi-web/languages/"${APP_LANGUAGE:-it}"/cgi-bin/*.sh /var/www/status/cgi-bin/
chmod 644 /var/www/status/*.html
chmod 755 /var/www/status/cgi-bin/*.sh
# Authentication state is generated at startup, never during image build.
# Traduzione / Translation: Lo stato di autenticazione viene generato all’avvio, mai durante la build dell’immagine
if [[ -r /opt/pi-dock-wifi-secrets/dashboard.env ]]; then
    set -a
    . /opt/pi-dock-wifi-secrets/dashboard.env
    set +a
fi
[[ -n "${DASHBOARD_PASSWORD:-}" ]] || { pdw_echo 'DASHBOARD_PASSWORD mancante' >&2; exit 1; }
mkdir -p "$STATE/web-sessions" /var/www/status/cgi-bin /var/log/nginx
chmod 700 "$STATE" "$STATE/web-sessions"
printf '%s' "$DASHBOARD_PASSWORD" | sha256sum | cut -d' ' -f1 > "$STATE/password.sha256"
if [[ -r /opt/pi-dock-wifi-secrets/pihole.env ]]; then
    set -a
    . /opt/pi-dock-wifi-secrets/pihole.env
    set +a
fi
[[ -n "${PIHOLE_PASSWORD:-}" ]] || { pdw_echo 'PIHOLE_PASSWORD mancante' >&2; exit 1; }
printf '%s' "$PIHOLE_PASSWORD" > "$STATE/pihole-password"
chmod 600 "$STATE/password.sha256" "$STATE/pihole-password"
# Web pages, CGI scripts and nginx configuration are installed by this Dockerfile.
# Never replace them from a host directory during startup.
# Traduzione / Translation: Pagine web, CGI e nginx sono installati dal Dockerfile; non sostituirli con una directory host durante
# IT/EN: l’avvio.
for file in /var/www/status/index.html /var/www/status/login.html /etc/nginx/nginx.conf /var/www/status/cgi-bin/auth.sh; do
    [[ -r "$file" ]] || { pdw_echo "Web asset mancante: $file" >&2; exit 1; }
done
END_WEB_CONFIGURE


# ------------------------------------------------------------------------------
# Nginx log rotation
# Keep dashboard logs bounded without restarting the router.
# Traduzione / Translation: Rotazione dei log nginx: limita i log della dashboard senza riavviare il router
# ------------------------------------------------------------------------------
RUN tee /opt/pi-dock-wifi-web/nginx-log-rotation.sh > /dev/null <<'END_WEB_LOG_ROTATION'
#!/bin/bash
set -e
. /bin/logger.sh
umask 077
mkdir -p /run/pi-dock-wifi /var/log/nginx
exec 201>/run/pi-dock-wifi/nginx-log-rotation.lock
flock -n 201 || exit 0
access_limit=${NGINX_ACCESS_MAX_LINES:-15000}
error_limit=${NGINX_ERROR_MAX_LINES:-5000}
interval=${NGINX_LOG_ROTATE_SECONDS:-60}
for value in "$access_limit" "$error_limit" "$interval"; do
    [[ "$value" =~ ^[1-9][0-9]*$ ]] || exit 1
done
rotate_logs /var/log/nginx/access.log "$access_limit"
rotate_logs /var/log/nginx/error.log "$error_limit"
rotate_logs_loop /var/log/nginx/access.log "$access_limit" "$interval" &
p1=$!
rotate_logs_loop /var/log/nginx/error.log "$error_limit" "$interval" &
p2=$!
trap 'kill "$p1" "$p2" 2>/dev/null || true' EXIT
trap 'exit 0' TERM INT
wait
END_WEB_LOG_ROTATION


# File permissions for all embedded web assets.
# Traduzione / Translation: Permessi dei file per tutte le risorse web incorporate
RUN chmod 644 /etc/nginx/nginx.conf /var/www/status/index.html /var/www/status/login.html && \
    chmod 755 /var/www/status/cgi-bin/*.sh /opt/pi-dock-wifi-web/*.sh


# ==============================================================================
# ENTRYPOINT & HEALTHCHECK
# Traduzione / Translation: ENTRYPOINT E CONTROLLO DI SALUTE
# ==============================================================================
ENTRYPOINT ["/bin/bash", "/bin/entrypoint.sh"]
HEALTHCHECK --interval=30s --timeout=60s --start-period=120s --retries=3 CMD ["/bin/healthcheck.sh"]

# Future rebuild guard: preserve newer patched runtime versions.
# CVE-2026-111497: narrow security updates; application and network configuration retained.
# Traduzione / Translation: Protezione delle build future: conserva versioni runtime già corrette. CVE-2026-111497: aggiornamento
# IT/EN: di sicurezza circoscritto, con applicazione e rete invariate.
USER 0
RUN apt-get update && apt-get install -y --no-install-recommends --only-upgrade libbrotli1 && rm -rf /var/lib/apt/lists/*
USER 0
# End CVE-2026-111497 patch.
# Traduzione / Translation: Fine della patch CVE-2026-111497


# ==============================================================================
# RECUPERO ETHERNET INTEGRATO — dal monitor_ip.sh esistente
# nmcli e Python sono client: nessun demone NetworkManager/DHCP aggiuntivo.
# Le pagine HTML e login incorporate sopra restano invariate.
# Traduzione / Translation: INTEGRATED ETHERNET RECOVERY from the existing monitor_ip.sh. nmcli and Python are clients, not
# IT/EN: additional NetworkManager/DHCP daemons. Embedded dashboard and sign-in pages remain unchanged.
# ==============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 network-manager && \
    if dpkg-query -W -f='${Version}' libbrotli1 >/dev/null 2>&1; then \
        dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libbrotli1)" ge 1.1.0-2+deb13u1; \
    fi && rm -rf /var/lib/apt/lists/*

COPY config/recovery/ /opt/pi-dock-wifi/recovery/
RUN chmod 644 /opt/pi-dock-wifi/recovery/*.py

# Italian/English selection; original web assets above remain the source of truth.
# Traduzione / Translation: Selezione italiano/inglese: le risorse web originali restano la fonte di riferimento
RUN mkdir -p /opt/pi-dock-wifi-web/languages/it/cgi-bin && cp /var/www/status/*.html /opt/pi-dock-wifi-web/languages/it/ && cp /var/www/status/cgi-bin/*.sh /opt/pi-dock-wifi-web/languages/it/cgi-bin/
COPY i18n/en/ /opt/pi-dock-wifi-web/languages/en/

COPY config/i18n.sh /bin/i18n.sh
