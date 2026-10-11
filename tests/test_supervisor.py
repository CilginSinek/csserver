"""Exercise process ownership with isolated .env/database and a loopback game port."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import json
import os
import signal

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from server import state


@unittest.skipUnless((ROOT / 'server/hlds_linux').exists(), 'HLDS not installed')
class SupervisorTest(unittest.TestCase):
    def setUp(self):
        if state(): self.skipTest('Live server is running')
        self.temp = tempfile.TemporaryDirectory()
        self.checkout = Path(self.temp.name)
        shutil.copytree(ROOT / 'tools', self.checkout / 'tools')
        shutil.copytree(ROOT / 'accounts', self.checkout / 'accounts')
        (self.checkout / 'server').symlink_to(ROOT / 'server', target_is_directory=True)
        self.cfg = ROOT / 'server/cstrike/generated.cfg'
        self.original = self.cfg.read_bytes() if self.cfg.exists() else None
        (self.checkout / '.env').write_text('SERVER_NAME="Supervisor test"\nSERVER_PORT=27026\nACCOUNT_PORT=28766\nSERVER_BIND=127.0.0.1\nMAX_PLAYERS=16\nDEFAULT_MAP=deathrun_temple\nFOUNDER_NICK="TestOwner"\nFOUNDER_PASSWORD="TestPassword123"\nRCON_PASSWORD="TestRcon123"\n')
        (self.checkout / '.env').chmod(0o600)

    def call(self, *args, check=True):
        result = subprocess.run([sys.executable, str(self.checkout / 'tools/server.py'), *args], cwd=self.checkout, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30)
        if check and result.returncode:
            logs = ''
            for p in (self.checkout / 'logs').glob('*.log'):
                logs += p.read_text(errors='replace')[-2500:]
            self.fail(result.stdout + logs)
        return result.stdout

    def tearDown(self):
        self.call('stop', check=False)
        if self.original is None:
            if self.cfg.exists(): self.cfg.unlink()
        else: self.cfg.write_bytes(self.original)
        self.temp.cleanup()

    def test_start_duplicate_status_console_stop_and_failure(self):
        self.assertIn('baslatildi', self.call('start'))
        initial = json.loads((self.checkout / 'run/state.json').read_text())
        self.assertIn('zaten calisiyor', self.call('start'))
        self.assertEqual(json.loads((self.checkout / 'run/state.json').read_text())['hlds'], initial['hlds'])
        self.assertIn('HLDS: hazir; hesap servisi: hazir', self.call('status'))
        self.call('console', 'sv_autobunnyhopping')
        time.sleep(0.25)
        self.assertIn('"sv_autobunnyhopping" is "1"', (self.checkout / 'logs/server.log').read_text())
        self.assertIn('durduruldu', self.call('stop'))
        self.assertIn('kapali', self.call('status'))
        self.call('start')
        current = json.loads((self.checkout / 'run/state.json').read_text())
        os.kill(current['accounts'], signal.SIGTERM)
        for _ in range(100):
            if not (self.checkout / 'run/state.json').exists(): break
            time.sleep(0.1)
        self.assertFalse((self.checkout / 'run/state.json').exists(), 'Account process failure must stop HLDS too')


if __name__ == '__main__':
    unittest.main()
