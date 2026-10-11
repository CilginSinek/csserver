#!/usr/bin/env python3
"""Real HLDS startup on loopback with a temporary founder database, never .env."""
from pathlib import Path
import os
import secrets
import socket
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / 'tools'))
from accounts.service import Store, Server
from common import runtime_command
from server import configure_reunion, prepare_config, query, state


def main():
    if state(): raise RuntimeError('Canli sunucu acikken smoke testi calistirmayin.')
    (ROOT / 'logs').mkdir(exist_ok=True)
    cfg = ROOT / 'server/cstrike/generated.cfg'
    backup = cfg.read_bytes() if cfg.exists() else None
    banfiles = [ROOT / 'server/cstrike/banned.cfg', ROOT / 'server/cstrike/listip.cfg',
                ROOT / 'server/cstrike/addons/amxmodx/data/persistent_bans.txt']
    banbackup = {p: p.read_bytes() if p.exists() else None for p in banfiles}
    secret = secrets.token_hex(32)
    with tempfile.TemporaryDirectory() as tmp:
        store = Store(Path(tmp) / 'accounts/accounts.sqlite3')
        store.bootstrap('SmokeFounder', secrets.token_hex(16))
        service = Server(('127.0.0.1', 0), store, secret)
        thread = threading.Thread(target=service.serve_forever, daemon=True); thread.start()
        configure_reunion()
        prepare_config({'SERVER_NAME': 'Deathrun smoke test', 'RCON_PASSWORD': secrets.token_hex(24), 'ACCOUNT_PORT': str(service.server_address[1])}, secret)
        logpath = ROOT / 'logs/smoke-server.log'
        child_env = os.environ.copy()
        child_env['LD_LIBRARY_PATH'] = str(ROOT / 'server') + ':' + str(ROOT / 'downloads/steamcmd/linux32')
        child = None
        try:
            with logpath.open('wb') as log:
                child = subprocess.Popen(runtime_command(ROOT / 'server/hlds_linux', '-game', 'cstrike', '-console', '-noipx',
                                          '+ip', '127.0.0.1', '+port', '27025', '+maxplayers', '16', '+exec', 'generated.cfg', '+map', 'deathrun_temple'),
                                         cwd=ROOT / 'server', env=child_env, stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT)
                for _ in range(200):
                    if child.poll() is not None: raise RuntimeError('HLDS kapandi; logs/smoke-server.log inceleyin.')
                    if query(27025): break
                    time.sleep(0.1)
                else: raise RuntimeError('HLDS query yaniti yok.')
                time.sleep(1.2)
                commands = 'version\nmeta list\namxx plugins\namxx modules\nsv_autobunnyhopping\nsv_enablebunnyhopping\namx_addban "192.0.2.199" 2\n'
                child.stdin.write(commands.encode()); child.stdin.flush()
                time.sleep(2)
                child.stdin.write(b'quit\n'); child.stdin.flush(); child.wait(timeout=10)
            text = logpath.read_text(errors='replace')
            for required in ('Nick Account Guard', 'Deathrun Manager', 'Deathrun Auto Bhop', 'Persistent AMX Bans'):
                if required not in text: raise RuntimeError(f'Eklenti listede yok: {required}')
            for failure in ('bad load', 'Load fails', 'Run time error', 'Host_Error', 'FATAL ERROR', 'Failed to load'):
                if failure.lower() in text.lower(): raise RuntimeError(f'Log hata iceriyor: {failure}')
            records = banfiles[-1].read_text()
            record = next(line for line in records.splitlines() if '192.0.2.199' in line)
            expiration = int(record.split()[1])
            if not 100 <= expiration - int(time.time()) <= 120:
                raise RuntimeError('Sureli ban bitis zamani yanlis.')
            # A fresh engine process must replay the remaining duration, not restart it.
            with (ROOT / 'logs/smoke-ban-restart.log').open('wb') as log:
                child = subprocess.Popen(runtime_command(ROOT / 'server/hlds_linux', '-game', 'cstrike', '-console', '-noipx',
                                          '+ip', '127.0.0.1', '+port', '27025', '+maxplayers', '16', '+exec', 'generated.cfg', '+map', 'deathrun_temple'),
                                         cwd=ROOT / 'server', env=child_env, stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT)
                for _ in range(200):
                    if child.poll() is not None: raise RuntimeError('Ban testinde HLDS kapandi.')
                    if query(27025): break
                    time.sleep(0.1)
                else: raise RuntimeError('Ban testinde query yok.')
                time.sleep(1.5)
                child.stdin.write(b'listip\namx_unban "192.0.2.199"\n'); child.stdin.flush()
                time.sleep(0.5)
                child.stdin.write(b'quit\n'); child.stdin.flush(); child.wait(timeout=10)
            restart_log = (ROOT / 'logs/smoke-ban-restart.log').read_text(errors='replace')
            import re
            listed = ''.join(restart_log.split('IP filter list:', 1)[-1].split('[AMXX]', 1)[0].split())
            remaining = re.search(r'192\.0\.2\.199:([0-9.]+)min', listed)
            if not remaining or not 0 < float(remaining[1]) < 2 or '192.0.2.199' in banfiles[-1].read_text():
                raise RuntimeError('Ban yukleme veya kaldirma testi basarisiz.')
            print('PASS: deathrun_temple, A2S, tum eklentiler, sureli banin yeniden yuklenmesi ve kaldirilmasi.')
        finally:
            if child and child.poll() is None:
                child.terminate()
                try: child.wait(timeout=5)
                except subprocess.TimeoutExpired: child.kill(); child.wait()
            service.shutdown(); service.server_close(); thread.join()
            if backup is not None: cfg.write_bytes(backup)
            elif cfg.exists(): cfg.unlink()
            for path, content in banbackup.items():
                if content is not None: path.write_bytes(content)
                elif path.exists(): path.unlink()


if __name__ == '__main__':
    main()
