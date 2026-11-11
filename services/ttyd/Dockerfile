# ==============================================================================
# Dockerfile - ttyd (web terminal)
# Traduzione / Translation: Dockerfile ttyd, terminale web
# ==============================================================================
FROM debian:latest
ENV TZ=Europe/Rome
ARG DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
# Dipendenze runtime + compilazione passh
# Traduzione / Translation: Runtime dependencies and passh compilation
# ------------------------------------------------------------------------------
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl procps ssh nano wget iputils-ping \
        git gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
# Scarica ttyd binary (versione pinned, con fallback su GitHub API)
# Traduzione / Translation: Download the pinned ttyd binary, with GitHub API fallback
# ------------------------------------------------------------------------------
ARG TARGETARCH
ARG TTYD_VERSION=1.7.7

RUN ARCH=$(case "${TARGETARCH}" in \
        amd64) echo "x86_64" ;; \
        arm64) echo "aarch64" ;; \
        arm)   echo "armhf" ;; \
        *)     echo "aarch64" ;; \
    esac) && \
    # Prova prima la versione pinned, poi fallback su GitHub API
    # Traduzione / Translation: Try the pinned version first, then the GitHub API fallback
    VERSION="${TTYD_VERSION}" && \
    if [ -z "$VERSION" ]; then \
        VERSION=$(curl -sf --retry 3 https://api.github.com/repos/tsl0922/ttyd/releases/latest \
            | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'); \
    fi && \
    echo "Downloading ttyd ${VERSION} for ${ARCH}..." && \
    curl -fSL --retry 3 \
        "https://github.com/tsl0922/ttyd/releases/download/${VERSION}/ttyd.${ARCH}" \
        -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd && \
    ttyd --version

# ------------------------------------------------------------------------------
# Compila passh (wrapper SSH con password automatica)
# Traduzione / Translation: Build passh, the automatic-password SSH wrapper
# ------------------------------------------------------------------------------
RUN git clone https://github.com/clarkwang/passh /passh && \
    gcc -o /passh/passh /passh/passh.c && \
    cp /passh/passh /usr/local/bin/ && \
    chmod +x /usr/local/bin/passh && \
    rm -rf /passh

# ------------------------------------------------------------------------------
# Script di connessione SSH
# Traduzione / Translation: SSH connection script
# ------------------------------------------------------------------------------
RUN tee /usr/local/bin/sshconnect > /dev/null <<'END_SCRIPT'
#!/bin/bash
set -e
if [[ -r /run/pi-dock-wifi/ttyd.env ]]; then
    . /run/pi-dock-wifi/ttyd.env
fi
# IT: Localizza solo il testo dell’errore; autenticazione SSH invariata.
# EN: Localize only the error text; SSH authentication is unchanged.
case "${APP_LANGUAGE:-it}" in
    en) pdw_ssh_required='SSH_PASSWORD is missing' ;;
    *) pdw_ssh_required='SSH_PASSWORD mancante' ;;
esac
: "${SSH_PASSWORD:?$pdw_ssh_required}"
exec passh -p "$SSH_PASSWORD" ssh \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile=/etc/ssh/router_known_hosts \
    "${SSH_USER:-pi}@${SSH_HOST:-127.0.0.1}"
END_SCRIPT
RUN chmod +x /usr/local/bin/sshconnect

# ------------------------------------------------------------------------------
# Script wrapper ttyd
# Traduzione / Translation: ttyd wrapper script
# ------------------------------------------------------------------------------
RUN tee /usr/local/bin/start-ttyd > /dev/null <<'END_SCRIPT'
#!/bin/bash
exec ttyd --interface lo --port "${PORT:-3000}" --check-origin -W bash /usr/local/bin/sshconnect
END_SCRIPT
RUN chmod +x /usr/local/bin/start-ttyd

# ------------------------------------------------------------------------------
# Bashrc
# Traduzione / Translation: Configurazione Bashrc
# ------------------------------------------------------------------------------
RUN tee /etc/bash.bashrc > /dev/null <<'END_SCRIPT'
export CLICOLOR=1
alias rm="rm -i"
alias mv="mv -i"
alias cp="cp -i"
alias ls="ls --color=auto"
alias ll="ls -alh"
export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
export EDITOR="nano"
END_SCRIPT

EXPOSE 3000
WORKDIR /home
CMD ["/usr/local/bin/start-ttyd"]
# Future rebuild guard: preserve newer patched runtime versions.
# CVE-2026-111497: narrow security updates; application and network configuration retained.
# Traduzione / Translation: Protezione delle build future: conserva versioni runtime già corrette. CVE-2026-111497: aggiornamento
# IT/EN: di sicurezza circoscritto, con applicazione e rete invariate.
USER 0
RUN apt-get update && apt-get install -y --no-install-recommends --only-upgrade libbrotli1 && rm -rf /var/lib/apt/lists/*
USER 0
# End CVE-2026-111497 patch.
# Traduzione / Translation: Fine della patch CVE-2026-111497
