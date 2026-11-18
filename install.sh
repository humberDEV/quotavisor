#!/bin/bash
# Compila, instala en /Applications y relanza (activa el inicio con el Mac la 1ª vez).
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
pkill -x Quotavisor 2>/dev/null || true
rm -rf "/Applications/Quotavisor.app"
cp -R "build/Quotavisor.app" /Applications/
open "/Applications/Quotavisor.app"
echo "Instalada en /Applications"
