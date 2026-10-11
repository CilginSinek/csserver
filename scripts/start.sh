#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/update_maps.py
exec python3 tools/server.py start
