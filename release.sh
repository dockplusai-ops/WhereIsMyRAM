#!/bin/bash
# Assina (Developer ID + hardened runtime), empacota em DMG, notariza e staple.
# Pré-requisitos (ver README): certificado "Developer ID Application" instalado
# e perfil de notarização salvo (notarytool store-credentials "$PROFILE").
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="WhereIsMyRAM"
DISPLAY_NAME="WhereIsMyRAM?"
APP="dist/$APP_NAME.app"
DMG="dist/$APP_NAME.dmg"
PROFILE="${NOTARY_PROFILE:-WIMR}"

# 1. Compila e monta o .app (assinatura ad-hoc inicial).
./build_app.sh

# 2. Reassina com Developer ID + Hardened Runtime + timestamp seguro.
IDENTITY=$(security find-identity -v -p codesigning \
  | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')
if [ -z "$IDENTITY" ]; then
    echo "✗ Nenhum certificado 'Developer ID Application' encontrado no Keychain."
    echo "  Crie em Xcode › Settings › Accounts › Manage Certificates › + Developer ID Application."
    exit 1
fi
echo "▸ Assinando com: $IDENTITY"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

# 3. Empacota num DMG estilizado (janela + seta para /Applications).
./make_dmg.sh

# 4. Notariza (aguarda o resultado da Apple).
echo "▸ Notarizando (pode levar 1–5 min)…"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

# 5. Anexa o ticket (staple) ao DMG e ao app.
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"

echo ""
echo "✓ Pronto para distribuir: $DMG"
echo "  Assinado com Developer ID, notarizado e stapled."
echo "  Verifique: spctl -a -vvv -t install \"$APP\""
