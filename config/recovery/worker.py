#!/usr/bin/env python3
'Container-owned Ethernet worker. Never starts NetworkManager or DHCP.\n\nIT/EN: Worker Ethernet gestito dal container; non avvia mai NetworkManager o DHCP'
from runtime_i18n import text as pdw_text

import fcntl
import json
import os
from pathlib import Path
import signal
import sys
import time

import recovery

HERE = Path(__file__).resolve().parent
RUNTIME = Path('/run/pi-dock-wifi/uplink')
STATE = Path('/var/lib/pi-dock-wifi/uplink')


def resolve_profile(config, runner=recovery.run):
    config = dict(config)
    override = os.environ.get('UPLINK_PROFILE_UUID') or config.get('connection_uuid')
    rc, ids = runner(['nmcli', '-g', 'UUID', 'connection', 'show'])
    if rc:
        raise RuntimeError(pdw_text('NetworkManager host non raggiungibile tramite D-Bus'))
    candidates = []
    for uuid in ids.splitlines():
        if override and uuid != override:
            continue
        rc, details = runner(['nmcli', '--escape', 'no', '-g',
                              'connection.id,connection.type,connection.interface-name',
                              'connection', 'show', 'uuid', uuid])
        fields = details.splitlines()
        if rc or len(fields) < 2:
            continue
        name, kind = fields[:2]
        interface = fields[2] if len(fields) > 2 else ''
        if kind != '802-3-ethernet' or interface not in ['', '--', config['interface']]:
            continue
        if override or name == config.get('connection_name'):
            candidates.append(uuid)
    if len(candidates) != 1:
        raise RuntimeError(pdw_text('Profilo Ethernet assente o ambiguo: verificare nome/interfaccia o UPLINK_PROFILE_UUID'))
    config['connection_uuid'] = candidates[0]
    recovery.validate(config)
    return config


def main():
    for directory, mode in [(RUNTIME, 0o755), (STATE, 0o700)]:
        directory.mkdir(parents=True, exist_ok=True, mode=mode)
        directory.chmod(mode)
    # One worker for the persistent state, even if accidentally launched twice.
    # Traduzione / Translation: Un solo worker per lo stato persistente, anche in caso di doppio avvio accidentale
    with (STATE / 'worker.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print(pdw_text('[WARN] Recupero Ethernet già attivo; nessun secondo gestore'), flush=True)
            return
        config = json.loads((HERE / 'config.json').read_text())
        if os.environ.get('INTERNET') != config['interface']:
            raise RuntimeError(pdw_text('INTERNET e interfaccia recupero non coincidono'))
        config = resolve_profile(config)
        recovery.atomic(RUNTIME / 'effective-config.json', config, 0o600)
        recovery.atomic(RUNTIME / 'worker.json', {'pid': os.getpid(), 'started_at': time.time()}, 0o644)
        previous = recovery.load(STATE / 'state.json')
        previous.pop('condition', None)  # Reconfirm after a container/worker restart. | IT/EN: Riconferma dopo il riavvio del container o del worker
        recovery.atomic(STATE / 'state.json', previous)
        sys.argv = [sys.argv[0], '--config', str(RUNTIME / 'effective-config.json'),
                    '--state-dir', str(STATE), '--runtime-dir', str(RUNTIME)]

        def stop(signum, frame):
            raise SystemExit(0)

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        try:
            while not Path('/tmp/shutdown_in_progress').exists():
                recovery.main()
                time.sleep(15)
        finally:
            (RUNTIME / 'worker.json').unlink(missing_ok=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        # Do not log nmcli command output, which could contain private settings.
        # Traduzione / Translation: Non registrare l’output nmcli: può contenere impostazioni private
        print(pdw_text('[WARN] Recupero Ethernet sospeso: ') + str(exc), flush=True)
        raise SystemExit(1)
