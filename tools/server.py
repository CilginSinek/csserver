#!/usr/bin/env python3
"""Own both processes, lock out duplicate starts and expose a local console FIFO."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import secrets
import selectors
import signal
import socket
import subprocess
import sys
import time
from common import ROOT, load_env, private_file, runtime_command, token

RUN = ROOT / 'run'
STATE = RUN / 'state.json'
STOP = False


def ping(port, secret):
    try:
        with socket.create_connection(('127.0.0.1', int(port)), timeout=1) as s:
            s.sendall((secret + '|PING\n').encode())
            return s.recv(128).startswith(b'OK|PONG|0')
    except OSError:
        return False


def query(port):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.settimeout(1)
            request = b'\xff\xff\xff\xffTSource Engine Query\0'
            s.sendto(request, ('127.0.0.1', int(port)))
            response = s.recv(4096)
            if response[4:5] == b'A':
                s.sendto(request + response[5:9], ('127.0.0.1', int(port)))
                response = s.recv(4096)
            return response[4:5] in (b'I', b'm')
    except OSError:
        return False


def process_stamp(pid):
    try:
        # Start time prevents a recycled PID from being signalled by stop.
        text = Path(f'/proc/{pid}/stat').read_text()
        return text.rsplit(')', 1)[1].split()[19]
    except (OSError, IndexError):
        return None


def state():
    try:
        result = json.loads(STATE.read_text())
        if process_stamp(result['supervisor']) != result['stamp']:
            return None
        return result
    except (OSError, ValueError, KeyError):
        return None


def prepare_config(env, secret=None):
    secret = secret or token()
    rcon = env.get('RCON_PASSWORD', '')
    if not rcon:
        file = ROOT / 'data/rcon.secret'
        if not file.exists():
            private_file(file, secrets.token_hex(24))
        rcon = file.read_text().strip()
    config = f'hostname "{env["SERVER_NAME"]}"\nrcon_password "{rcon}"\n'
    config += f'localinfo account_token "{secret}"\nlocalinfo account_port "{env["ACCOUNT_PORT"]}"\n'
    config += f'localinfo account_epoch "{secrets.token_hex(12)}"\n'
    private_file(ROOT / 'server/cstrike/generated.cfg', config)


def configure_reunion():
    file = ROOT / 'server/cstrike/reunion.cfg'
    text = file.read_text()
    import re
    if re.search(r'^SteamIdHashSalt\s*=\s*$', text, re.M):
        text = re.sub(r'^SteamIdHashSalt\s*=\s*$', 'SteamIdHashSalt = ' + secrets.token_hex(32), text, flags=re.M)
    text = re.sub(r'^cid_NoSteam47\s*=.*$', 'cid_NoSteam47 = 3', text, flags=re.M)
    text = re.sub(r'^cid_NoSteam48\s*=.*$', 'cid_NoSteam48 = 3', text, flags=re.M)
    private_file(file, text)


def stop_signal(signum, frame):
    global STOP
    STOP = True


def supervise():
    global STOP
    os.umask(0o077)
    RUN.mkdir(exist_ok=True, mode=0o700)
    RUN.chmod(0o700)
    with (RUN / 'server.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Sunucu zaten calisiyor.')
        env = load_env()
        if not (ROOT / ('server/cstrike/maps/' + env['DEFAULT_MAP'] + '.bsp')).exists():
            raise ValueError('Harita bulunamadi; once kurulum yapin.')
        subprocess.run([sys.executable, str(ROOT / 'tools/account_admin.py'), 'bootstrap'], check=True)
        configure_reunion()
        prepare_config(env)
        signal.signal(signal.SIGTERM, stop_signal)
        signal.signal(signal.SIGINT, stop_signal)
        logs = ROOT / 'logs'
        logs.mkdir(exist_ok=True)
        children = []
        fifo = RUN / 'console.pipe'
        if fifo.exists(): fifo.unlink()
        os.mkfifo(fifo, 0o600)
        descriptor = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
        try:
            with (logs / 'accounts-process.log').open('ab', buffering=0) as alog, (logs / 'server.log').open('ab', buffering=0) as slog:
                account = subprocess.Popen([sys.executable, str(ROOT / 'accounts/service.py')], stdout=alog, stderr=subprocess.STDOUT)
                children.append(account)
                for _ in range(50):
                    if STOP or account.poll() is not None:
                        raise RuntimeError('Hesap servisi baslatilamadi; logs/accounts-process.log kontrol edin.')
                    if ping(env['ACCOUNT_PORT'], token()): break
                    time.sleep(0.1)
                else:
                    raise RuntimeError('Hesap servisi yanit vermedi.')
                command = runtime_command(ROOT / 'server/hlds_linux', '-game', 'cstrike', '-console', '-norestart', '-noipx',
                                          '+ip', env['SERVER_BIND'], '+port', env['SERVER_PORT'], '+maxplayers', env['MAX_PLAYERS'],
                                          '+exec', 'generated.cfg', '+map', env['DEFAULT_MAP'])
                child_env = os.environ.copy()
                child_env['LD_LIBRARY_PATH'] = str(ROOT / 'server') + ':' + str(ROOT / 'downloads/steamcmd/linux32')
                hlds = subprocess.Popen(command, cwd=ROOT / 'server', env=child_env, stdin=subprocess.PIPE, stdout=slog, stderr=subprocess.STDOUT)
                children.append(hlds)
                info = {'supervisor': os.getpid(), 'stamp': process_stamp(os.getpid()), 'hlds': hlds.pid,
                        'accounts': account.pid, 'port': env['SERVER_PORT'], 'account_port': env['ACCOUNT_PORT']}
                private_file(STATE, json.dumps(info))
                selector = selectors.DefaultSelector()
                selector.register(descriptor, selectors.EVENT_READ)
                while not STOP:
                    if any(p.poll() is not None for p in children):
                        raise RuntimeError('Bir sunucu sureci kapandi; iki surec de durduruluyor. Loglari kontrol edin.')
                    for key, _ in selector.select(timeout=0.25):
                        data = os.read(key.fd, 4096)
                        if data:
                            hlds.stdin.write(data); hlds.stdin.flush()
                selector.close()
        finally:
            # Ask HLDS to quit cleanly so map/plugin state is flushed.
            if len(children) == 2 and children[1].poll() is None:
                try:
                    children[1].stdin.write(b'quit\n'); children[1].stdin.flush()
                    children[1].wait(timeout=5)
                except (OSError, subprocess.TimeoutExpired):
                    pass
            for child in reversed(children):
                if child.poll() is None:
                    child.terminate()
                    try: child.wait(timeout=5)
                    except subprocess.TimeoutExpired: child.kill(); child.wait()
            os.close(descriptor)
            if fifo.exists(): fifo.unlink()
            if STATE.exists(): STATE.unlink()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['start', 'run', '_supervise', 'stop', 'status', 'console'])
    parser.add_argument('command', nargs='?')
    args = parser.parse_args()
    if args.operation in ('run', '_supervise'):
        supervise(); return
    info = state()
    if args.operation == 'start':
        if info:
            print('Sunucu zaten calisiyor.'); return
        load_env()  # Fail before spawning if founder configuration is missing.
        (ROOT / 'logs').mkdir(exist_ok=True)
        with (ROOT / 'logs/supervisor.log').open('ab') as log:
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '_supervise'], stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        for _ in range(150):
            info = state()
            if child.poll() is not None:
                raise RuntimeError('Baslatilamadi; logs/supervisor.log kontrol edin.')
            if info and query(info['port']):
                print(f"Sunucu baslatildi: UDP {info['port']}, PID {info['hlds']}"); return
            time.sleep(0.1)
        os.kill(child.pid, signal.SIGTERM)
        raise RuntimeError('Sunucu hazir olamadi; logs/server.log kontrol edin.')
    if not info:
        print('Sunucu kapali.'); return
    if args.operation == 'stop':
        os.kill(info['supervisor'], signal.SIGTERM)
        for _ in range(100):
            if not state():
                print('Sunucu ve hesap servisi durduruldu.'); return
            time.sleep(0.1)
        raise RuntimeError('Durdurma tamamlanmadi; logs/supervisor.log kontrol edin.')
    if args.operation == 'status':
        secret = (ROOT / 'data/service.token').read_text().strip()
        print(f"HLDS: {'hazir' if query(info['port']) else 'yanit yok'}; hesap servisi: {'hazir' if ping(info['account_port'], secret) else 'yanit yok'}; port: {info['port']}")
    if args.operation == 'console':
        if not args.command or '\n' in args.command or '\r' in args.command:
            raise ValueError('Tek satirlik komut gerekli.')
        descriptor = os.open(RUN / 'console.pipe', os.O_WRONLY | os.O_NONBLOCK)
        try: os.write(descriptor, (args.command + '\n').encode())
        finally: os.close(descriptor)
        print('Komut gonderildi; sonuc logs/server.log dosyasinda.')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
