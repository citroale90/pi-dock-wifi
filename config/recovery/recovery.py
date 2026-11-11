#!/usr/bin/env python3
'Ethernet recovery inside pi-dock-wifi. Never reboot host, Wi-Fi or LAN.\n\nNetworkManager remains the host DHCP owner; this client only activates its\nexisting, explicitly selected Ethernet profile. No GPIO or USB reset code.\n\n\nIT/EN: Recupero Ethernet interno a pi-dock-wifi: non riavvia host, Wi-Fi o LAN. NetworkManager resta l’unico gestore DHCP dell’host; questo client attiva soltanto il suo profilo Ethernet esistente e selezionato esplicitamente. Nessun reset GPIO o USB.'
from runtime_i18n import text as pdw_text

import argparse
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time


def run(args, timeout=8):
    p = None
    try:
        p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             text=True, env={**os.environ, 'LC_ALL': 'C', 'LANG': 'C'})
        stdout, _ = p.communicate(timeout=timeout)
        return p.returncode, stdout.strip()
    except subprocess.TimeoutExpired:
        return 124, ''
    finally:
        # SIGTERM during nmcli must not leave an orphaned management request.
        # Traduzione / Translation: SIGTERM durante nmcli non deve lasciare una richiesta di gestione orfana
        if p is not None and p.poll() is None:
            p.terminate()
            try:
                p.wait(timeout=2)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait()


def atomic(path, value, mode=0o600):
    path = Path(path)
    fd, tmp = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            os.fchmod(f.fileno(), mode)
            json.dump(value, f, allow_nan=False)
            f.write('\n'); f.flush(); os.fsync(f.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)


def load(path):
    try:
        data = json.loads(Path(path).read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def validate(config):
    assert config['role'] == 'ethernet'
    assert re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,14}', config['interface'])
    assert re.fullmatch(r'[0-9a-fA-F-]{36}', config['connection_uuid'])
    if config['role'] == 'ethernet':
        ipaddress.ip_network(config['expected_network'])
        ipaddress.ip_address(config['expected_gateway'])


def snapshot(config, runner=run, sysfs=Path('/sys')):
    iface = config['interface']
    rc, body = runner(['ip', '-j', 'link', 'show', 'dev', iface])
    link = json.loads(body)[0] if rc == 0 and body else None
    out = {'state': 'missing', 'interface': iface, 'usb': 'not_applicable'}
    if link is None:
        return out
    if 'UP' not in link.get('flags', []):
        out['state'] = 'admin_down'; return out
    if config['role'] == 'ethernet':
        try: carrier = (sysfs/'class/net'/iface/'carrier').read_text().strip()
        except OSError: carrier = '0'
        if carrier != '1': out['state'] = 'no_carrier'; return out
    rc, body = runner(['ip', '-j', '-4', 'address', 'show', 'dev', iface])
    if rc: out['state'] = 'probe_error'; return out
    addresses = [a['local'] for d in json.loads(body or '[]')
                 for a in d.get('addr_info', []) if a.get('family') == 'inet' and a.get('scope') == 'global']
    out['addresses'] = addresses
    if not addresses: out['state'] = 'no_ip'; return out
    if config['role'] == 'ethernet' and not any(
            ipaddress.ip_address(a) in ipaddress.ip_network(config['expected_network']) for a in addresses):
        out['state'] = 'unexpected_network'; return out
    rc, body = runner(['ip', '-j', '-4', 'route', 'show', 'default', 'dev', iface])
    if rc: out['state'] = 'probe_error'; return out
    routes = json.loads(body or '[]')
    if not routes: out['state'] = 'no_route'; return out
    if config['role'] == 'ethernet' and not any(r.get('gateway') == config['expected_gateway'] for r in routes):
        out['state'] = 'unexpected_gateway'; return out
    out['state'] = 'configured'
    return out


def decide(config, previous, sample, now, boot):
    state = dict(previous)
    if state.get('boot') != boot or now < state.get('last_tick', 0):
        state = {'boot': boot}
    # A long gap must not count as continuous confirmation of a fault.
    # Traduzione / Translation: Un intervallo lungo non vale come conferma continua di un guasto
    if now - state.get('last_tick', now) > 90:
        state.pop('condition', None)
    state['last_tick'] = now
    condition = sample['state'] + ':' + sample.get('usb', '')
    if state.get('condition') != condition:
        state.update(condition=condition, since=now, samples=0)
    state['samples'] = state.get('samples', 0) + 1
    if sample['state'] == 'configured':
        state.update(attempts=0, next_attempt=0)
        return state, None
    if now < config.get('boot_grace_seconds', 120): return state, None
    if state['samples'] < 2 or now - state['since'] < 15: return state, None
    if now < state.get('next_attempt', 0): return state, None
    if sample['state'] in ['no_carrier', 'probe_error']: return state, None
    action = None
    if config['role'] == 'ethernet':
        if sample['state'] == 'admin_down': action = 'link_up'
        elif sample['state'] in ['no_ip', 'no_route', 'unexpected_network', 'unexpected_gateway']:
            action = 'activate_profile'
    if action:
        state['attempts'] = state.get('attempts', 0) + 1
        state['next_attempt'] = now + min(120, 30 * state['attempts'])
    return state, action


