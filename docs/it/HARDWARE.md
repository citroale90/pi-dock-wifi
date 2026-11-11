[← README](../../README.md) · [Installazione](GUIDA.md) · [DHCP e firewall](RETE.md) · [English](../en/HARDWARE.md)

# Hardware e montaggio

**Distinta, collegamenti, boot e modelli 3D.**

[Componenti](#componenti) · [Alimentazione P01](#alimentazione-52pi-p01--ep-0225) · [Hub USB](#hub-hat-usb-32-gen1) · [Topologia](#collegamenti) · [Kernel](#sistema-e-kernel-osservati) · [Boot](#configurazione-del-boot) · [Stampa 3D](#modelli-3d)

## Componenti

La distinta seguente distingue i dati rilevati sul sistema dalle identificazioni ricavate dalle fotografie del proprietario. Non attribuisce un modello commerciale a componenti che il sistema non identifica.

| Quantità | Componente | Identificazione e funzione |
|---|---|---|
| 1 | Raspberry Pi 5, 8 GB, Model B Rev 1.0 | Host ARM64 del router; rilevato dal device tree e dalla memoria |
| 1 | 52Pi P01 — RPi5 PD Power Expansion Board, EP-0225 | Prodotto indicato dal proprietario e sigla P01 visibile nella foto; ingresso USB-C PD o DC, uscita USB-C verso il Pi 5 e selettore Always-ON |
| 1 | GeeekPi / 52Pi B14 Quad FPC PCIe HAT, EP-0233 | Fotografia del prodotto; switch ASMedia ASM1184e `1b21:1184` rilevato sul bus |
| 2 | Waveshare PCIe TO MiniPCIe HAT+ | Due adattatori distinti; “×2” indica la quantità, non due lane PCIe |
| 2 | Schede radio MediaTek MT7915E | ID `14c3:7915`, driver `mt7915e` della famiglia mt76; modello commerciale non verificabile dal solo ID |
| 1 | GeeekPi / 52Pi N02 M.2 NVMe SSD Adapter | Adattatore USB mostrato nella fotografia; non usa una porta FPC del B14 |
| 1 | HUB HAT USB 3.2 Gen1, 4 porte USB-A | Driver-free; USB-C 5 V DC per alimentazione; compatibile USB 3.0/2.0/1.1 |
| 1 | SSD NVMe USB, circa 512 GB nominali | Rilevati 476,9 GiB e bridge ASMedia ASM2362 `174c:2362`; filesystem root su `/dev/sda2` al momento della verifica |
| 1 | microSD, circa 64 GB nominali | Rilevati 59,7 GiB; non confondere la sua presenza con il disco root |
| — | Antenne, cavetti RF, alimentatore e raffreddamento | Necessari e da dimensionare; marca, guadagno, connettore e modello non sono stati identificati con certezza |

## Alimentazione 52Pi P01 / EP-0225

Il componente indicato è la **52Pi RPi5 PD Power Expansion Board**, nome scheda **P01**, codice **EP-0225**. Converte l'alimentazione esterna per il Raspberry Pi 5 e aggiunge pulsante POWERON e selettore Always-ON. Il modello dell'alimentatore esterno e la posizione del selettore nell'installazione di riferimento restano da verificare.

| Caratteristica | Funzione e collegamento |
|---|---|
| **Ingresso USB-C PD** | Il produttore indica un ingresso PD predefinito a 15 V; serve una sorgente che offra il profilo richiesto |
| **Ingresso DC alternativo** | Da 9 a 24 V; verificare connettore e polarità sul modulo prima del collegamento |
| **Uscita USB-C PD 3.0** | Profilo dichiarato di 5,15 V / 5 A verso il Pi 5; sorgente e cavo devono sostenere il carico |
| **Always-ON disabilitato** | Occorre una pressione breve su POWERON per attivare l'alimentazione |
| **Always-ON abilitato** | Il Pi viene alimentato automaticamente quando torna l'alimentazione esterna |
| **POWERON premuto per oltre 3 secondi** | Interrompe l'alimentazione: completare prima l'arresto di Linux per proteggere il filesystem |

```text
Sorgente USB-C PD oppure sorgente DC 9–24 V
  └─ 52Pi P01 / EP-0225
       └─ uscita USB-C → ingresso di alimentazione del Raspberry Pi 5
```

Usare **un solo ingresso alla volta**: 52Pi vieta l'alimentazione contemporanea dagli ingressi DC e USB-C.

Riferimenti: [manuale del produttore](https://wiki.52pi.com/index.php?title=EP-0225) · [scheda 52Pi](https://52pi.com/products/52pi-pd-power-extension-adapter-board-for-raspberry-pi-5) · [articolo AliExpress indicato](https://it.aliexpress.com/item/1005006778140818.html).

## Hub HAT USB 3.2 Gen1

| Caratteristica | Uso nel router |
|---|---|
| **4 porte USB 3.2 Gen1** | Espansione per periferiche USB, senza un driver proprietario |
| **Fino a 5 Gbit/s nominali** | La banda disponibile è condivisa attraverso l’uplink USB del hub |
| **Ingresso USB-C 5 V DC** | Alimentazione esterna della scheda; non confonderlo con il collegamento dati all’host |
| **Retrocompatibilità** | USB 3.0, 2.0 e 1.1; la velocità effettiva dipende dall’host e dalla periferica |
| **Formato HAT** | Verificare distanziali, accesso ai connettori e spazio con gli altri HAT/ventole |

Il titolo del componente fornito elenca Raspberry Pi 4B/3B+/3B e Zero/Zero W/Zero WH. Nel montaggio del router Pi 5, il percorso dati resta USB: il connettore GPIO a 40 pin non trasferisce traffico USB. La compatibilità meccanica e il cablaggio seguono la scheda e il montaggio scelti.

## Collegamenti

Schema funzionale: il ramo USB riassume i componenti, senza imporre a quale porta fisica collegarli.

Le [foto del router assemblato](../../README.md#il-router-realizzato) mostrano la struttura a livelli, i supporti delle antenne e il dettaglio delle schede.

```text
Raspberry Pi 5
  ├─ PCIe FFC, una lane condivisa
  │    └─ B14 / ASM1184e
  │         ├─ FFC → Waveshare MiniPCIe HAT+ n. 1 → MT7915E → wlan0
  │         └─ FFC → Waveshare MiniPCIe HAT+ n. 2 → MT7915E → wlan1
  ├─ USB 3 → storage N02/SSD e hub HAT a 4 porte
  └─ Ethernet → uplink gestito da NetworkManager
       Wi-Fi → br0 → DHCP/DNS → Pi-hole → DNS upstream
```

Il Raspberry Pi 5 espone una singola lane PCIe. Il B14 suddivide la connettività mediante uno switch: le porte condividono il collegamento verso il Pi. Non fornisce quattro lane indipendenti verso la CPU. Il cavetto USB del Waveshare serve al percorso USB di una scheda combinata, per esempio il Bluetooth; la radio Wi-Fi MiniPCIe usa il percorso PCIe. Non collegare o scollegare gli HAT sotto alimentazione. Verificare alimentazione, temperature e cablaggio prima di abilitare due radio.

## Sistema e kernel osservati

Il riferimento operativo è Debian 13 Trixie ARM64, con kernel custom `6.18.60wifi+`. Il repository include la sua configurazione completa in [hardware/kernel/config.reference](../../hardware/kernel/config.reference). Serve un kernel host che riconosca entrambi gli adattatori e consenta AP/bridge; Docker non fornisce i driver del kernel.

### Configurazione del kernel inclusa

Il file è una copia integrale del `.config` di riferimento: **9.870 righe**, comprese le opzioni disabilitate. Verifica effettuata l’**11 novembre 2026**:

| Riferimento | Valore verificato |
|---|---|
| Kernel in esecuzione | `6.18.60wifi+` |
| Sorgenti | [raspberrypi/linux](https://github.com/raspberrypi/linux), ramo `rpi-6.18.y` |
| Commit dei sorgenti | [`a4985478de14`](https://github.com/raspberrypi/linux/commit/a4985478de14b3a83c8e04fed68377c1bdae735d) |
| File tracciati dei sorgenti | Nessuna modifica locale rilevata rispetto al commit |
| Compilatore registrato | GCC `14.2.0`, pacchetto Debian `14.2.0-19` |
| Provenienza della configurazione | Estratta dal modulo `configs` installato; il suo `vermagic` corrisponde al kernel in esecuzione |
| Confronto con i sorgenti | Identica byte per byte al `.config` della directory di build collegata ai moduli |

SHA-256 del file distribuito:

```text
2d058adfd4e84ab9d8f102317cad9283d3ed65631f9a3924412cfd8c87de62cb
```

Le opzioni rilevanti per questo router sono già presenti nel file completo:

| Opzioni | Valore | Ruolo |
|---|---|---|
| `CONFIG_ARM64`, `CONFIG_ARCH_BCM2835` | `y` | Architettura ARM64 e piattaforma Raspberry Pi |
| `CONFIG_ARM64_16K_PAGES` | `y` | Pagine di memoria da 16 KiB |
| `CONFIG_LOCALVERSION` | `"wifi+"` | Suffisso della release del kernel; distinto dal nome del file di boot |
| `CONFIG_MODULES` | `y` | Supporto ai moduli caricabili |
| `CONFIG_PCI`, `CONFIG_PCIE_BRCMSTB` | `y` | Bus PCIe e controller Broadcom |
| `CONFIG_CFG80211`, `CONFIG_MAC80211` | `m` | Stack wireless del kernel |
| `CONFIG_MT76_CORE`, `CONFIG_MT7915E` | `m` | Driver delle radio MediaTek MT7915E |
| `CONFIG_BRIDGE`, `CONFIG_BRIDGE_NETFILTER` | `m` | Bridge LAN e supporto Netfilter sul bridge |
| `CONFIG_NETFILTER` | `y` | Infrastruttura del firewall |
| `CONFIG_NF_TABLES`, `CONFIG_NETFILTER_XTABLES`, `CONFIG_IP_NF_IPTABLES`, `CONFIG_NFT_COMPAT` | `m` | Supporti nftables, xtables e compatibilità |
| `CONFIG_NF_NAT`, `CONFIG_NETFILTER_XT_TARGET_MASQUERADE`, `CONFIG_NETFILTER_XT_TARGET_TCPMSS` | `m` | NAT, masquerade e MSS clamp |
| `CONFIG_BRIDGE_NF_EBTABLES` | `m` | Supporto ebtables per il bridge |
| `CONFIG_IKCONFIG` / `CONFIG_IKCONFIG_PROC` | `m` / `y` | Configurazione incorporata nel modulo `configs`; `/proc/config.gz` dipende dal suo caricamento |

`y` indica una funzione incorporata nel kernel; `m` richiede il relativo modulo della **stessa release** in `/lib/modules`. Firmware e moduli delle radio vanno preparati sull’host.

Per usare il riferimento, entrare in una **copia separata dei sorgenti corrispondenti al commit indicato**, su Linux ARM64, quindi adattare il percorso del repository:

```sh
cp /percorso/pi-dock-wifi/hardware/kernel/config.reference .config
make ARCH=arm64 olddefconfig
make -s ARCH=arm64 kernelrelease
```

Controllare la release risultante e le differenze introdotte da `olddefconfig` prima di compilare. Il file contiene anche una `CONFIG_CMDLINE` di fallback con `root=/dev/mmcblk0p2`; `CONFIG_CMDLINE_FORCE` è disabilitato. Verificare la riga di boot e il disco root del proprio sistema.

Questi comandi preparano la configurazione dei sorgenti; non installano un kernel. La configurazione non sostituisce [config.txt](../../hardware/boot/config.reference.txt), che seleziona l’immagine al boot. Il binario, i moduli e il firmware non sono distribuiti; una nuova compilazione e il suo avvio non sono stati collaudati durante l’esportazione. Riferimenti: [compilazione Raspberry Pi](https://www.raspberrypi.com/documentation/computers/linux_kernel.html) e [Kconfig](https://docs.kernel.org/kbuild/kconfig.html).

Comandi di verifica:

```sh
uname -r
lspci -nnk
lsusb
iw dev
iw list
ip -br link
findmnt /
vcgencmd get_throttled
```

`iw list` deve includere la modalità AP e le combinazioni consentite. Canali e larghezze effettive dipendono da radio, firmware e paese; i canali DFS possono richiedere un periodo CAC. I nomi `wlan0` e `wlan1` sono parametri, non un vincolo hardware.

## Configurazione del boot

Percorso del firmware: `/boot/firmware/config.txt`.

[config.reference.txt](../../hardware/boot/config.reference.txt) conserva il riferimento tecnico corrente; **non sostituire integralmente il proprio file con questo esempio**. Il file contiene sezioni condizionali: `[all]`, `[pi5]`, `[cm4]` e `[cm5]` hanno significati diversi. Una riga valida sotto una sezione sbagliata può non applicarsi al Pi 5.

| Parametro osservato | Significato e criterio d’uso |
|---|---|
| `arm_64bit=1` | Avvio del sistema a 64 bit |
| `dtparam=i2c_arm=on`, `dtparam=spi=on` | Abilitazione dei bus, da conservare solo se utilizzati |
| `dtoverlay=vc4-kms-v3d` | Driver grafico KMS, non gestisce le radio PCIe |
| `dtoverlay=disable-wifi` | Disabilita il Wi-Fi integrato; aiuta a lasciare i nomi alle radio esterne |
| `dtoverlay=pcie-32bit-dma-pi5` | Impostazione DMA della piattaforma per i dispositivi PCIe; verificare che l’overlay esista nel kernel/firmware scelto |
| `dtparam=pciex1_gen=3` | Il riferimento usa Gen 3. Raspberry Pi certifica il collegamento esposto per Gen 2: Gen 3 resta una scelta da collaudare, non un requisito imposto dall’installer |
| `usb_max_current_enable=1` | Imposta il limite di corrente USB previsto dal firmware; non sostituisce un alimentatore adeguato |
| `over_voltage_delta=50000` | Incremento di tensione del profilo locale, valore di riferimento inserito solo se la chiave manca |
| `arm_freq=2800`, `gpu_freq=900` | Frequenze del profilo locale ridotto. Non sono valori garantiti per altri Pi; lo script conserva valori già presenti; inizializza il profilo indicato solo se le chiavi mancano |
| `[pi5]` + `kernel=kernel_2712_wifi.img` | Selezione del kernel custom. Il file deve esistere e avere moduli corrispondenti in `/lib/modules`; cambiare il nome senza installare il kernel non lo crea |
| `dtoverlay=dwc2,dr_mode=peripheral` | Controller USB in modalità periferica; è specifico della topologia locale e non necessario a un normale router Ethernet/AP |

> [!WARNING]
> Prima di modificare il boot, salvare `config.txt` e mantenere accesso locale. `start_system.sh` conserva il riavvio finale dell’originale quando modifica il boot: leggerlo prima di eseguirlo.

## Modelli 3D

| File | Funzione |
|---|---|
| `placca base ventola pi.stl` | Base senza HAT; sorgente SCAD non presente nei file forniti |
| `placca base ventola pi con hat.stl` + `.scad` | Base con spazio per il montaggio HAT |
| `placca antenne ventola pi.stl` + `.scad` | Supporto antenne e ventola |
| `usb cover.stl` + `.scad` | Copertura USB con rientranza |


[hardware/3d](../../hardware/3d) contiene quattro mesh STL e tre sorgenti SCAD: placca base, variante con HAT, supporto antenne/ventola e copertura USB. I nomi originali descrittivi sono conservati. Le mesh binarie sono state controllate per lunghezza e numero di triangoli; la stampa e l’adattamento meccanico non sono stati ricollaudati durante l’estrazione. Il modello base senza HAT non ha un sorgente SCAD tra i file ricevuti. Controllare le dimensioni nello slicer: STL non codifica l’unità di misura. Non forzare la chiusura sui cavi FFC o RF.

## Fonti del produttore

- [Raspberry Pi: documentazione della piattaforma e PCIe](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)
- [Specifiche del connettore PCIe Pi 5](https://pip-assets.raspberrypi.com/categories/892-raspberry-pi-5/documents/RP-008298-DS-1-pcie-connector-standard.pdf)
- [Indice 52Pi, B14 EP-0233](https://wiki.52pi.com/)
- [Waveshare PCIe TO MiniPCIe HAT+](https://www.waveshare.com/wiki/PCIe_TO_MiniPCIe_HAT%2B)

- [HUB HAT USB 3.2 Gen1: caratteristiche tecniche](https://www.waveshare.com/product/raspberry-pi/usb-3.2-gen1-hub-hat.htm)
