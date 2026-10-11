"""Shared configuration, validation and portable 32-bit runtime helpers."""
from pathlib import Path
import os
import re
import shlex
import secrets

ROOT = Path(__file__).resolve().parents[1]


def load_env(path=None):
    path = Path(path or ROOT / '.env')
    if not path.exists():
        raise ValueError('.env yok. .env.example dosyasini .env olarak kopyalayip kurucu bilgilerini doldurun.')
    if path.stat().st_mode & 0o077:
        path.chmod(0o600)
    values = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        key, sep, text = line.partition('=')
        if not sep or not re.fullmatch(r'[A-Z_]+', key):
            raise ValueError('Gecersiz .env satiri (KEY=value bekleniyor).')
        parts = shlex.split(text, comments=True)
        if len(parts) > 1:
            raise ValueError(f'{key}: bosluk iceren degeri tirnak icine alin.')
        values[key] = parts[0] if parts else ''
    for key in ('FOUNDER_NICK', 'FOUNDER_PASSWORD'):
        if not values.get(key):
            raise ValueError(f'{key} .env icinde doldurulmali.')
    validate_nick(values['FOUNDER_NICK'])
    validate_password(values['FOUNDER_PASSWORD'])
    for key, default, lo, hi in [('SERVER_PORT', '27015', 1024, 65535), ('ACCOUNT_PORT', '28765', 1024, 65535), ('MAX_PLAYERS', '16', 2, 32)]:
        value = values.setdefault(key, default)
        if not value.isdigit() or not lo <= int(value) <= hi:
            raise ValueError(f'{key}: {lo}..{hi} araliginda olmali.')
    values.setdefault('SERVER_NAME', 'CS 1.6 Deathrun')
    values.setdefault('SERVER_BIND', '0.0.0.0')
    values.setdefault('DEFAULT_MAP', 'deathrun_temple')
    if not re.fullmatch(r'[A-Za-z0-9_]+', values['DEFAULT_MAP']):
        raise ValueError('DEFAULT_MAP gecersiz.')
    for key in ('SERVER_NAME', 'RCON_PASSWORD'):
        if any(c in values.get(key, '') for c in '\n\r";\\'):
            raise ValueError(f'{key}: tirnak, ters egik cizgi, noktali virgul veya yeni satir kullanmayin.')
    return values


def validate_nick(nick):
    if not nick or nick != nick.strip() or len(nick.encode('utf-8')) > 31:
        raise ValueError('Nick 1..31 UTF-8 bayt olmali; basta/sonda bosluk olmamali.')
    if any(ord(c) < 32 or c in '\\";|' for c in nick):
        raise ValueError('Nick kontrol karakteri, tirnak, ters egik cizgi, | veya ; iceremez.')
    return nick.casefold()


def validate_password(password):
    length = len(password.encode('utf-8'))
    if not 8 <= length <= 63:
        raise ValueError('FOUNDER_PASSWORD ve hesap sifreleri 8..63 UTF-8 bayt olmali.')
    if any(ord(c) < 32 or c in '\\";' for c in password):
        raise ValueError('Sifrede kontrol karakteri, cift tirnak, ters egik cizgi veya noktalı virgul kullanilamaz.')


def private_file(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, 'w') as f:
        f.write(text)


def token():
    path = ROOT / 'data/service.token'
    if not path.exists():
        private_file(path, secrets.token_hex(32))
    return path.read_text().strip()


def runtime_command(binary, *args):
    binary = Path(binary).resolve()
    if Path('/lib/ld-linux.so.2').exists():
        return [str(binary), *map(str, args)]
    loader = ROOT / 'runtime/usr/lib32/ld-linux.so.2'
    if loader.exists():
        return [str(loader), '--library-path', ':'.join(map(str, [ROOT / 'runtime/usr/lib32', binary.parent, binary.parent / 'linux32'])), str(binary), *map(str, args)]
    if not Path('/lib/ld-linux.so.2').exists():
        raise ValueError('32 bit runtime yok: python3 tools/install.py --portable-runtime calistirin.')
    return [str(binary), *map(str, args)]
