#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $(id -u) -eq 0 ]]; then
    server_user=$(stat -c '%U' "$PWD")
    echo "Bu sunucu root ile kurulmamalı. Dosya sahibi $server_user; onunla çalıştırın:"
    echo "runuser -u $server_user -- $PWD/scripts/install.sh"
    exit 2
fi
if [[ ! -e .env ]]; then
    install -m 600 .env.example .env
fi
if [[ ! -e /lib/ld-linux.so.2 ]]; then
    echo '32 bit kutuphaneler gerekli: sudo apt-get install libc6-i386 lib32stdc++6 lib32gcc-s1'
    exit 1
fi
python3 tools/server.py status
if [[ -e run/state.json ]]; then
    echo 'Kurulum/guncelleme oncesinde scripts/stop.sh calistirin.'
    exit 1
fi
# Validate and provision the founder before spending time downloading Steam files.
python3 tools/account_admin.py bootstrap
python3 tools/install.py --packages --steam --overlay --map
python3 tools/compile.py
echo 'Kurulum tamamlandi. scripts/start.sh ile baslatin.'
