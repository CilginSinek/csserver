#!/usr/bin/env python3
"""Download pinned packages; install HLDS without overwriting persistent state."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import sys
import urllib.request
import zipfile
from common import ROOT, runtime_command

DOWNLOADS = ROOT / 'downloads'
SERVER = ROOT / 'server'


def download(name, item):
    DOWNLOADS.mkdir(exist_ok=True)
    path = DOWNLOADS / Path(item['url']).name
    if not path.exists():
        subprocess.run(['curl', '-fL', '--retry', '2', '--connect-timeout', '15', '--max-time', '180',
                        '-sS', '-o', str(path.with_suffix(path.suffix + '.part')), item['url']], check=True)
        path.with_suffix(path.suffix + '.part').replace(path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if item.get('sha256') and digest != item['sha256']:
        raise ValueError(f'{name}: SHA256 uyusmuyor.')
    print(f'{name}: {path.name} SHA256={digest}', flush=True)
    return path, digest


def unpack(path, dest):
    dest.mkdir(parents=True, exist_ok=True)
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            for member in z.infolist():
                target = (dest / member.filename).resolve()
                if not target.is_relative_to(dest.resolve()):
                    raise ValueError('Arsiv disina cikan yol.')
            z.extractall(dest)
    else:
        with tarfile.open(path) as t:
            t.extractall(dest, filter='data')


def portable_runtime():
    # Ubuntu amd64 multilib packages: no root installation or system modification.
    for package in ('libc6-i386', 'lib32gcc-s1', 'lib32stdc++6'):
        output = subprocess.check_output(['apt-cache', 'show', package], text=True)
        filename = next(line.removeprefix('Filename: ') for line in output.splitlines() if line.startswith('Filename: '))
        path, _ = download(package, {'url': 'https://archive.ubuntu.com/ubuntu/' + filename})
        subprocess.run(['dpkg-deb', '-x', str(path), str(ROOT / 'runtime')], check=True)


def packages():
    manifest = json.loads((ROOT / 'versions.json').read_text())
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = dict(zip(manifest, pool.map(lambda pair: download(*pair), manifest.items())))
    for name, (path, digest) in results.items():
        manifest[name]['sha256'] = digest
        unpack(path, DOWNLOADS / name)
    (ROOT / 'versions.json').write_text(json.dumps(manifest, indent=2) + '\n')
    SERVER.mkdir(exist_ok=True)
    for name in ('rehlds', 'regamedll', 'metamod', 'reapi', 'reunion'):
        print(name, [str(p.relative_to(DOWNLOADS / name)) for p in (DOWNLOADS / name).rglob('*.so')])


def steam():
    binary = DOWNLOADS / 'steamcmd/linux32/steamcmd'
    binary.chmod(0o755)
    for attempt in range(6):
        result = subprocess.run(runtime_command(binary, '+force_install_dir', SERVER, '+login', 'anonymous', '+app_update', '90', '-beta', 'steam_legacy', 'validate', '+quit'), cwd=binary.parent.parent)
        if (SERVER / 'cstrike/maps/de_dust2.bsp').exists() and (SERVER / 'hlds_linux').exists():
            if result.returncode == 0:
                sdk = Path.home() / '.steam/sdk32/steamclient.so'
                sdk.parent.mkdir(parents=True, exist_ok=True)
                if not sdk.exists() and not sdk.is_symlink():
                    sdk.symlink_to(binary.parent / 'steamclient.so')
                return
        print(f'SteamCMD tekrar deneniyor ({attempt + 1}/6), exit={result.returncode}', flush=True)
    raise RuntimeError('SteamCMD kurulumu tamamlanamadi; downloads/steamcmd/logs kontrol edin.')


def overlay():
    # Keep operator configuration on subsequent installs; payloads contain defaults.
    config_root = SERVER / 'cstrike/addons/amxmodx/configs'
    keep = {p: p.read_bytes() for p in config_root.rglob('*') if p.is_file()}
    for relative in ('server.cfg', 'mapcycle.txt', 'reunion.cfg'):
        p = SERVER / 'cstrike' / relative
        if p.exists(): keep[p] = p.read_bytes()
    def copy(src, dst):
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    def find(name, pattern):
        candidates = list((DOWNLOADS / name).rglob(pattern))
        if len(candidates) != 1:
            raise RuntimeError(f'{name}/{pattern}: belirsiz arsiv yapisi {candidates}')
        return candidates[0]
    shutil.copytree(DOWNLOADS / 'rehlds/bin/linux32', SERVER, dirs_exist_ok=True)
    copy(find('regamedll', 'cs.so'), SERVER / 'cstrike/dlls/cs.so')
    copy(find('metamod', 'metamod_i386.so'), SERVER / 'cstrike/addons/metamod/metamod_i386.so')
    copy(find('reunion', 'reunion_mm_i386.so'), SERVER / 'cstrike/addons/reunion/reunion_mm_i386.so')
    cfg = SERVER / 'cstrike/reunion.cfg'
    if not cfg.exists():
        copy(find('reunion', 'reunion.cfg'), cfg)
    for name in ('amxx_base', 'amxx_cstrike', 'reapi'):
        src = DOWNLOADS / name / 'addons'
        shutil.copytree(src, SERVER / 'cstrike/addons', dirs_exist_ok=True)
    parachute_model = find('asset_parachute', 'NEW_Parachutev2.mdl')
    model_data = parachute_model.read_bytes()
    if len(model_data) < 84 or model_data[:4] != b'IDST' or int.from_bytes(model_data[4:8], 'little') != 10:
        raise RuntimeError('GameBanana parachute model is not a GoldSrc MDL v10 file.')
    copy(parachute_model, SERVER / 'cstrike/models/parachute.mdl')
    liblist = SERVER / 'cstrike/liblist.gam'
    import re
    text = liblist.read_text()
    text = re.sub(r'gamedll_linux\s+"[^"]+"', 'gamedll_linux "addons/metamod/metamod_i386.so"', text)
    liblist.write_text(text)
    copy(ROOT / 'config/metamod.ini', SERVER / 'cstrike/addons/metamod/plugins.ini')
    copy(ROOT / 'config/plugins.ini', SERVER / 'cstrike/addons/amxmodx/configs/plugins.ini')
    copy(ROOT / 'config/jailbreak.cfg', SERVER / 'cstrike/addons/amxmodx/configs/jailbreak.cfg')
    copy(ROOT / 'config/deathrun.cfg', SERVER / 'cstrike/addons/amxmodx/configs/deathrun.cfg')
    copy(ROOT / 'config/vanilla.cfg', SERVER / 'cstrike/addons/amxmodx/configs/vanilla.cfg')
    copy(ROOT / 'config/jail_maps.ini', SERVER / 'cstrike/addons/amxmodx/configs/jail_maps.ini')
    copy(ROOT / 'config/deathrun_maps.ini', SERVER / 'cstrike/addons/amxmodx/configs/deathrun_maps.ini')
    copy(ROOT / 'config/server.cfg', SERVER / 'cstrike/server.cfg')
    copy(ROOT / 'config/amxx.cfg', SERVER / 'cstrike/addons/amxmodx/configs/amxx.cfg')
    (SERVER / 'cstrike/mapcycle.txt').write_text('deathrun_temple\njail_buyukisyan_dark\n')
    (SERVER / 'cstrike/addons/amxmodx/configs/users.ini').write_text('; Account plugin assigns permissions after password verification. No stock admin.amxx.\n')
    for name in ('hlds_linux', 'hlds_run'):
        (SERVER / name).chmod(0o755)
    for path, data in keep.items():
        path.write_bytes(data)
    print('Bilesenler yerlestirildi.')


def map_install():
    manifest = json.loads((ROOT / 'versions.json').read_text())
    import struct
    for key, item in manifest.items():
        if not key.startswith('map') or 'mapname' not in item:
            continue
        path, digest = download(key, item)
        if item.get('sha256') and digest != item['sha256']:
            raise ValueError(f'{key}: SHA256 uyusmuyor.')
        dest = DOWNLOADS / key
        unpack(path, dest)
        found = False
        for p in dest.rglob('*'):
            if not p.is_file():
                continue
            relative = p.relative_to(dest)
            resource_roots = ('maps', 'models', 'sound', 'sprites', 'gfx', 'overviews')
            for i, part in enumerate(relative.parts):
                if part.lower() in resource_roots:
                    relative = Path(*relative.parts[i:])
                    break
            if relative.parts[0].lower() == 'cstrike':
                relative = Path(*relative.parts[1:])
            if p.suffix.lower() == '.res':
                relative = Path('maps') / p.name
            elif p.suffix.lower() == '.wad' and len(relative.parts) > 1 and relative.parts[0] not in resource_roots:
                relative = Path(p.name)
            if p.suffix.lower() == '.bsp' and len(relative.parts) == 1:
                relative = Path('maps') / p.name
            if p.name == item['mapname'] + '.bsp':
                data = p.read_bytes()
                if len(data) < 4 or struct.unpack('<i', data[:4])[0] != 30:
                    raise RuntimeError(f'{item["mapname"]}: gecerli GoldSrc BSP degil.')
                found = True
            allowed = ('maps', 'models', 'sound', 'sprites', 'gfx', 'overviews')
            if relative.parts[0] not in allowed and p.suffix.lower() != '.wad':
                continue
            target = SERVER / 'cstrike' / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
        if not found or not (SERVER / 'cstrike/maps' / (item['mapname'] + '.bsp')).exists():
            raise RuntimeError(f'{key}: {item["mapname"]}.bsp arsivde bulunamadi.')
    # The jail map's resource manifest asks clients for this stock sprite too.
    stock_laser = SERVER / 'valve/sprites/laserbeam.spr'
    if stock_laser.exists():
        shutil.copy2(stock_laser, SERVER / 'cstrike/sprites/laserbeam.spr')
    subprocess.run([sys.executable, str(ROOT / 'tools/update_maps.py')], check=True)


if __name__ == '__main__':
    if os.geteuid() == 0:
        print('SteamCMD/oyun dosyalarini root ile kurmayin. Proje dosyalarinin sahibi olan normal kullaniciyla calistirin.', file=sys.stderr)
        raise SystemExit(2)
    parser = argparse.ArgumentParser()
    parser.add_argument('--portable-runtime', action='store_true')
    parser.add_argument('--packages', action='store_true')
    parser.add_argument('--steam', action='store_true')
    parser.add_argument('--overlay', action='store_true')
    parser.add_argument('--map', action='store_true')
    args = parser.parse_args()
    if args.portable_runtime: portable_runtime()
    if args.packages: packages()
    if args.steam: steam()
    if args.overlay: overlay()
    if args.map: map_install()
