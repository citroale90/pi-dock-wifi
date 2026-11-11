[← README](../../README.en.md) · [Hardware](HARDWARE.md) · [DHCP and firewall](NETWORK.md) · [Italiano](../it/GUIDA.md)

# Installation and configuration

**Path:** prepare → configure → build → start → verify.

[Requirements](#before-you-start) · [Installation](#step-by-step-installation) · [Variables](#compose-variables) · [Files](#file-reference) · [Languages](#dashboard-and-log-language) · [Maintenance](#updates-and-shutdown)

## Before you start

| Requirement | Check |
|---|---|
| ARM64 Linux and compatible kernel | Two detected radios, AP mode and supported combinations in `iw list` |
| Docker Engine + Compose | `docker version` and `docker compose version` |
| Host-managed Ethernet uplink | Working NetworkManager profile and gateway |
| Recovery access | Local console or a recovery connection |
| Available ports | Inspect listeners with `ss -lntup` |

Read the [hardware guide](HARDWARE.md). The [kernel configuration](HARDWARE.md#included-kernel-configuration) is included; prepare the binary separately. Docker cannot supply a missing host radio driver.

> [!IMPORTANT]
> Containers share the host network; the main one is privileged and changes interfaces, bridge, firewall and resolver settings. The original topology permits uplink→LAN forwarding and delegates perimeter filtering to the upstream modem. Do not run two copies on the same host.

### Ports and responsibilities

| Port | Service | Purpose |
|---|---|---|
| `53` TCP/UDP | dnsmasq | LAN DNS |
| `67` UDP | dnsmasq | The LAN’s only DHCP server |
| `15353` TCP/UDP | Pi-hole | Filtered DNS, called by dnsmasq |
| `8090` HTTP | Pi-hole | Web UI and API |
| `8888` HTTP | nginx | Dashboard and terminal access |
| `3000`, loopback only | ttyd | Terminal backend through nginx |

## Step-by-step installation

### 1. Prepare configuration

From the project directory:

```sh
cp .env.example .env
chmod 600 .env
```

Replace **every `CHANGE_ME`**: distinct passwords, SSIDs and WPS UUID. Generate the UUID once using `uuidgen`, or:

```sh
python3 -c 'import uuid; print(uuid.uuid4())'
```

Shared WPS requires both radios to use the same UUID, SSID and passphrase. Select `APP_LANGUAGE=it` or `en`.

> [!NOTE]
> `.env` uses Compose syntax, not shell-script syntax. Single-quote literal passwords containing `$`. Resolved `docker compose config` output can expose secrets; use `--quiet` for validation.

### 2. Define LAN and uplink

The default LAN is `192.168.4.0/24`, router `192.168.4.1`, matching the original project and its startup and monitoring scripts. It must differ from the uplink network. Follow the [consistent-address checklist](NETWORK.md#customize-the-example-network) when changing it; editing a single occurrence is insufficient.

```sh
cp config/recovery/config.json.example config/recovery/config.json
nmcli -f NAME,UUID,TYPE,DEVICE connection show
```

Set Ethernet interface, NetworkManager profile UUID, expected IPv4 network and gateway in `config.json`. The worker uses the host’s existing profile: **it does not start a second DHCP client** and is not an UPS watchdog.

### 3. Prepare persistent state

```sh
mkdir -p state/uplink logs services/pihole/etc-pihole services/ttyd/home config/dhcp/leases
touch config/dhcp/leases/dnsmasq.leases
```

Deny lists start empty. Do not import someone else’s credentials, Pi-hole data or leases. All 25 original reservations remain as anonymized, disabled examples.

### 4. Verify the SSH host key

The terminal retains `StrictHostKeyChecking=yes`. On the router, compare both fingerprints:

```sh
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
ssh-keyscan -t ed25519 127.0.0.1 > /tmp/router_known_hosts
ssh-keygen -lf /tmp/router_known_hosts
```

**Only if they match**, save the file:

```sh
cp /tmp/router_known_hosts config/ttyd/router_known_hosts
```

This example matches `SSH_HOST=127.0.0.1`, port 22. For another target, collect and verify that target’s key. A scan alone does not prove identity. Never put a private key in this file.

### 5. Prepare the host if needed

Read `start_system.sh` and the [boot configuration guide](HARDWARE.md#boot-configuration) first. The script retains local packages, persistent radio names, overlays, missing clock values, IRQ/NAPI, rfkill, NetworkManager and Avahi setup.

```sh
bash start_system.sh
```

> [!WARNING]
> Run this **on the router**, from a recovery session. It may interrupt networking and reboot the Pi when boot settings change. Do not run it on your Mac or NAS. It does not provision backups, other hosts or UPS shutdown.

### 6. Build and start

```sh
docker compose config --quiet
docker compose build
docker compose up -d
docker compose ps
```

The build covers `pi-dock-wifi` and `ttyd`. Pi-hole uses **`pihole/pihole:2026.10.1`** directly; Compose downloads the official image if missing.

| Open from the LAN | Credential |
|---|---|
| `http://192.168.4.1:8888` | `DASHBOARD_PASSWORD` |
| `http://192.168.4.1:8090/admin/` | `PIHOLE_PASSWORD` |

The terminal is proxied through `/terminal/`; ttyd is not exposed directly. The page references `pi-dock-wifi.local`: use a matching hostname or adapt it before building. Use a VPN or your own TLS reverse proxy for remote administration.

## Compose variables

| Variable | Purpose |
|---|---|
| `APP_LANGUAGE` | `it`/`en`: dashboard, sign-in, CGI and startup/runtime logs |
| `SSID1`, `SSID2` | Radio SSIDs; identical for shared WPS |
| `WPA_PASSPHRASE1`, `WPA_PASSPHRASE2` | WPA passphrases, 8–63 characters without line breaks |
| `DASHBOARD_PASSWORD` | Dashboard and integrated terminal access |
| `PIHOLE_PASSWORD` | Pi-hole API/UI, also shared with the dashboard CGI |
| `SSH_USER`, `SSH_HOST`, `SSH_PASSWORD` | SSH terminal target and credentials |
| `WPS_UUID` | One UUID shared by both radios |
| `LOCAL_DOMAIN` | Pi-hole web domain; does not create public DNS or certificates |
| `PIHOLE_EXTRA_DNS` | Additional Pi-hole directives; default `stop-dns-rebind` |
| `EXTRA_ROUTES` | Router routes: `NETWORK/CIDR,GATEWAY;...` |
| `ISOLATED_DEVICE_1_IP`, `ISOLATED_DEVICE_2_IP` | Enable the two original device-specific blocks; empty by default |
| `TRUSTED_PROXY_IP` | Proxy allowed to assert HTTPS for cookies; empty for direct access |

Interfaces (`wlan0`, `wlan1`, `eth0`, `wt0`), regulatory country/channels, ports, timezone `Europe/Rome` and example LAN remain explicit file settings. HT/VHT/HE and force-HT40 require compatible radios and regulations; see [hardware](HARDWARE.md) and [networking](NETWORK.md).

## File reference

Technical reference by area. Runtime files are ready to use; no npm stage is required.

<details>
<summary><strong>Images and startup</strong></summary>

| Path | Purpose |
|---|---|
| `docker-compose.yml` | Three services, host networking, privileges, environment, mounts and dependencies |
| `Dockerfile` | Original hostapd/force-HT40 and fastfetch builds, nginx/fcgiwrap runtime, embedded CGI/HTML; final block adds English assets |
| `start_system.sh` | Local host packages, persistent radio names, boot overlays/missing clock values, IRQ/NAPI, rfkill, NetworkManager and Avahi |
| `services/ttyd/Dockerfile` | Original separate ttyd 1.7.7 download, passh build and launchers; bilingual comments and localized SSH error text |

</details>

<details>
<summary><strong>Networking and services</strong></summary>

| Path | Purpose |
|---|---|
| `config/entrypoint.sh` | INIT/runtime phases, bridge, hostapd, DHCP, web, process supervision and cleanup; language/placeholder checks |
| `config/healthcheck.sh` | Service/socket checks, repair attempts, counters and last-resort restart |
| `config/logger.sh` | Timestamps, log writing, synchronization and rotation |
| `config/start-scripts/start_hostapd.sh` | Radio startup, waits and logs |
| `config/start-scripts/dnsmasq_start.sh` | br0 address, DHCP/DNS process, PID/log handling and recovery without bridge reset |
| `config/start-scripts/server-routes.sh` | Explicit extra routes using `ip route replace` |
| `config/start-scripts/monitor_ip.sh` | Uplink supervision and Ethernet worker, without adding another DHCP daemon |
| `config/start-scripts/check_nsswitch.sh` | Host name-resolution configuration checks |
| `config/hostapd/*.template` | Radio/interface/bridge, country/channel, HT/VHT/HE, SSID, WPA and WPS settings |
| `config/hostapd/4w.deny`, `6w.deny` | Host-persisted deny lists, initially empty |
| `config/dhcp/dnsmasq.conf` | br0 bind, pool/leases, DHCP options 3/6/121, DNS forward, local names and logging |
| `config/dhcp/dhclient.conf` | DHCP client options and example resolver; NetworkManager still owns uplink |
| `config/iptables/iptables-rules.sh` | Original dedicated mangle/filter/NAT chains, MSS clamp, rogue DHCP protection, LAN/uplink/NetBird routing, client restrictions, masquerade and UDP tuning |
| `config/recovery/recovery.py` | Link/address/route sampling, fault confirmation/backoff and targeted NetworkManager calls |
| `config/recovery/worker.py` | Single-worker lock, unambiguous UUID selection and recovery loop |
| `config/recovery/config.json.example` | Ethernet role/interface/UUID, expected network/gateway and boot grace period |
| `config/ttyd/sshconnect`, `start-ttyd` | SSH with host-key verification; ttyd loopback listener with Origin checks |

</details>

<details>
<summary><strong>Data, languages and hardware</strong></summary>

| Path | Purpose |
|---|---|
| `config/dhcp/leases` | Private live lease state, initially empty |
| `config/ttyd/router_known_hosts` | Locally verified public host keys, excluded from Git |
| `services/pihole/etc-pihole`, `services/ttyd/home` | Private runtime persistence, not distributed |
| `state/uplink`, `logs` | Recovery state/backoff and rotating runtime logs |
| `i18n/en.json`, `i18n/en` | Translation catalogue and generated English HTML/CGI |
| `hardware/boot`, `hardware/3d` | Boot reference, four STL meshes and three SCAD sources |
| `hardware/kernel/config.reference` | Complete `6.18.60wifi+` kernel `.config`, checked against the installed module; build settings separate from the boot file |
| `config/i18n.sh` | Italian/English log text and safe language selection; no external process per line |
| `config/recovery/runtime_i18n.py` | Python diagnostic translations; state codes are unchanged |
| `i18n/logs.json`, `i18n/en.json` | Translation reference catalogues; ready runtime files are bundled |

</details>

## Dashboard and log language

```dotenv
APP_LANGUAGE=en
```

```sh
docker compose up -d --force-recreate
```

Restart alone does not refresh Compose environment variables. Language covers new startup, healthcheck, DNS/DHCP, hostapd, web-bootstrap and Ethernet-recovery messages.

- `config/i18n.sh` translates Bash diagnostics without an external process per line.
- `config/recovery/runtime_i18n.py` handles Python diagnostics.
- Comments are bilingual and disabled reference options remain available.
- JSON/machine codes, native third-party output and the SSH session keep their formats; history is not rewritten.
- `start_system.sh` reads the language from `.env` as data; an exported variable takes precedence.

Translations and reference catalogues are bundled. To customize text, edit the ready runtime files: Italian HTML in the Dockerfile, English assets in `i18n/en`, Bash logs in `config/i18n.sh` and Python diagnostics in `runtime_i18n.py`. Node.js, npm and generators are unnecessary for installing or starting the release.

## Updates and shutdown

```sh
# Official Pi-hole image: the tag remains the one declared in Compose.
docker compose pull pihole

# Custom images: rebuild with the project patches.
docker compose build --pull pi-dock-wifi ttyd
docker compose up -d
```

To change the Pi-hole version, update its Compose tag first and read the release notes. Pull alone does not rebuild custom code. Original build methods include moving upstream references; bit-for-bit reproducibility is not claimed.

```sh
docker compose down
```

This stops containers without deleting persistent data. Preserve `.env`, deny lists, leases and Pi-hole data during ordinary maintenance. Lab backups and controlled power shutdown remain outside the public project.

## Troubleshooting

| Symptom | First check |
|---|---|
| Main container keeps restarting | `docker compose logs --tail=100 pi-dock-wifi`; `.env` placeholders, radios and ports |
| No Wi-Fi | `iw dev`, driver/firmware and radio settings; allow any DFS CAC delay |
| Clients have no address | dnsmasq, port 67, bridge and competing DHCP servers |
| DNS fails | dnsmasq:53 → Pi-hole:15353 → upstream resolvers |
| Terminal does not open | Verified host key, SSH credentials and ttyd logs |
| Uplink recovery is suspended | `config.json` UUID, interface, expected network/gateway |

Logs can expose names, addresses, queries and credentials: keep them private. Use the [read-only network diagnostics](NETWORK.md#read-only-verification) for firewall analysis.
