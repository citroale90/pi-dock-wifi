# Dipendenze / Dependencies

La licenza GPL-3.0 del progetto non sostituisce le licenze dei componenti di terzi. I Dockerfile mantengono i riferimenti upstream originali. Non sono inclusi binari presi dall’installazione privata.

The project’s GPL-3.0 license does not replace third-party component licenses. Dockerfiles retain the original upstream references. No binaries copied from the private installation are bundled.

| Componente | Sorgente upstream |
|---|---|
| Debian e pacchetti / packages | https://www.debian.org/legal/licenses/ |
| hostapd | https://w1.fi/hostapd/ |
| fastfetch | https://github.com/fastfetch-cli/fastfetch |
| Pi-hole | https://github.com/pi-hole/docker-pi-hole |
| ttyd | https://github.com/tsl0922/ttyd |
| passh | https://github.com/clarkwang/passh |
| Chart.js, caricato come nell’originale / loaded as in the original | https://github.com/chartjs/Chart.js |
| IBM Plex, font web come nell’originale / original web font | https://github.com/IBM/plex |

Le pagine mantengono i riferimenti CDN/font dell’originale. La selezione della lingua non li sostituisce e non introduce servizi cloud per amministrare il router.

The pages retain the original chart CDN and web-font references. Language selection does not replace them or introduce a cloud router-administration service.


## Pi-hole e Brotli / Pi-hole and Brotli

La release usa direttamente `pihole/pihole:2026.10.1`, senza wrapper locale. La [release ufficiale](https://github.com/pi-hole/docker-pi-hole/releases/tag/2026.10.1) aggiorna Alpine a 3.24.3; il controllo delle immagini AMD64 e ARM64 dell’11 novembre 2026 ha rilevato `brotli-libs 1.2.1-r0`. La [release Brotli 1.2.1](https://github.com/google/brotli/releases/tag/v1.2.1) include la correzione CVE-2026-111497.

The release uses `pihole/pihole:2026.10.1` directly, without a local wrapper. Its [official release](https://github.com/pi-hole/docker-pi-hole/releases/tag/2026.10.1) updates Alpine to 3.24.3; AMD64 and ARM64 image checks on 11 November 2026 found `brotli-libs 1.2.1-r0`. [Brotli 1.2.1](https://github.com/google/brotli/releases/tag/v1.2.1) includes the CVE-2026-111497 fix.
