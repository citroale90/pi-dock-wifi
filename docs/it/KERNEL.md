[← README](../../README.md) · [Installazione del router](GUIDA.md) · [Hardware](HARDWARE.md) · [English](../en/KERNEL.md)

# Compilare e installare il kernel del router

**Raspberry Pi 5 · Linux ARM64 · configurazione `6.18.60wifi+` inclusa nel progetto.**

[Requisiti](#1-requisiti-e-ambito) · [Sorgenti](#3-scaricare-i-sorgenti-esatti) · [Configurazione](#4-applicare-la-configurazione) · [Compilazione](#5-compilare) · [Backup](#6-salvare-il-boot-funzionante) · [Installazione](#7-installare-i-moduli) · [Initramfs](#8-generare-linitramfs) · [Boot](#10-selezionare-il-kernel) · [Verifiche](#11-riavviare-e-verificare) · [Ripristino](#13-ripristinare-il-boot-precedente)

## 1. Requisiti e ambito

Questa procedura descrive la compilazione **nativa sul Raspberry Pi 5**, con Debian 13 / Raspberry Pi OS Trixie **ARM64**, avvio tramite firmware Raspberry Pi e partizione di boot montata in `/boot/firmware`. Per distribuzioni con U-Boot, GRUB o un diverso schema di avvio, adattare l’installazione alla documentazione della distribuzione.

| Serve | Perché |
|---|---|
| Pi 5 e hardware della [distinta](HARDWARE.md) | La configurazione comprende PCIe, MT7915E, bridge e Netfilter |
| Sistema già avviabile con kernel della distribuzione | È il punto di partenza e di recupero |
| Connessione Ethernet e accesso locale di recupero | Il primo riavvio può richiedere interventi senza Wi-Fi |
| Alimentazione stabile e raffreddamento | La compilazione usa la CPU a lungo |
| Spazio libero per sorgenti, build e backup | Consigliati almeno 20 GiB sul filesystem di lavoro; controllare anche lo spazio del boot |
| Utente con `sudo` | Necessario solo per pacchetti, backup e installazione |

Il [`.config` completo](../../hardware/kernel/config.reference) è stato verificato rispetto al modulo `configs` installato e ai sorgenti del router. La procedura è documentata con riferimento a questi file e alle fonti ufficiali; **una nuova compilazione completa e il suo avvio non sono stati eseguiti per collaudare questa guida**. Non promette un binario identico byte per byte con toolchain diverse.

### Nomi da non confondere

| Nome | Valore della prima installazione | Significato |
|---|---|---|
| Release del kernel | `6.18.60wifi+` | Seleziona la directory dei moduli |
| Immagine di boot | `kernel_2712_wifi.img` | File selezionato da `kernel=` in `config.txt` |
| Initramfs | `initramfs_2712_wifi` | Archivio per la stessa release del kernel |
| Directory dei moduli | `/lib/modules/6.18.60wifi+` | Contiene driver e dipendenze compilati insieme al kernel |

Il nome `.img` non determina la release mostrata da `uname -r`.

## 2. Preparare ambiente e dipendenze

Eseguire i blocchi, nell’ordine, in **una sessione Bash dedicata sul Pi**. `set -euo pipefail` ferma la sessione in caso di errore: correggere la causa e reimpostare le variabili prima di riprendere. I comandi di ripristino sono una procedura separata.

```sh
bash
set -euo pipefail
test "$(uname -m)" = aarch64
test "$(dpkg --print-architecture)" = arm64

PDW_REPO="$HOME/src/pi-dock-wifi"
PDW_SRC="$HOME/src/linux-pi-dock-wifi-6.18.60"
PDW_OUT="$HOME/build/pi-dock-wifi-6.18.60"
PDW_COMMIT=a4985478de14b3a83c8e04fed68377c1bdae735d
PDW_JOBS=4
PDW_IMAGE=kernel_2712_wifi.img
PDW_INITRAMFS=initramfs_2712_wifi

sudo apt update
sudo apt install build-essential git ca-certificates bc bison flex \
  libssl-dev libelf-dev libncurses-dev pkg-config pahole python3 \
  kmod xz-utils zstd cpio gzip device-tree-compiler initramfs-tools pciutils usbutils iw
sudo apt install firmware-mediatek wireless-regdb
```

Adattare `PDW_REPO` se il progetto è già stato scaricato altrove. Il pacchetto Debian `firmware-mediatek` richiede il componente APT `non-free-firmware`; abilitarlo nelle sorgenti della propria distribuzione se il pacchetto non viene trovato. Non aggiungere repository di altre release per risolvere una dipendenza.

Il firmware delle MT7915E è separato dal driver del kernel. Controllare i tre file principali e il database regolamentare:

```sh
ls -l /lib/firmware/mediatek/mt7915{_rom_patch,_wa,_wm}.bin*
ls -l /lib/firmware/regulatory.db*
df -h "$HOME" /boot/firmware
findmnt /
findmnt /boot/firmware
```

Su sistemi con firmware compresso verificare anche il supporto di decompressione del kernel; i file non devono essere semplicemente rinominati. Il driver può elencare anche firmware per MT7916: sono varianti dello stesso modulo, non la prova che il router monti quelle radio.

## 3. Scaricare i sorgenti esatti

Si usa il commit verificato, non la punta mobile del ramo `rpi-6.18.y`. Le directory di sorgente e build devono essere nuove: non usare i sorgenti del kernel attualmente in servizio.

```sh
mkdir -p "$HOME/src" "$HOME/build"
if [ ! -e "$PDW_REPO" ]; then
  git clone https://github.com/citroale90/pi-dock-wifi.git "$PDW_REPO"
fi
test -f "$PDW_REPO/hardware/kernel/config.reference"
test ! -e "$PDW_SRC"
test ! -e "$PDW_OUT"

git init "$PDW_SRC"
git -C "$PDW_SRC" remote add origin https://github.com/raspberrypi/linux.git
git -C "$PDW_SRC" fetch --depth=1 origin "$PDW_COMMIT"
git -C "$PDW_SRC" checkout --detach FETCH_HEAD
test "$(git -C "$PDW_SRC" rev-parse HEAD)" = "$PDW_COMMIT"
mkdir -p "$PDW_OUT"
```

Se una directory esiste già, sceglierne una nuova o esaminarne il contenuto prima di riutilizzarla. Non eseguire `make mrproper` nella directory del kernel originale: può eliminarne la configurazione.

## 4. Applicare la configurazione

Verificare il file e copiarlo nella directory di build separata, selezionata da `O=`:

```sh
printf '%s  %s\n' \
  2d058adfd4e84ab9d8f102317cad9283d3ed65631f9a3924412cfd8c87de62cb \
  "$PDW_REPO/hardware/kernel/config.reference" | sha256sum --check
cp "$PDW_REPO/hardware/kernel/config.reference" "$PDW_OUT/.config"
make -C "$PDW_SRC" O="$PDW_OUT" ARCH=arm64 LOCALVERSION= olddefconfig
make -C "$PDW_SRC" O="$PDW_OUT" ARCH=arm64 LOCALVERSION= prepare
python3 "$PDW_SRC/scripts/diffconfig" \
  "$PDW_REPO/hardware/kernel/config.reference" "$PDW_OUT/.config"

grep -qx 'CONFIG_ARM64=y' "$PDW_OUT/.config"
grep -qx 'CONFIG_ARM64_16K_PAGES=y' "$PDW_OUT/.config"
grep -qx 'CONFIG_MT7915E=m' "$PDW_OUT/.config"
grep -qx 'CONFIG_BRIDGE=m' "$PDW_OUT/.config"
grep -qx 'CONFIG_NETFILTER=y' "$PDW_OUT/.config"

PDW_RELEASE="$(make -s --no-print-directory -C "$PDW_SRC" \
  O="$PDW_OUT" ARCH=arm64 LOCALVERSION= kernelrelease)"
printf 'Release da installare: %s\n' "$PDW_RELEASE"
test "$PDW_RELEASE" = 6.18.60wifi+
```

`LOCALVERSION=` è intenzionalmente vuoto in **ogni** comando `make`: il suffisso `wifi+` è già nel `.config`. Lo script Kbuild può aggiungere un altro suffisso SCM se la variabile non è impostata. `prepare` genera anche `include/config/auto.conf`, necessario a `setlocalversion` quando la directory `O=` è nuova. `olddefconfig` può aggiornare simboli legati a compilatore e dipendenze: leggere il risultato di `diffconfig` prima di continuare. Non eseguire `bcm2712_defconfig` dopo la copia: sostituirebbe la configurazione fornita.

## 5. Compilare

La compilazione si esegue come utente normale. Su Pi 5 da 8 GB il valore iniziale proposto è quattro processi; ridurlo se il sistema esaurisce la memoria.

```sh
make -C "$PDW_SRC" O="$PDW_OUT" ARCH=arm64 LOCALVERSION= \
  -j"$PDW_JOBS" Image.gz modules dtbs 2>&1 | tee "$PDW_OUT/build.log"

test -s "$PDW_OUT/arch/arm64/boot/Image.gz"
gzip -t "$PDW_OUT/arch/arm64/boot/Image.gz"
test -s "$PDW_OUT/modules.order"
test -s "$PDW_OUT/Module.symvers"
test "$(cat "$PDW_OUT/include/config/kernel.release")" = "$PDW_RELEASE"
test -s "$PDW_OUT/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"
test -s "$PDW_OUT/arch/arm64/boot/dts/overlays/pcie-32bit-dma-pi5.dtbo"
```

`Image.gz` contiene il kernel; `modules` produce anche il driver MT7915E; `dtbs` produce descrizioni hardware e overlay. Questa configurazione usa `CONFIG_MODVERSIONS=y`: conservare `Module.symvers` e l’intera build per eventuali moduli esterni.

## 6. Salvare il boot funzionante

Prima di qualsiasi copia sul boot, accertarsi che sia montata la vera partizione. Il backup rimane **fuori** dalla partizione di boot e va conservato anche su un supporto accessibile per il recupero.

```sh
mountpoint -q /boot/firmware
test -s /boot/firmware/config.txt
test -s /boot/firmware/kernel_2712.img
df -h /boot/firmware /var/backups

PDW_BACKUP="/var/backups/pi-dock-wifi-kernel/$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 0700 "$PDW_BACKUP"
sudo tar -czf "$PDW_BACKUP/firmware-before.tar.gz" -C /boot/firmware .
sudo gzip -t "$PDW_BACKUP/firmware-before.tar.gz"
sudo cp /boot/firmware/config.txt "$PDW_BACKUP/config.txt.before"
printf '%s\n' "$(uname -r)" | sudo tee "$PDW_BACKUP/kernel-before.txt" >/dev/null
printf '%s\n' "$PDW_RELEASE" | sudo tee "$PDW_BACKUP/kernel-new.txt" >/dev/null
printf 'Backup: %s\n' "$PDW_BACKUP"
```

Il controllo di `kernel_2712.img` assume il kernel di distribuzione del Pi 5. Se il proprio sistema usa un’altra immagine, identificare e salvare quella effettiva prima di adattare la procedura. Annotare il percorso del backup. I DTB e gli overlay sono condivisi con il boot di distribuzione: il backup completo servirà anche a ripristinarli.

## 7. Installare i moduli

**Prima installazione di questa release:** i tre percorsi seguenti devono essere liberi. Se esistono, fermarsi e leggere [Aggiornamenti successivi](#14-aggiornamenti-successivi). `modules_install` può sostituire il contenuto di una directory di release già presente.

```sh
test "$PDW_RELEASE" != "$(uname -r)"
test ! -e "/lib/modules/$PDW_RELEASE"
test ! -e "/boot/firmware/$PDW_IMAGE"
test ! -e "/boot/firmware/$PDW_INITRAMFS"

sudo make -C "$PDW_SRC" O="$PDW_OUT" ARCH=arm64 LOCALVERSION= modules_install
sudo depmod -a "$PDW_RELEASE"
sudo install -m 0644 "$PDW_OUT/.config" "/boot/config-$PDW_RELEASE"
sudo install -m 0644 "$PDW_OUT/System.map" "/boot/System.map-$PDW_RELEASE"

sudo modinfo -k "$PDW_RELEASE" -F filename mt7915e
sudo modinfo -k "$PDW_RELEASE" -F vermagic mt7915e
```

Il primo campo di `vermagic` deve essere la release appena calcolata. Usare `sudo` consente anche di trovare gli strumenti Debian in `/usr/sbin` quando quella directory manca dal PATH dell’utente. Il kernel in esecuzione e i suoi moduli rimangono quelli precedenti fino al riavvio.

## 8. Generare l’initramfs

Crearlo **dopo** `modules_install`, specificando la nuova release: ometterla selezionerebbe il kernel attualmente in esecuzione. `-m most` include un insieme ampio di driver di storage, utile per il boot da USB; `-c gzip` sceglie una compressione supportata dal riferimento.

```sh
sudo mkinitramfs -c gzip -m most \
  -o "$PDW_OUT/$PDW_INITRAMFS" "$PDW_RELEASE"
sudo test -s "$PDW_OUT/$PDW_INITRAMFS"
sudo lsinitramfs "$PDW_OUT/$PDW_INITRAMFS" > "$PDW_OUT/initramfs-files.txt"
grep -F "$PDW_RELEASE/" "$PDW_OUT/initramfs-files.txt"
```

Esaminare gli avvisi su firmware o moduli mancanti. Per root su LUKS, RAID, LVM, rete o filesystem differenti occorrono anche i relativi pacchetti/hook: `-m most` non configura da solo tali sistemi. Non riutilizzare l’initramfs del kernel stock.

## 9. Copiare immagine, DTB e overlay

Installare l’immagine custom senza sovrascrivere `kernel_2712.img`. I DTB e gli overlay, invece, vengono aggiornati nelle directory standard secondo la procedura Raspberry Pi: devono provenire dalla stessa build.

```sh
sudo install -m 0644 "$PDW_OUT/arch/arm64/boot/Image.gz" \
  "/boot/firmware/$PDW_IMAGE.new"
sudo install -m 0644 "$PDW_OUT/$PDW_INITRAMFS" \
  "/boot/firmware/$PDW_INITRAMFS.new"
sudo cp "$PDW_OUT/arch/arm64/boot/dts/broadcom/"*.dtb /boot/firmware/
sudo install -d /boot/firmware/overlays
sudo cp "$PDW_OUT/arch/arm64/boot/dts/overlays/"*.dtb* /boot/firmware/overlays/
sudo cp "$PDW_SRC/arch/arm64/boot/dts/overlays/README" /boot/firmware/overlays/
sudo mv "/boot/firmware/$PDW_IMAGE.new" "/boot/firmware/$PDW_IMAGE"
sudo mv "/boot/firmware/$PDW_INITRAMFS.new" "/boot/firmware/$PDW_INITRAMFS"
sync
```

Il `README` degli overlay viene preso dai sorgenti, non dalla directory `O=`. Non sostituire gli altri file firmware (`start*`, `fixup*`, EEPROM) con materiali prelevati da repository diversi.

## 10. Selezionare il kernel

```sh
sudoedit /boot/firmware/config.txt
```

Aggiornare la selezione già esistente, conservando le altre impostazioni del proprio sistema:

```ini
[pi5]
kernel=kernel_2712_wifi.img
auto_initramfs=1
[all]
```

Con questo nome del kernel il firmware cerca **`initramfs_2712_wifi`**, nella stessa directory. Controllare e adattare eventuali direttive `initramfs ...`, `os_prefix`, `device_tree` o selezioni `kernel=` successive che cambiano il percorso o la selezione effettiva. Una direttiva esplicita `initramfs` deve indicare l’archivio della nuova release; non aggiungerne una concorrente senza esaminare il file.

Per la topologia di riferimento B14 + MT7915E mantenere gli overlay `pcie-32bit-dma-pi5` e `disable-wifi` descritti nella [guida hardware](HARDWARE.md#configurazione-del-boot). Verificare che i relativi `.dtbo` esistano. PCIe Gen 3 e overclock non sono necessari per compilare il kernel: seguire i criteri hardware della guida, senza copiare integralmente `config.reference.txt`.

Conservare `/boot/firmware/cmdline.txt` del proprio sistema, su **una sola riga**. Il `.config` contiene una riga di fallback con `root=/dev/mmcblk0p2`, mentre `CONFIG_CMDLINE_FROM_BOOTLOADER=y`: non copiarla sopra il `root=PARTUUID=...` o `root=UUID=...` effettivo del disco USB.

### Controllo finale prima del riavvio

```sh
test -s "/boot/firmware/$PDW_IMAGE"
test -s "/boot/firmware/$PDW_INITRAMFS"
test -d "/lib/modules/$PDW_RELEASE"
test -s /boot/firmware/bcm2712-rpi-5-b.dtb
test -s /boot/firmware/overlays/pcie-32bit-dma-pi5.dtbo
test -s /boot/firmware/overlays/disable-wifi.dtbo
sudo gzip -t "/boot/firmware/$PDW_IMAGE"
sudo modinfo -k "$PDW_RELEASE" -F vermagic mt7915e
grep -nE 'kernel=|auto_initramfs=|^[[:space:]]*initramfs[[:space:]]|^\[' \
  /boot/firmware/config.txt
cat /boot/firmware/cmdline.txt
sync
```

Se tutti i controlli e il backup sono corretti, pianificare il breve fermo del router e proseguire.

## 11. Riavviare e verificare

```sh
sudo reboot
```

Ricollegarsi via Ethernet. Le variabili della sessione precedente non esistono più: per la configurazione originale il risultato atteso di `uname -r` è **`6.18.60wifi+`**.

```sh
uname -r
getconf PAGESIZE
sudo modinfo -F vermagic mt7915e
lspci -nnk
iw dev
iw list
sudo journalctl -b -k --no-pager | grep -Ei 'mt7915|firmware|pcie|error|fail' || true
if command -v vcgencmd >/dev/null; then vcgencmd get_throttled; fi
```

| Controllo | Risultato atteso |
|---|---|
| Release / `vermagic` | Stessa release custom per kernel e modulo |
| `getconf PAGESIZE` | `16384` |
| PCIe | Le due schede `14c3:7915`, con driver `mt7915e` |
| `iw dev` | Radio/interfacce rilevate; i nomi dipendono dalle regole host |
| `iw list` | Modalità AP e combinazioni supportate |
| Log kernel | Nessun fallimento di caricamento del firmware richiesto o errore persistente di inizializzazione radio |

Non scaricare o ricaricare a forza `mt7915e` se il router serve già client Wi-Fi. Prima verificare il log del boot e l’identità del kernel caricato.

## 12. Proseguire con Pi-Dock-Wifi

Seguire la [guida d’installazione](GUIDA.md): SSID/password, configurazione dell’uplink, chiave host SSH, `start_system.sh` e infine Compose. Lo script host configura anche i nomi persistenti delle radio. Il bridge `br0` e l’indirizzo LAN **`192.168.4.1/24`** vengono gestiti dallo stack, non dalla sola compilazione del kernel.

Dopo aver completato e avviato lo stack, dalla cartella del progetto:

```sh
docker compose ps
ip -4 addr show br0
sudo ss -lntup
```

Verificare DHCP/DNS e accesso a dashboard `:8888`, Pi-hole `:8090` e terminale. `start_system.sh` non compila o installa il kernel al posto di questa procedura.

## 13. Ripristinare il boot precedente

### Se Linux si avvia ancora

Impostare il percorso reale del backup creato al passo 6 e controllarne l’integrità. Questo ripristina anche DTB, overlay e `config.txt`, non soltanto l’immagine del kernel.

```sh
PDW_BACKUP=/var/backups/pi-dock-wifi-kernel/TIMESTAMP
sudo gzip -t "$PDW_BACKUP/firmware-before.tar.gz"
mountpoint -q /boot/firmware
sudo tar -xzf "$PDW_BACKUP/firmware-before.tar.gz" \
  --no-same-owner --no-same-permissions -C /boot/firmware
sync
sudo reboot
```

Sostituire `TIMESTAMP` prima di eseguire il blocco. Le directory di moduli precedenti sono state conservate. Lasciare i nuovi moduli sul disco fino al completamento del recupero: non impediscono l’avvio del kernel precedente.

<details>
<summary><strong>Se il Pi non si avvia: recupero da un altro Linux</strong></summary>

Spegnere il Pi e collegare il suo disco a un altro sistema Linux. Con `lsblk -f` identificare con certezza root e boot del disco del Pi, quindi sostituire `ROOT_PARTITION`, `BOOT_PARTITION` e `TIMESTAMP`. Non usare nomi di disco dedotti soltanto dall’ordine di collegamento.

```sh
lsblk -f
sudo mkdir -p /mnt/pdw-root /mnt/pdw-boot
sudo mount -o ro /dev/ROOT_PARTITION /mnt/pdw-root
sudo mount /dev/BOOT_PARTITION /mnt/pdw-boot
test -d /mnt/pdw-root/etc
test -f /mnt/pdw-boot/config.txt
sudo gzip -t /mnt/pdw-root/var/backups/pi-dock-wifi-kernel/TIMESTAMP/firmware-before.tar.gz
sudo tar -xzf /mnt/pdw-root/var/backups/pi-dock-wifi-kernel/TIMESTAMP/firmware-before.tar.gz \
  --no-same-owner --no-same-permissions -C /mnt/pdw-boot
sync
sudo umount /mnt/pdw-boot
sudo umount /mnt/pdw-root
```

Ricollegare il disco al Pi. Se il backup è su un altro supporto, usare il percorso di quel supporto invece della copia nella root del Pi.

</details>

## 14. Aggiornamenti successivi

Per una nuova build conservare i sorgenti/artefatti precedenti e scegliere una directory `O=` nuova. Se la release esiste già, impostare **un suffisso nuovo nella copia di build**, poi rieseguire `olddefconfig` e ricalcolare `PDW_RELEASE`:

```sh
"$PDW_SRC/scripts/config" --file "$PDW_OUT/.config" \
  --set-str LOCALVERSION 'wifi-pdw2'
make -C "$PDW_SRC" O="$PDW_OUT" ARCH=arm64 LOCALVERSION= olddefconfig
make -C "$PDW_SRC" O="$PDW_OUT" ARCH=arm64 LOCALVERSION= prepare
PDW_RELEASE="$(make -s --no-print-directory -C "$PDW_SRC" \
  O="$PDW_OUT" ARCH=arm64 LOCALVERSION= kernelrelease)"
PDW_IMAGE=kernel_2712_wifi_pdw2.img
PDW_INITRAMFS=initramfs_2712_wifi_pdw2
```

Per il commit di riferimento la release diventa `6.18.60wifi-pdw2`. Questi comandi sono un’alternativa al nome della prima installazione: tornare alla compilazione, ripetere backup e installazione e aggiornare `config.txt` con il nuovo nome. Non sostituire i moduli di una release caricata. Per un kernel più recente aggiornare anche il commit scelto, verificare i simboli con `diffconfig` e ripetere i controlli di hardware e firmware.

APT continua a gestire il kernel della distribuzione; non ricompila questo kernel custom. Dopo aggiornamenti a kernel/firmware di distribuzione verificare la selezione in `config.txt` e la coerenza dei DTB/overlay condivisi. Quando cambiano i moduli o gli hook necessari al boot, rigenerare l’initramfs per la release custom esplicita.

## Diagnostica rapida

| Sintomo | Controllo |
|---|---|
| `cc1` terminato / memoria esaurita | Ridurre `PDW_JOBS`, leggere `build.log` e i messaggi OOM |
| Release `wifi++` o suffisso inatteso | Verificare `LOCALVERSION=`, `.config`, file `localversion*` e commit |
| `Module not found` | Release di `uname -r`, directory `/lib/modules`, `modules_install` e `depmod` |
| `Invalid module format` / symbol version | Kernel e moduli provengono da build differenti; ricompilare/installare la coppia coerente |
| Ancora kernel stock dopo il riavvio | File custom presente, partizione corretta, sezione `[pi5]` e successive selezioni attive |
| Attesa del disco root / shell initramfs | `cmdline.txt`, UUID del disco, release contenuta nell’initramfs e driver/hook di storage |
| `Direct firmware load ... failed` | Pacchetto MediaTek, percorso/file esatto richiesto e supporto per eventuale compressione |
| PCIe vede meno schede | Alimentazione, FFC/B14, overlay e log PCIe; la build Docker non corregge il bus |
| Radio presenti ma AP assente | `iw list`, paese/canali, eventuale CAC DFS e configurazione hostapd |

## Fonti primarie

- [Raspberry Pi: compilazione e installazione del kernel](https://www.raspberrypi.com/documentation/computers/linux_kernel.html)
- [Firmware: kernel, initramfs e auto_initramfs](https://github.com/raspberrypi/documentation/blob/master/documentation/asciidoc/computers/config_txt/boot.adoc)
- [Linux Kbuild: ARCH, O= e installazione moduli](https://docs.kernel.org/kbuild/kbuild.html)
- [Linux Kconfig: adattamento della configurazione](https://docs.kernel.org/kbuild/kconfig.html)
- [Sorgenti esatti di setlocalversion](https://github.com/raspberrypi/linux/blob/a4985478de14b3a83c8e04fed68377c1bdae735d/scripts/setlocalversion)
- [Debian: mkinitramfs](https://manpages.debian.org/trixie/initramfs-tools-core/mkinitramfs.8.en.html)
- [Debian: firmware-mediatek e file forniti](https://packages.debian.org/trixie/firmware-mediatek)
