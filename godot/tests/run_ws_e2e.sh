#!/usr/bin/env bash
# E2E multiplayer: avvia il relay Node su :8123, esegue il test Godot (tavolo + 2
# telefoni via WebSocket reale), poi spegne il server. Uso: bash tests/run_ws_e2e.sh
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"          # .../godot
ROOT="$(cd "$HERE/.." && pwd)"                      # repo root
PORT=8123

PORT=$PORT node "$ROOT/server/server.js" &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT
sleep 0.6

( cd "$HERE" && godot --headless --quit-after 6000 tests/test_ws_e2e.tscn ) 2>&1 \
  | grep -iE "ok:|fail|risult|conclusa|vincitore" | grep -viE "leaked|still in use"
