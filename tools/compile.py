#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess
import re
from common import ROOT, runtime_command
from patch_admincmd import patched_source, patched_menu, patched_votes

compiler_dir = ROOT / 'server/cstrike/addons/amxmodx/scripting'
compiler = compiler_dir / 'amxxpc'
compiler.chmod(0o755)
dest = ROOT / 'server/cstrike/addons/amxmodx/plugins'
(compiler_dir / 'include/mode_profile.inc').write_bytes((ROOT / 'plugins/mode_profile.inc').read_bytes())
(compiler_dir / 'admincmd.sma').write_text(patched_source())
build = ROOT / 'downloads/build'
build.mkdir(exist_ok=True)
def compile_one(name):
    output = build / (Path(name).stem + '.amxx')
    result = subprocess.run(runtime_command(compiler, name, '-iinclude', '-o' + str(output)), cwd=compiler_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end='')
    # amxxpc can return exit code 0 even for fatal Pawn compilation errors.
    if result.returncode or re.search(r'(?i)(?:fatal )?error [0-9]+|compilation aborted', result.stdout) or not output.exists():
        raise RuntimeError('Derleme basarisiz: ' + name)
    shutil.copy2(output, dest / output.name)
compile_one('admincmd.sma')
for name, patch in [('plmenu.sma', patched_menu), ('adminvote.sma', patched_votes)]:
    (compiler_dir / name).write_text(patch())
    compile_one(name)
for source in sorted((ROOT / 'plugins').glob('*.sma')):
    shutil.copy2(source, compiler_dir / source.name)
    compile_one(source.name)
