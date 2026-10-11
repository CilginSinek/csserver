import concurrent.futures
import socket
import tempfile
import threading
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from accounts.service import AccountError, FOUNDER_FLAGS, Server, Store


class AccountsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'db/accounts.sqlite3'
        self.store = Store(self.path)
        self.store.bootstrap('Kurucu', 'Kurucu123!')

    def tearDown(self):
        self.temp.cleanup()

    def test_guest_and_protected_nick(self):
        self.assertEqual(self.store.auth('guest', '1', 'Misafir', ''), 'OK|GUEST|0')
        for password in ('', 'Yanlis123'):
            with self.assertRaisesRegex(AccountError, 'BAD_PASSWORD'):
                self.store.auth('bad', '2', 'kurucu', password)
        self.assertEqual(self.store.auth('founder', '1', 'KURUCU', 'Kurucu123!'), f'OK|ACCOUNT|{FOUNDER_FLAGS}')
        with self.assertRaisesRegex(AccountError, 'ALREADY_CONNECTED'):
            self.store.auth('duplicate', '1', 'Kurucu', 'Kurucu123!')

    def test_registration_and_permissions(self):
        self.store.auth('owner', '1', 'Kurucu', 'Kurucu123!')
        self.store.authorize('owner')
        with self.assertRaisesRegex(AccountError, 'FORBIDDEN'):
            self.store.authorize('guest')
        self.store.change('REGISTER', 'Oyuncu', 'Oyuncu123')
        with self.assertRaisesRegex(AccountError, 'EXISTS'):
            self.store.change('REGISTER', 'oyuncu', 'Baska123')
        self.assertEqual(self.store.auth('player', '3', 'Oyuncu', 'Oyuncu123'), 'OK|ACCOUNT|0')
        with self.assertRaisesRegex(AccountError, 'FORBIDDEN'):
            self.store.authorize('player')
        self.store.change('GRANT', 'Oyuncu', flags=1 << 11)
        with self.assertRaisesRegex(AccountError, 'FORBIDDEN'):
            self.store.authorize('player')
        self.store.auth('player', '3', 'Oyuncu', 'Oyuncu123')
        self.store.authorize('player')

    def test_reset_delete_and_founder_protection(self):
        self.store.change('REGISTER', 'Oyuncu', 'Oyuncu123')
        self.store.auth('player', '3', 'Oyuncu', 'Oyuncu123')
        self.store.change('RESET', 'Oyuncu', 'YeniSifre123')
        with self.assertRaisesRegex(AccountError, 'BAD_PASSWORD'):
            self.store.auth('player', '3', 'Oyuncu', 'Oyuncu123')
        self.store.auth('player', '3', 'Oyuncu', 'YeniSifre123')
        self.store.change('DELETE', 'Oyuncu')
        self.assertEqual(self.store.auth('player', '3', 'Oyuncu', ''), 'OK|GUEST|0')
        with self.assertRaisesRegex(AccountError, 'FOUNDER_PROTECTED'):
            self.store.change('DELETE', 'Kurucu')

    def test_persistence_and_explicit_founder_sync(self):
        self.store.bootstrap('Kurucu', 'Ignored123')
        fresh = Store(self.path)
        self.assertEqual(fresh.auth('owner', '1', 'Kurucu', 'Kurucu123!'), f'OK|ACCOUNT|{FOUNDER_FLAGS}')
        with self.assertRaises(ValueError):
            fresh.bootstrap('YeniKurucu', 'YeniSifre123')
        fresh.bootstrap('YeniKurucu', 'YeniSifre123', sync=True)
        self.assertEqual(fresh.auth('old', '1', 'Kurucu', 'Kurucu123!'), 'OK|ACCOUNT|0')
        self.assertEqual(fresh.auth('new', '1', 'YeniKurucu', 'YeniSifre123'), f'OK|ACCOUNT|{FOUNDER_FLAGS}')
        self.assertNotIn(b'Kurucu123!', self.path.read_bytes())

    def test_rate_limit(self):
        for _ in range(5):
            with self.assertRaisesRegex(AccountError, 'BAD_PASSWORD'):
                self.store.auth('bad', '2', 'Kurucu', 'Wrong123')
        with self.assertRaisesRegex(AccountError, 'RATE_LIMIT'):
            self.store.auth('bad', '2', 'Kurucu', 'Wrong123')

    def test_concurrent_duplicate_login(self):
        def login(sid):
            try: return self.store.auth(sid, '1', 'Kurucu', 'Kurucu123!')
            except AccountError as e: return str(e)
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            answers = list(pool.map(login, ['first', 'second']))
        self.assertEqual(sum(a.startswith('OK|ACCOUNT') for a in answers), 1)
        self.assertIn('ALREADY_CONNECTED', answers)

    def test_nickname_cannot_retain_privileges(self):
        self.store.auth('owner', '1', 'Kurucu', 'Kurucu123!')
        self.store.auth('owner', '1', 'Misafir', '')
        with self.assertRaisesRegex(AccountError, 'FORBIDDEN'):
            self.store.authorize('owner')

    def test_live_session_survives_external_password_attempts(self):
        self.store.auth('owner', '1', 'Kurucu', 'Kurucu123!')
        for _ in range(5):
            with self.assertRaisesRegex(AccountError, 'BAD_PASSWORD'):
                self.store.auth('attacker', '2', 'Kurucu', 'Wrong123')
        self.assertEqual(self.store.auth('owner', '1', 'Kurucu', 'Kurucu123!'), f'OK|ACCOUNT|{FOUNDER_FLAGS}')

    def test_disconnect_prevents_late_authentication(self):
        self.store.auth('owner', '1', 'Kurucu', 'Kurucu123!')
        self.store.dispatch('RELEASE', ['owner'])
        with self.assertRaisesRegex(AccountError, 'RELEASED'):
            self.store.auth('owner', '1', 'Kurucu', 'Kurucu123!')
        self.assertEqual(self.store.auth('new-session', '1', 'Kurucu', 'Kurucu123!'), f'OK|ACCOUNT|{FOUNDER_FLAGS}')

    def test_wire_authorization_and_fragmentation(self):
        server = Server(('127.0.0.1', 0), self.store, 'test-secret')
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        def request(packet):
            with socket.create_connection(server.server_address) as s:
                # TCP segmentation must not break line framing.
                s.sendall(packet[:7]); s.sendall(packet[7:]); return s.recv(1024).decode().strip()
        try:
            self.assertEqual(request(b'bad|PING\n'), 'ERR|FORBIDDEN')
            self.assertEqual(request(b'test-secret|PING\n'), 'OK|PONG|0')
            hn, hp = 'Kurucu'.encode().hex(), 'Kurucu123!'.encode().hex()
            self.assertEqual(request(f'test-secret|AUTH|owner|1|{hn}|{hp}\n'.encode()), f'OK|ACCOUNT|{FOUNDER_FLAGS}')
            nick, password = 'Yeni'.encode().hex(), 'Sifre123!'.encode().hex()
            self.assertEqual(request(f'test-secret|REGISTER|nobody|{nick}|{password}\n'.encode()), 'ERR|FORBIDDEN')
            self.assertEqual(request(f'test-secret|REGISTER|owner|{nick}|{password}\n'.encode()), 'OK|SAVED|0')
        finally:
            server.shutdown(); server.server_close(); worker.join()


if __name__ == '__main__':
    unittest.main()