def execute(config, action, runner=run, sysfs=Path('/sys')):
    # Recheck immediately before every intervention, not only before planning.
    # Traduzione / Translation: Ricontrolla immediatamente prima di ogni intervento, non solo prima di pianificarlo
    live = snapshot(config, runner, sysfs)
    if live['state'] == 'configured': return 'already_recovered'
    if action not in ['link_up', 'activate_profile']: raise ValueError(pdw_text('unknown recovery action'))
    if action == 'link_up' and live['state'] != 'admin_down': return 'condition_changed'
    if live['state'] not in ['no_ip', 'no_route', 'unexpected_network', 'unexpected_gateway', 'admin_down']:
        return 'condition_changed'
    # Refuse to override an unmanaged device or a different active profile.
    # Traduzione / Translation: Non sovrascrive un dispositivo non gestito o un diverso profilo attivo
    device = live.get('nm_device', config.get('nm_device', config['interface']))
    rc, body = runner(['nmcli', '-g', 'GENERAL.STATE,GENERAL.CON-UUID', 'device', 'show', device])
    if rc: return 'nm_device_unavailable'
    values = body.splitlines()
    if values and values[0].startswith('10 '): return 'device_unmanaged'
    state_code = values[0].split()[0] if values else ''
    if state_code in ['40', '50', '70', '80', '90']: return 'activation_in_progress'
    if state_code == '60': return 'credentials_required'
    active = values[1].strip() if len(values) > 1 else ''
    if active not in ['', '--', config['connection_uuid']]: return 'another_profile_active'
    if action == 'link_up':
        rc, _ = runner(['ip', 'link', 'set', 'dev', config['interface'], 'up'])
        return 'requested' if rc == 0 else 'failed'
    runner(['nmcli', '--wait', '5', 'device', 'set', device, 'autoconnect', 'yes'])
    args = ['nmcli', '--wait', '25', 'connection', 'up', 'uuid', config['connection_uuid']]
    args += ['ifname', device]
    rc, _ = runner(args, timeout=30)
    return 'requested' if rc == 0 else 'pending_or_failed'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', default=str(Path(__file__).with_name('config.json')))
    parser.add_argument('--observe', action='store_true')
    parser.add_argument('--state-dir',default='/var/lib/pi-dock-wifi/uplink')
    parser.add_argument('--runtime-dir',default='/run/pi-dock-wifi/uplink')
    args = parser.parse_args()
    config = load(args.config); validate(config)
    state_dir = Path(args.state_dir)
    runtime = Path(args.runtime_dir)
    for directory, mode in [(state_dir, 0o700), (runtime, 0o755)]:
        directory.mkdir(mode=mode, parents=True, exist_ok=True)
    runtime.chmod(0o755)
    with (runtime/'lock').open('a') as lock:
        try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: return
        boot = Path('/proc/sys/kernel/random/boot_id').read_text().strip()
        now = time.monotonic(); old = load(state_dir/'state.json')
        sample = snapshot(config)
        state, action = decide(config, old, sample, now, boot)
        if not args.observe: atomic(state_dir/'state.json', state)
        result = None
        if action and not args.observe:
            result = execute(config, action)
            sample = snapshot(config)
        report = {'checked_at': time.time(), 'role': config['role'], **sample,
                  'planned_action': action, 'result': result, 'observe': args.observe}
        # "configured" means IP and route, never a claim that Internet works.
        # Traduzione / Translation: configured significa indirizzo IP e rotta presenti, non accesso Internet funzionante
        atomic(runtime/'status.json', report, 0o644)
        previous = load(state_dir/'last-report.json')
        if (previous.get('state') != report['state'] or action or
                report['checked_at'] - previous.get('checked_at', 0) >= 300):
            print(json.dumps(report), flush=True)
            if not args.observe: atomic(state_dir/'last-report.json', report)


if __name__ == '__main__': main()
