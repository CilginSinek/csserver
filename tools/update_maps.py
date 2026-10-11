#!/usr/bin/env python3
"""Keep AMXX's map menu in sync with the BSP files installed on this server."""
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parent.parent
CS = ROOT / 'server/cstrike'


def overview_text(bsp: Path) -> str:
    data = bsp.read_bytes()
    if len(data) < 124 or struct.unpack_from('<i', data)[0] != 30:
        return ''
    lumps = [struct.unpack_from('<ii', data, 4 + i * 8) for i in range(15)]
    offset, size = lumps[14]
    if size < 64 or offset + 64 > len(data):
        return ''
    mins = struct.unpack_from('<3f', data, offset)
    maxs = struct.unpack_from('<3f', data, offset + 12)
    origin = [(mins[i] + maxs[i]) / 2 for i in range(3)]
    return ('// Generated overview metadata.\n'
            'global\n{\n'
            '\tZOOM\t1.0\n'
            f'\tORIGIN\t{origin[0]:.0f} {origin[1]:.0f} {origin[2]:.0f}\n'
            '\tROTATED\t0\n'
            '}\n')


def fallback_overview_bmp() -> bytes:
    """Build a valid, subdued indexed BMP when a custom map has no overview."""
    width, height = 1024, 768
    palette = bytearray()
    for value in range(256):
        shade = min(92, 28 + value // 4)
        palette.extend((shade, shade, shade, 0))
    pixels = bytearray(width * height)
    # A restrained grid makes the placeholder distinguishable from a corrupt
    # or zero-byte asset while keeping it legible in the in-game overview UI.
    for y in range(height):
        for x in range(width):
            if x % 64 == 0 or y % 64 == 0:
                pixels[y * width + x] = 112
            else:
                pixels[y * width + x] = 24
    image = bytearray()
    for y in range(height - 1, -1, -1):
        image.extend(pixels[y * width:(y + 1) * width])
    offset = 14 + 40 + len(palette)
    size = offset + len(image)
    return (struct.pack('<2sIHHI', b'BM', size, 0, 0, offset)
            + struct.pack('<IIIHHIIIIII', 40, width, height, 1, 8, 0,
                          len(image), 2835, 2835, 256, 256)
            + palette + image)


def required_wads(bsp: Path) -> list[str]:
    data = bsp.read_bytes()
    if len(data) < 124 or struct.unpack_from('<i', data)[0] != 30:
        return []
    offset, size = struct.unpack_from('<ii', data, 4)
    if size <= 0 or offset + size > len(data):
        return []
    entities = data[offset:offset + size].decode('latin1', 'replace')
    match = re.search(r'"wad"\s+"([^"]*)"', entities, re.IGNORECASE)
    if not match:
        return []
    return [Path(item.strip().replace('\\', '/')).name.lower()
            for item in match.group(1).split(';') if item.strip()]


def missing_wads(bsp: Path) -> list[str]:
    available = {p.name.lower() for folder in (CS, ROOT / 'server/valve') for p in folder.glob('*.wad')}
    return [name for name in required_wads(bsp) if name not in available]


def main():
    maps_dir = CS / 'maps'
    all_names = sorted(p.stem for p in maps_dir.glob('*.bsp') if re.fullmatch(r'[A-Za-z0-9_-]+', p.stem))
    names, blocked = [], []
    for name in all_names:
        bsp = maps_dir / f'{name}.bsp'
        wads = required_wads(bsp)
        res = maps_dir / f'{name}.res'
        if wads:
            current = res.read_text(errors='replace').splitlines() if res.exists() else []
            present = {line.strip().lower() for line in current if line.strip() and not line.lstrip().startswith('//') and not line.lstrip().startswith(';')}
            additions = [wad for wad in wads if wad not in present]
            if additions:
                res.write_text('\n'.join(current + additions).rstrip() + '\n')
        missing = missing_wads(bsp)
        if missing:
            blocked.append((name, missing))
        else:
            names.append(name)
    cfg = CS / 'addons/amxmodx/configs/maps.ini'
    old = cfg.read_text(errors='replace') if cfg.exists() else ''
    comments = [line for line in old.splitlines() if line.lstrip().startswith(';')]
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text('\n'.join(comments + names) + '\n')
    (cfg.parent / 'maps_blocked.ini').write_text(''.join(f'{name} ; missing WAD: {", ".join(missing)}\n' for name, missing in blocked))

    overview_dir = CS / 'overviews'
    overview_dir.mkdir(exist_ok=True)
    for name in names:
        if name.startswith(('deathrun_', 'jail_', 'jb_')):
            target = overview_dir / f'{name}.txt'
            if not target.exists():
                text = overview_text(maps_dir / f'{name}.bsp')
                if text:
                    target.write_text(text)
            image = overview_dir / f'{name}.bmp'
            if not image.exists() and target.exists():
                image.write_bytes(fallback_overview_bmp())

    cycle = CS / 'mapcycle.txt'
    lines = cycle.read_text(errors='replace').splitlines() if cycle.exists() else []
    valid = {name.lower() for name in names}
    lines = [line for line in lines if not line.strip() or line.lstrip().startswith('//') or line.strip().lower() in valid]
    listed = {line.strip().lower() for line in lines if line.strip() and not line.lstrip().startswith('//')}
    for name in ('deathrun_temple', 'jail_buyukisyan_dark'):
        if name in names and name.lower() not in listed:
            lines.append(name)
    cycle.write_text('\n'.join(lines).rstrip() + '\n')


if __name__ == '__main__':
    main()
