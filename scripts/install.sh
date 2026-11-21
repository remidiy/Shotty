#!/usr/bin/env bash
# Copies dist/Shotty.app to /Applications and restarts it. Running from one fixed
# location (with a stable signature) keeps macOS permissions attached.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d dist/Shotty.app ] || scripts/build-app.sh
pkill -x Shotty 2>/dev/null || true
sleep 0.5
rm -rf /Applications/Shotty.app
ditto dist/Shotty.app /Applications/Shotty.app
open /Applications/Shotty.app
echo "Installed /Applications/Shotty.app"
