[← README](../../README.en.md) · [Installation](GUIDE.md) · [Hardware](HARDWARE.md) · [Italiano](../it/RETE.md)

# DHCP, DNS and firewall

**Complete files, explicit rules and network customization.**

[DHCP/DNS](#dhcp-and-dns) · [Firewall](#iptables-and-ebtables) · [Change networks](#customize-the-example-network) · [Diagnostics](#read-only-verification)

The complete original configuration files are retained, not replaced with a reduced settings interface. Rule ordering and behavior remain explicit. Personal identifiers are replaced by placeholders; the owner decides which device-specific examples to activate.

## DHCP and DNS

| Directive | Purpose |
|---|---|
| `interface=br0`, `bind-dynamic` | Bind the LAN service and follow interface availability |
| `dhcp-range` | Dynamic pool and lease duration |
| `dhcp-option=3,...` | Client default gateway |
| `dhcp-option=6,...` | Client DNS on standard port 53 |
| `tag:no_route,121,...` | Default-route-only classless route option for tagged clients |
| `tag:!no_route,121,...` | Default plus extra route for other clients |
| `dhcp-host=MAC,set:no_route,IP,NAME` | Reservation plus routing tag |
| `server=...#15353`, `no-resolv` | Forward to Pi-hole without a host-resolver loop |
| `domain`, `local`, `expand-hosts` | Local naming |
| `rebind-domain-ok=/nat/` | Original suffix-specific rebind exception |
| `dhcp-leasefile`, `log-queries`, `log-dhcp` | Private runtime state and diagnostics |


In `config/dhcp/dnsmasq.conf`, `interface=br0` binds the LAN service and `bind-dynamic` follows interface availability. The example pool is `192.168.4.50–192.168.4.250`, lease `12h`. DHCP option 3 announces router `192.168.4.1`; option 6 announces its DNS on standard port 53. `server=192.168.4.1#15353` forwards to Pi-hole, while `no-resolv` prevents resolver loops. `domain=local`, `local=/local/`, `expand-hosts` and `rebind-domain-ok=/nat/` retain local naming and the original specific rebind exception. The lease file is private runtime state. `log-queries` and `log-dhcp` are diagnostic logs that must not be published.

All **25 original reservations** are retained as disabled examples with fictitious MACs and `example-device-NN` hostnames. Replace MAC, IP and hostname before enabling a line. Preserve unique addresses and the original `set:no_route` tags where intended.

Both original classless-route option 121 variants are retained as disabled examples. Clients tagged `no_route` receive only the default route; other clients also receive the additional network via its LAN next hop. `192.0.2.0/24` is documentation space, not the owner’s network. Replace it and its gateway before activating those lines. Include the default route in the same option-121 instance: clients receiving 121 may ignore router option 3. Do not split the list into conflicting option-121 directives. The tag means “no extra route”, not “no default gateway”.

`server-routes.sh` and `EXTRA_ROUTES` configure routes **on the router**, using semicolon-separated `NETWORK/CIDR,GATEWAY` entries. These differ from routes advertised to DHCP clients. Check next-hop reachability and the return route.

## Iptables and ebtables

`config/iptables/iptables-rules.sh` retains all **49 original rule/tuning commands**. Set `ISOLATED_DEVICE_1_IP` or `ISOLATED_DEVICE_2_IP` to enable the corresponding original per-device block; empty values disable only those blocks.

| Original block | Effect |
|---|---|
| Dedicated mangle chain | Create/flush/attach only `pi-dock-wifi-mangle`, without globally flushing mangle |
| MSS clamp | `TCPMSS --clamp-mss-to-pmtu` on TCP SYN/RST, useful with tunnel/exit-node MTU |
| Dedicated filter chain | Attach the project chain to FORWARD without flushing unrelated host chains |
| Dedicated NAT chain | PREROUTING hook for DNS redirection |
| Targeted cleanup | Remove the listed old uplink/`wt0` masquerade and INPUT rules before restoring them |
| 2.1 | Accept RELATED/ESTABLISHED return traffic |
| Rogue DHCP protection | Ebtables drops forwarded UDP source-port-67 replies; locally generated DHCP does not cross this FORWARD |
| 2.2 | Allow new uplink→LAN forwarding, relying on the original upstream perimeter firewall |
| 2.3/2.4 | For each configured device, allow NetBird directions and LAN destinations, then REJECT other traffic from that IP before general LAN→uplink acceptance |
| 2.5 | Allow other LAN clients to use the uplink |
| 2.6 | Forward between uplink, `wt0` and `br0`; NetBird peer ACLs remain separate |
| 2.7 | Preserve loopback/established INPUT and listed local DNS/HTTP interface rules |
| 3.1 | Masquerade through the uplink |
| 3.2 | Masquerade through `wt0`, presenting the VPN router source to peers |
| 3.3 | Redirect incoming NetBird TCP/UDP DNS 53 to local Pi-hole port 15353 |
| 3.4 | Note externally managed device-specific rules without duplicating them |
| 4 | Preserve UDP conntrack timeout values 120/180 seconds and optional Ethernet/bridge GRO tuning |

Original HTTP/80 rules are retained; they are distinct from dashboard 8888 and Pi-hole 8090. INPUT means traffic addressed to the router; FORWARD means traffic crossing it; PREROUTING and POSTROUTING transform traffic before/after routing. A FORWARD acceptance does not open a local listening service.

The original ebtables rule affects host bridge FORWARD rather than a newly isolated chain; evaluate it when other bridges exist. IP-based restrictions depend on correct addressing and reservations; they do not replace VLANs, authentication or full network ACLs.

## Customize the example network

Changing `192.168.4.0/24` requires consistent updates:

| File | Values to adjust |
|---|---|
| `config/dhcp/dnsmasq.conf` | Pool, gateway, DNS, reservations and DHCP-route next hops |
| `config/start-scripts/dnsmasq_start.sh` | br0 address/prefix and readiness check |
| `config/entrypoint.sh` | Resolver set during initialization |
| `config/healthcheck.sh` | Expected `BRIDGE_ADDRESS` |
| `config/dhcp/dhclient.conf` | Reference resolver |
| `config/iptables/iptables-rules.sh` | LAN restriction subnet; uplink/VPN interfaces |
| `i18n/logs.json` and `config/i18n.sh` | Italian/English log messages and matchers containing the DNS address; keep the catalogue and runtime consistent |
| `.env` | Isolated-device addresses and extra routes |
| `config/recovery/config.json` | Expected **uplink** network/gateway, separate from LAN |

Before starting, verify reservations, interface names, device IPs, option-121 tags/routes, router routes, return paths, resolvers, DNS exceptions, ports and upstream firewall policies.

## Read-only verification

```sh
iptables-save
iptables -t nat -S
iptables -t mangle -S
ebtables -L
ip -4 route
ss -lntup
```

> [!NOTE]
> Keep diagnostic output private. Never globally flush host rules just to remove or clean this project.
