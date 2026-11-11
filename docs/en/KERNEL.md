[← README](../../README.en.md) · [Router installation](GUIDE.md) · [Hardware](HARDWARE.md) · [Italiano](../it/KERNEL.md)

# Build and install the router kernel

**Raspberry Pi 5 · ARM64 Linux · bundled `6.18.60wifi+` configuration.**

[Requirements](#1-requirements-and-scope) · [Sources](#3-download-the-exact-sources) · [Configuration](#4-apply-the-configuration) · [Build](#5-build) · [Backup](#6-save-the-working-boot-files) · [Installation](#7-install-modules) · [Initramfs](#8-generate-the-initramfs) · [Boot](#10-select-the-kernel) · [Checks](#11-reboot-and-verify) · [Recovery](#13-restore-the-previous-boot)

## 1. Requirements and scope

This procedure describes a **native build on the Raspberry Pi 5**, using Debian 13 / Raspberry Pi OS Trixie **ARM64**, Raspberry Pi firmware boot and a boot partition mounted at `/boot/firmware`. Distributions using U-Boot, GRUB or a different boot layout need their own installation procedure.

| Requirement | Reason |
|---|---|
| Pi 5 and the [listed hardware](HARDWARE.md) | The configuration includes PCIe, MT7915E, bridging and Netfilter |
| System that already boots its distribution kernel | Starting point and recovery option |
| Ethernet and local recovery access | The first reboot may require intervention without Wi-Fi |
| Stable power and cooling | Compilation places sustained load on the CPU |
| Space for sources, build and backup | At least 20 GiB free in the work filesystem is recommended; also check boot space |
| User with `sudo` | Required for packages, backups and installation only |

The [complete `.config`](../../hardware/kernel/config.reference) was checked against the installed `configs` module and the router's sources. This procedure is documented from those files and official references; **a fresh full kernel build and boot have not been performed to test this guide**. It does not promise a byte-for-byte identical binary with different toolchains.

### Keep these names distinct

| Name | First-install value | Meaning |
|---|---|---|
| Kernel release | `6.18.60wifi+` | Selects the module directory |
| Boot image | `kernel_2712_wifi.img` | File selected by `kernel=` in `config.txt` |
| Initramfs | `initramfs_2712_wifi` | Archive for the same kernel release |
| Module directory | `/lib/modules/6.18.60wifi+` | Drivers and dependencies built with the kernel |

The `.img` filename does not determine the release reported by `uname -r`.

## 2. Prepare the environment and dependencies

Run the blocks in order in **a dedicated Bash session on the Pi**. `set -euo pipefail` stops that session on an error: fix the cause and restore the variables before resuming. Recovery commands form a separate procedure.

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

Adjust `PDW_REPO` if the project is already stored elsewhere. Debian's `firmware-mediatek` package needs the APT `non-free-firmware` component; enable it in your distribution's sources if the package cannot be found. Do not mix release repositories to obtain a dependency.

MT7915E firmware is separate from the kernel driver. Check its three main files and the regulatory database:

```sh
ls -l /lib/firmware/mediatek/mt7915{_rom_patch,_wa,_wm}.bin*
ls -l /lib/firmware/regulatory.db*
df -h "$HOME" /boot/firmware
findmnt /
findmnt /boot/firmware
```

If firmware is compressed, also check kernel decompression support; renaming the files is insufficient. The driver can list MT7916 firmware too: those are variants supported by the same module, not evidence that the router uses MT7916 cards.

## 3. Download the exact sources

Use the verified commit, rather than the moving tip of `rpi-6.18.y`. Source and output directories must be new; do not use the source tree of the kernel currently serving the router.

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

If a directory exists, choose a new one or inspect its contents before reuse. Do not run `make mrproper` in the original kernel tree: it can delete its configuration.

## 4. Apply the configuration

Verify the reference file and copy it into the separate output directory selected by `O=`:

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
printf 'Release to install: %s\n' "$PDW_RELEASE"
test "$PDW_RELEASE" = 6.18.60wifi+
```

`LOCALVERSION=` is deliberately empty in **every** `make` invocation: `.config` already supplies `wifi+`. Kbuild can append another SCM suffix when the variable is unset. `prepare` also generates `include/config/auto.conf`, which `setlocalversion` needs in a fresh `O=` directory. `olddefconfig` can update compiler- and dependency-related symbols; inspect `diffconfig` output before continuing. Do not run `bcm2712_defconfig` after copying the file: it would replace the supplied configuration.

## 5. Build

Build as a normal user. Four jobs are the suggested starting point on an 8 GB Pi 5; reduce the value if the system runs out of memory.

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

`Image.gz` is the kernel, `modules` includes the MT7915E driver, and `dtbs` produces hardware descriptions and overlays. This configuration uses `CONFIG_MODVERSIONS=y`: keep `Module.symvers` and the full build for any external modules.

## 6. Save the working boot files

Before copying to boot, verify that the actual partition is mounted. Keep the backup **outside** the boot partition, and also copy it to media accessible during recovery.

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

The `kernel_2712.img` check assumes the Pi 5 distribution kernel. If your system uses a different image, identify and save the actual boot image before adapting the procedure. Record the backup path. DTBs and overlays are shared with the distribution boot files; the full backup is needed to restore them too.

## 7. Install modules

**First installation of this release:** the following three paths must be unused. If they exist, stop and read [Subsequent updates](#14-subsequent-updates). `modules_install` can replace the contents of an existing release directory.

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

The first `vermagic` field must match the calculated release. Using `sudo` also locates Debian tools in `/usr/sbin` when that directory is absent from the user's PATH. The running kernel and its loaded modules remain the previous versions until reboot.

## 8. Generate the initramfs

Generate it **after** `modules_install`, passing the new release explicitly; omitting it selects the currently running kernel. `-m most` includes broad storage-driver support, useful for USB boot, and `-c gzip` selects a compression supported by this configuration.

```sh
sudo mkinitramfs -c gzip -m most \
  -o "$PDW_OUT/$PDW_INITRAMFS" "$PDW_RELEASE"
sudo test -s "$PDW_OUT/$PDW_INITRAMFS"
sudo lsinitramfs "$PDW_OUT/$PDW_INITRAMFS" > "$PDW_OUT/initramfs-files.txt"
grep -F "$PDW_RELEASE/" "$PDW_OUT/initramfs-files.txt"
```

Review missing-module or firmware warnings. Roots using LUKS, RAID, LVM, network storage or other filesystems also need their corresponding packages/hooks; `-m most` does not configure those setups by itself. Do not reuse the distribution kernel's initramfs.

## 9. Copy image, DTBs and overlays

Install the custom image without replacing `kernel_2712.img`. DTBs and overlays are updated in the standard directories following Raspberry Pi's procedure; they must come from the same build.

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

The overlay `README` comes from the source tree, not the `O=` output directory. Do not replace other firmware files (`start*`, `fixup*`, EEPROM) with files taken from unrelated repositories.

## 10. Select the kernel

```sh
sudoedit /boot/firmware/config.txt
```

Update the existing selection while preserving the system's other settings:

```ini
[pi5]
kernel=kernel_2712_wifi.img
auto_initramfs=1
[all]
```

With this kernel filename, firmware looks for **`initramfs_2712_wifi`** in the same directory. Inspect and adapt any `initramfs ...`, `os_prefix`, `device_tree` or later `kernel=` settings that change the effective path or selection. An explicit `initramfs` directive must point to the archive for the new release; do not add a competing directive without reviewing the file.

For the reference B14 + MT7915E topology, retain the `pcie-32bit-dma-pi5` and `disable-wifi` overlays described in the [hardware guide](HARDWARE.md#boot-configuration). Check their `.dtbo` files exist. PCIe Gen 3 and overclocking are not required to build the kernel: follow the hardware guide's criteria rather than replacing the entire boot file with `config.reference.txt`.

Keep your own `/boot/firmware/cmdline.txt` on **one physical line**. The `.config` contains a fallback command line with `root=/dev/mmcblk0p2`, while `CONFIG_CMDLINE_FROM_BOOTLOADER=y`; do not copy it over the USB root disk's actual `root=PARTUUID=...` or `root=UUID=...`.

### Final pre-reboot checks

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

Once all checks and the backup are complete, plan the short router outage and continue.

## 11. Reboot and verify

```sh
sudo reboot
```

Reconnect over Ethernet. Variables from the previous session are gone; the expected `uname -r` result for the original configuration is **`6.18.60wifi+`**.

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

| Check | Expected result |
|---|---|
| Release / `vermagic` | Same custom release for the kernel and module |
| `getconf PAGESIZE` | `16384` |
| PCIe | Both `14c3:7915` cards, using `mt7915e` |
| `iw dev` | Radios/interfaces detected; names depend on host naming rules |
| `iw list` | AP mode and supported interface combinations |
| Kernel log | No required-firmware load failure or persistent radio-initialization error |

Do not force-unload or reload `mt7915e` while the router serves Wi-Fi clients. First inspect the boot log and identify the loaded kernel.

## 12. Continue with Pi-Dock-Wifi

Follow the [installation guide](GUIDE.md): SSIDs/passwords, uplink settings, SSH host key, `start_system.sh`, then Compose. The host script also configures persistent radio names. The stack manages `br0` and LAN address **`192.168.4.1/24`**; compiling the kernel alone does not create them.

After configuring and starting the stack, run from the project directory:

```sh
docker compose ps
ip -4 addr show br0
sudo ss -lntup
```

Verify DHCP/DNS, dashboard `:8888`, Pi-hole `:8090` and terminal access. `start_system.sh` does not build or install the kernel in place of this procedure.

## 13. Restore the previous boot

### If Linux still boots

Set the actual backup path from step 6 and check its integrity. This also restores DTBs, overlays and `config.txt`, rather than only restoring a kernel image.

```sh
PDW_BACKUP=/var/backups/pi-dock-wifi-kernel/TIMESTAMP
sudo gzip -t "$PDW_BACKUP/firmware-before.tar.gz"
mountpoint -q /boot/firmware
sudo tar -xzf "$PDW_BACKUP/firmware-before.tar.gz" \
  --no-same-owner --no-same-permissions -C /boot/firmware
sync
sudo reboot
```

Replace `TIMESTAMP` before running the block. The earlier module directories were preserved. Keep the new modules until recovery is complete; their presence does not prevent the earlier kernel from booting.

<details>
<summary><strong>If the Pi does not boot: recovery from another Linux system</strong></summary>

Power off the Pi and attach its disk to another Linux system. Identify the Pi disk's root and boot partitions with `lsblk -f`, then replace `ROOT_PARTITION`, `BOOT_PARTITION` and `TIMESTAMP`. Do not infer disk names solely from connection order.

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

Reconnect the disk to the Pi. If the backup is stored on separate recovery media, use that path instead of the copy in the Pi's root filesystem.

</details>

## 14. Subsequent updates

For another build, retain the earlier source/artifacts and use a new `O=` directory. If the release already exists, select **a new suffix in the build copy**, rerun `olddefconfig`, then recalculate `PDW_RELEASE`:

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

At the reference commit this produces `6.18.60wifi-pdw2`. These commands are an alternative to the first-install names: return to the build step, repeat backup and installation, then update `config.txt` with the new filename. Do not replace modules belonging to a loaded release. For a newer kernel, also update the chosen commit, review symbols with `diffconfig`, and repeat hardware and firmware checks.

APT continues to manage the distribution kernel; it does not rebuild this custom kernel. After distribution kernel/firmware updates, verify the selection in `config.txt` and consistency of shared DTBs/overlays. When required boot modules or hooks change, regenerate the initramfs for the explicit custom release.

## Quick troubleshooting

| Symptom | Check |
|---|---|
| `cc1` killed / out of memory | Reduce `PDW_JOBS`; inspect `build.log` and OOM messages |
| Release `wifi++` or unexpected suffix | Check `LOCALVERSION=`, `.config`, `localversion*` files and commit |
| `Module not found` | `uname -r`, `/lib/modules`, `modules_install` and `depmod` |
| `Invalid module format` / symbol version | Kernel and modules came from different builds; rebuild/install a matching pair |
| Still running the distribution kernel | Custom image exists, correct partition, `[pi5]` and later effective selections |
| Waiting for root disk / initramfs shell | `cmdline.txt`, disk UUID, initramfs kernel release and storage drivers/hooks |
| `Direct firmware load ... failed` | MediaTek package, exact requested filename/path and compression support |
| Fewer PCIe cards detected | Power, FFC/B14, overlays and PCIe logs; Docker builds do not repair the bus |
| Radios present but AP missing | `iw list`, country/channels, possible DFS CAC and hostapd settings |

## Primary references

- [Raspberry Pi: kernel build and installation](https://www.raspberrypi.com/documentation/computers/linux_kernel.html)
- [Firmware: kernel, initramfs and auto_initramfs](https://github.com/raspberrypi/documentation/blob/master/documentation/asciidoc/computers/config_txt/boot.adoc)
- [Linux Kbuild: ARCH, O= and module installation](https://docs.kernel.org/kbuild/kbuild.html)
- [Linux Kconfig: adapting configuration](https://docs.kernel.org/kbuild/kconfig.html)
- [Exact setlocalversion source](https://github.com/raspberrypi/linux/blob/a4985478de14b3a83c8e04fed68377c1bdae735d/scripts/setlocalversion)
- [Debian: mkinitramfs](https://manpages.debian.org/trixie/initramfs-tools-core/mkinitramfs.8.en.html)
- [Debian: firmware-mediatek package and files](https://packages.debian.org/trixie/firmware-mediatek)
