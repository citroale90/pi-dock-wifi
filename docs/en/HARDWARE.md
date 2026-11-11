[← README](../../README.en.md) · [Installation](GUIDE.md) · [DHCP and firewall](NETWORK.md) · [Italiano](../it/HARDWARE.md)

# Hardware and assembly

**Bill of materials, connections, boot settings and 3D models.**

[Components](#components) · [P01 power board](#52pi-p01--ep-0225-power-board) · [USB hub](#usb-32-gen1-hub-hat) · [Connections](#connections) · [Kernel](#host-and-kernel) · [Boot](#boot-configuration) · [3D printing](#3d-models)

## Components

| Qty | Component | Evidence and role |
|---|---|---|
| 1 | Raspberry Pi 5 Model B Rev 1.0, 8 GB | Device tree and memory inventory |
| 1 | 52Pi P01 — RPi5 PD Power Expansion Board, EP-0225 | Product identified by the owner and P01 marking visible in the photo; USB-C PD or DC input, USB-C output to the Pi 5 and an Always-ON switch |
| 1 | GeeekPi / 52Pi B14 Quad FPC PCIe HAT, EP-0233 | Owner’s product photo; ASM1184e `1b21:1184` detected on PCIe |
| 2 | Waveshare PCIe TO MiniPCIe HAT+ | Two separate adapters. “×2” means quantity, not two PCIe lanes |
| 2 | MediaTek MT7915E Wi-Fi cards | `14c3:7915`, mt7915e/mt76 driver; commercial card model not established from the device ID |
| 1 | GeeekPi / 52Pi N02 M.2 NVMe SSD USB adapter | Identified from the owner’s product photo; USB path, not a B14 PCIe port |
| 1 | Four-port USB 3.2 Gen1 HUB HAT | Driver-free; USB-C 5 V DC power input; backwards compatible with USB 3.0/2.0/1.1 |
| 1 | Approximately 512 GB NVMe USB SSD | 476.9 GiB and ASM2362 `174c:2362` detected; root filesystem was `/dev/sda2` |
| 1 | Approximately 64 GB microSD | 59.7 GiB detected; its presence does not mean the OS root is on it |
| — | Antennas, RF cables, PSU, cooling | Required, but exact models, antenna gains and connectors were not verified |

## 52Pi P01 / EP-0225 power board

The supplied component is the **52Pi RPi5 PD Power Expansion Board**, board name **P01**, product code **EP-0225**. It converts external power for the Raspberry Pi 5 and provides a POWERON button and Always-ON switch. The external PSU model and switch position in the reference installation have not been verified.

| Feature | Function and connection |
|---|---|
| **USB-C PD input** | The manufacturer specifies a default 15 V PD input; the source must offer the required profile |
| **Alternative DC input** | 9–24 V; check the module's connector and polarity before connecting power |
| **USB-C PD 3.0 output** | Advertised 5.15 V / 5 A profile for the Pi 5; the source and cable must support the load |
| **Always-ON disabled** | A short press of POWERON is required to enable power |
| **Always-ON enabled** | Power to the Pi starts automatically when external power returns |
| **POWERON held for more than 3 seconds** | Cuts power; shut Linux down first to protect the filesystem |

```text
USB-C PD source or 9–24 V DC source
  └─ 52Pi P01 / EP-0225
       └─ USB-C output → Raspberry Pi 5 power input
```

Use **only one input at a time**: 52Pi explicitly prohibits powering the DC and USB-C inputs simultaneously.

References: [manufacturer manual](https://wiki.52pi.com/index.php?title=EP-0225) · [52Pi product page](https://52pi.com/products/52pi-pd-power-extension-adapter-board-for-raspberry-pi-5) · [supplied AliExpress listing](https://it.aliexpress.com/item/1005006778140818.html).

## USB 3.2 Gen1 HUB HAT

| Feature | Router use |
|---|---|
| **4 USB 3.2 Gen1 ports** | USB peripheral expansion without a proprietary driver |
| **Up to nominal 5 Gbit/s** | Available bandwidth is shared through the hub’s USB uplink |
| **USB-C 5 V DC input** | External board power, separate from its host data connection |
| **Backwards compatible** | USB 3.0/2.0/1.1; effective speed depends on host and peripheral |
| **HAT form factor** | Check spacers, connector access and clearance around other HATs/fans |

The supplied product title lists Raspberry Pi 4B/3B+/3B and Zero/Zero W/Zero WH. In the Pi 5 router build, data still travels over USB: the 40-pin GPIO connector does not carry USB traffic. Mechanical fit and cabling depend on the board and assembled stack.

## Connections

Functional diagram: the USB branch lists the components without assigning physical ports.

The [assembled router photos](../../README.en.md#assembled-router) show the stacked structure, antenna supports and a close-up of the boards.

```text
Pi 5 PCIe FFC, one shared lane
  └─ B14 / ASM1184e switch
       ├─ FFC → Waveshare MiniPCIe adapter 1 → MT7915E → wlan0
       └─ FFC → Waveshare MiniPCIe adapter 2 → MT7915E → wlan1
Pi 5 USB 3 → N02/SSD storage and four-port HUB HAT
Pi 5 Ethernet → NetworkManager-managed uplink
Wi-Fi → br0 → dnsmasq DHCP/DNS → Pi-hole → upstream DNS
```

The B14 shares the Pi’s single exposed PCIe lane; it does not create four independent CPU lanes. The Waveshare USB cable serves the card’s USB functions, such as Bluetooth; Wi-Fi uses PCIe. Power down before changing HAT connections. Verify power budget, cooling and FFC/RF routing for the assembled device.

## Host and kernel

The observed host was Debian 13 Trixie ARM64, kernel `6.18.60wifi+`. That custom kernel binary and a verified procedure to reproduce it are **not included**. Docker cannot supply a missing host radio driver. Check `uname -r`, `lspci -nnk`, `lsusb`, `iw dev`, `iw list`, `ip -br link`, `findmnt /` and `vcgencmd get_throttled`. Radios must support AP mode and the required interface combinations. DFS channels can require a CAC delay.

## Boot configuration

Firmware path: `/boot/firmware/config.txt`.

[config.reference.txt](../../hardware/boot/config.reference.txt) is a reference snapshot, not a replacement boot file. Preserve your own settings and understand conditional sections `[all]`, `[pi5]`, `[cm4]` and `[cm5]` before editing.

| Observed setting | Meaning |
|---|---|
| `arm_64bit=1` | 64-bit boot |
| `dtparam=i2c_arm=on`, `dtparam=spi=on` | Peripheral buses; retain only if used |
| `dtoverlay=vc4-kms-v3d` | Graphics KMS driver, not the PCIe radio driver |
| `dtoverlay=disable-wifi` | Disable the built-in radio and avoid interface-name conflicts |
| `dtoverlay=pcie-32bit-dma-pi5` | Platform PCIe DMA setting; verify the overlay exists in your kernel/firmware |
| `dtparam=pciex1_gen=3` | Reference uses Gen 3. Raspberry Pi certifies the exposed link for Gen 2; Gen 3 requires individual testing |
| `usb_max_current_enable=1` | Firmware USB current limit option; does not compensate for an inadequate PSU |
| `over_voltage_delta=50000` | Reference voltage offset; existing administrator values are retained by the script |
| `arm_freq=2800`, `gpu_freq=900` | Reduced local clock profile. The script inserts missing keys but preserves existing values; these clocks are not guaranteed on other hardware |
| `[pi5]` and `kernel=kernel_2712_wifi.img` | Select the custom kernel. The image and matching `/lib/modules` directory must actually exist |
| `dtoverlay=dwc2,dr_mode=peripheral` | Local USB peripheral-mode topology; not a general requirement for an Ethernet/Wi-Fi router |

> [!WARNING]
> Read `start_system.sh` before executing it: original boot changes and the final reboot when required are retained. Keep a local recovery session available.

## 3D models

| File | Purpose |
|---|---|
| `placca base ventola pi.stl` | Base without HAT; no SCAD source was supplied |
| `placca base ventola pi con hat.stl` + `.scad` | Base with HAT mounting space |
| `placca antenne ventola pi.stl` + `.scad` | Antenna/fan plate |
| `usb cover.stl` + `.scad` | Recessed USB cover |


[hardware/3d](../../hardware/3d) contains four STL meshes and three editable OpenSCAD sources: base plate, HAT variant, antenna/fan plate and USB cover. Original descriptive filenames are retained. Binary lengths and triangle counts were checked; mechanical fit and printing were not revalidated. No SCAD source was supplied for the plain base plate. STL does not encode units: check dimensions in the slicer, FFC clearance and ventilation before printing.

## Manufacturer references

- [Raspberry Pi platform and PCIe documentation](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)
- [Pi 5 PCIe connector specification](https://pip-assets.raspberrypi.com/categories/892-raspberry-pi-5/documents/RP-008298-DS-1-pcie-connector-standard.pdf)
- [52Pi product index, B14 EP-0233](https://wiki.52pi.com/)
- [Waveshare PCIe TO MiniPCIe HAT+](https://www.waveshare.com/wiki/PCIe_TO_MiniPCIe_HAT%2B)

- [USB 3.2 Gen1 HUB HAT technical specifications](https://www.waveshare.com/product/raspberry-pi/usb-3.2-gen1-hub-hat.htm)
