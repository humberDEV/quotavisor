#!/bin/bash
# Crea build/Quotavisor.dmg con la app y un acceso a /Applications.
# Firma opcional con Developer ID para distribuir sin avisos de Gatekeeper:
#   SIGN_ID="Developer ID Application: Nombre (TEAMID)" NOTARY_PROFILE=quotavisor ./make-dmg.sh
# NOTARY_PROFILE se crea una vez con: xcrun notarytool store-credentials quotavisor
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
STAGE=build/dmg
rm -rf "$STAGE" build/Quotavisor.dmg
mkdir -p "$STAGE"
cp -R "build/Quotavisor.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Quotavisor" -srcfolder "$STAGE" -ov -format UDZO build/Quotavisor.dmg >/dev/null
rm -rf "$STAGE"
if [[ -n "${SIGN_ID:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_ID" build/Quotavisor.dmg
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit build/Quotavisor.dmg --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple build/Quotavisor.dmg
    spctl -a -t open --context context:primary-signature -v build/Quotavisor.dmg
  fi
fi
echo "OK → build/Quotavisor.dmg"
