#!/usr/bin/env python3
"""Loopback-only, token-authenticated account service for the AMXX bridge.

Wire format: token|operation|arguments...\n, strings are UTF-8 hex encoded.
Passwords are never written to logs. Each request has its own TCP connection.
"""
from collections import defaultdict, deque
import hashlib
import hmac
import json
import logging
import os
from pathlib import Path
import secrets
import socketserver
import sqlite3
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from common import ROOT, load_env, token, validate_nick, validate_password

FOUNDER_FLAGS = (1 << 21) - 1  # a..u; z (ordinary player) is not an admin flag.
MANAGE_FLAG = 1 << 11         # ADMIN_RCON (l).


class AccountError(Exception):
    pass


class Store:
    def __init__(self, path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.path.parent.chmod(0o700)
        with self.db() as db:
            db.execute('PRAGMA journal_mode=WAL')
            db.execute('''CREATE TABLE IF NOT EXISTS accounts (
                nick_key TEXT PRIMARY KEY, nick TEXT NOT NULL, salt BLOB NOT NULL,
                digest BLOB NOT NULL, flags INTEGER NOT NULL DEFAULT 0,
                founder INTEGER NOT NULL DEFAULT 0, revision INTEGER NOT NULL DEFAULT 1)''')
            db.execute('CREATE UNIQUE INDEX IF NOT EXISTS single_founder ON accounts(founder) WHERE founder=1')
        self.path.chmod(0o600)
        self.lock = threading.RLock()
        self.sessions = {}
        self.attempts = defaultdict(deque)
        self.released = {}

    def db(self):
        return sqlite3.connect(self.path, timeout=5)

    @staticmethod
    def hashed(password, salt):
        return hashlib.scrypt(password.encode('utf-8'), salt=salt, n=16384, r=8, p=1, dklen=32, maxmem=64 * 1024 * 1024)

    def lookup(self, nick):
        key = validate_nick(nick)
        with self.db() as db:
            db.row_factory = sqlite3.Row
            row = db.execute('SELECT * FROM accounts WHERE nick_key=?', (key,)).fetchone()
        return row

    def founder(self):
        with self.db() as db:
            return db.execute('SELECT nick_key FROM accounts WHERE founder=1').fetchone()

    def bootstrap(self, nick, password, sync=False):
        key = validate_nick(nick)
        validate_password(password)
        with self.lock:
            existing = self.founder()
            if existing and not sync:
                if existing[0] != key:
                    raise ValueError('Kurucu nicki degismis. tools/account_admin.py sync-founder kullanin.')
                return False
            salt = secrets.token_bytes(16)
            digest = self.hashed(password, salt)
            with self.db() as db:
                db.execute('UPDATE accounts SET founder=0, flags=0, revision=revision+1 WHERE founder=1')
                db.execute('''INSERT INTO accounts(nick_key,nick,salt,digest,flags,founder) VALUES(?,?,?,?,?,1)
                    ON CONFLICT(nick_key) DO UPDATE SET nick=excluded.nick,salt=excluded.salt,
                    digest=excluded.digest,flags=excluded.flags,founder=1,revision=accounts.revision+1''',
                    (key, nick, salt, digest, FOUNDER_FLAGS))
            self.sessions.clear()
            logging.info('founder_sync nick=%s', nick)
            return True

    def change(self, operation, nick, password='', flags=0):
        key = validate_nick(nick)
        if operation in ('REGISTER', 'RESET'):
            validate_password(password)
            salt = secrets.token_bytes(16)
            digest = self.hashed(password, salt)
        with self.lock, self.db() as db:
            row = db.execute('SELECT founder FROM accounts WHERE nick_key=?', (key,)).fetchone()
            if operation == 'REGISTER':
                if row:
                    raise AccountError('EXISTS')
                db.execute('INSERT INTO accounts(nick_key,nick,salt,digest) VALUES(?,?,?,?)', (key, nick, salt, digest))
            elif not row:
                raise AccountError('NOT_FOUND')
            elif operation == 'RESET':
                db.execute('UPDATE accounts SET salt=?,digest=?,revision=revision+1 WHERE nick_key=?', (salt, digest, key))
            elif row[0]:
                raise AccountError('FOUNDER_PROTECTED')
            elif operation == 'DELETE':
                db.execute('DELETE FROM accounts WHERE nick_key=?', (key,))
            elif operation == 'GRANT':
                if flags < 0 or flags > FOUNDER_FLAGS:
                    raise ValueError('Gecersiz yetki bayraklari.')
                db.execute('UPDATE accounts SET flags=?,revision=revision+1 WHERE nick_key=?', (flags, key))
            else:
                raise ValueError('Gecersiz islem.')
            # Existing clients will be rechecked within five seconds.
            self.sessions = {sid: s for sid, s in self.sessions.items() if s['key'] != key}
        logging.info('%s nick=%s', operation.lower(), nick)

    def _prune(self, now):
        self.sessions = {sid: s for sid, s in self.sessions.items() if now - s['seen'] < 20}
        self.released = {sid: stamp for sid, stamp in self.released.items() if now - stamp < 20}
        for key in list(self.attempts):
            queue = self.attempts[key]
            while queue and now - queue[0] >= 60:
                queue.popleft()
            if not queue:
                del self.attempts[key]

    def auth(self, sid, ip, nick, password):
        key = validate_nick(nick)
        row = self.lookup(nick)
        now = time.monotonic()
        with self.lock:
            self._prune(now)
            if sid in self.released:
                raise AccountError('RELEASED')
            previous = self.sessions.get(sid)
            if previous and previous['key'] != key:
                self.sessions.pop(sid, None)
            if not row:
                self.sessions.pop(sid, None)
                return 'OK|GUEST|0'
            verified = previous and previous['key'] == key and previous['revision'] == row['revision']
            for limit_key, limit in [('nick:' + key, 5), ('ip:' + ip, 20)]:
                if not verified and len(self.attempts.get(limit_key, ())) >= limit:
                    raise AccountError('RATE_LIMIT')
            # Count in-flight checks too, avoiding concurrent brute-force bypass.
            self.attempts['nick:' + key].append(now)
            self.attempts['ip:' + ip].append(now)
        if not hmac.compare_digest(self.hashed(password, row['salt']), row['digest']):
            with self.lock:
                self.sessions.pop(sid, None)
            raise AccountError('BAD_PASSWORD')
        with self.lock:
            current = self.lookup(nick)
            if sid in self.released:
                raise AccountError('RELEASED')
            if not current or current['revision'] != row['revision']:
                raise AccountError('RETRY')
            if any(s['key'] == key and other != sid for other, s in self.sessions.items()):
                raise AccountError('ALREADY_CONNECTED')
            self.attempts.pop('nick:' + key, None)
            # Successful heartbeat requests must not throttle their own IP.
            try:
                self.attempts['ip:' + ip].remove(now)
            except ValueError:
                pass
            self.sessions[sid] = {'key': key, 'flags': row['flags'], 'revision': row['revision'], 'seen': now}
        return f"OK|ACCOUNT|{row['flags']}"

    def authorize(self, sid):
        with self.lock:
            self._prune(time.monotonic())
            session = self.sessions.get(sid)
            if not session:
                raise AccountError('FORBIDDEN')
            row = self.lookup(session['key'])
            if not row or row['revision'] != session['revision'] or not row['flags'] & MANAGE_FLAG:
                raise AccountError('FORBIDDEN')

    def dispatch(self, operation, args):
        def decode(text):
            if len(text) > 256:
                raise ValueError('Alan cok uzun.')
            return bytes.fromhex(text).decode('utf-8')
        if operation == 'PING' and not args:
            return 'OK|PONG|0'
        if operation == 'AUTH' and len(args) == 4:
            sid, ip, nick, password = args
            if not sid or len(sid) > 64 or len(ip) > 64:
                raise ValueError('Gecersiz oturum.')
            return self.auth(sid, ip, decode(nick), decode(password))
        if operation == 'RELEASE' and len(args) == 1:
            with self.lock:
                self.sessions.pop(args[0], None)
                self.released[args[0]] = time.monotonic()
            return 'OK|RELEASED|0'
        if operation in ('REGISTER', 'RESET', 'DELETE') and len(args) == 3:
            actor, nick, password = args
            with self.lock:
                self.authorize(actor)
                self.change(operation, decode(nick), decode(password))
            logging.info('actor_session=%s operation=%s', actor, operation)
            return 'OK|SAVED|0'
        raise ValueError('Gecersiz istek.')


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, address, store, secret):
        self.store = store
        self.secret = secret
        self.workers = threading.BoundedSemaphore(8)
        super().__init__(address, Handler)

    def process_request(self, request, address):
        if not self.workers.acquire(blocking=False):
            request.close()
            return
        try:
            super().process_request(request, address)
        except Exception:
            self.workers.release()
            raise

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.workers.release()


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        self.request.settimeout(3)
        try:
            raw = self.rfile.readline(1025)
            if len(raw) > 1024 or not raw.endswith(b'\n'):
                raise ValueError('Gecersiz paket.')
            secret, operation, *args = raw.decode('ascii').strip().split('|')
            if not hmac.compare_digest(secret, self.server.secret):
                raise AccountError('FORBIDDEN')
            answer = self.server.store.dispatch(operation, args)
        except AccountError as exc:
            answer = 'ERR|' + str(exc)
        except (ValueError, UnicodeError):
            answer = 'ERR|INVALID'
        except Exception:
            # Do not include raw requests or password-bearing exception strings.
            logging.error('Account request failed (%s)', sys.exc_info()[0].__name__)
            answer = 'ERR|UNAVAILABLE'
        self.wfile.write((answer + '\n').encode('ascii'))


def main():
    os.umask(0o077)
    env = load_env()
    logs = ROOT / 'logs'
    logs.mkdir(exist_ok=True)
    logging.basicConfig(filename=logs / 'accounts.log', level=logging.INFO, format='%(asctime)s %(message)s')
    store = Store(ROOT / 'data/accounts.sqlite3')
    store.bootstrap(env['FOUNDER_NICK'], env['FOUNDER_PASSWORD'])
    with Server(('127.0.0.1', int(env['ACCOUNT_PORT'])), store, token()) as server:
        logging.info('Service ready on loopback port %s', env['ACCOUNT_PORT'])
        server.serve_forever(poll_interval=0.25)


if __name__ == '__main__':
    main()
