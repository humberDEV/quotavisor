#!/bin/bash
# Compila y empaqueta "Quotavisor.app" en ./build
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --arch arm64
APP="build/Quotavisor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/Quotavisor "$APP/Contents/MacOS/Quotavisor"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Con SIGN_ID (p. ej. "Developer ID Application: Nombre (TEAMID)") firma para distribuir;
# sin él, firma ad hoc (solo vale en este Mac).
if [[ -n "${SIGN_ID:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
else
  codesign --force --sign - "$APP" >/dev/null
fi
echo "OK → $APP"
