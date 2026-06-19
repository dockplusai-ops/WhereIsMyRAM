#!/bin/bash
# Monta um DMG "bonito": janela com ícone do app à esquerda, atalho para
# /Applications à direita e seta de fundo. Resultado: dist/WhereIsMyRAM.dmg
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="WhereIsMyRAM"
VOL="WhereIsMyRAM"            # nome do volume (sem "?" p/ evitar dor de cabeça no path)
APP="dist/$APP_NAME.app"
DMG="dist/$APP_NAME.dmg"
RW="dist/.rw.dmg"

[ -d "$APP" ] || { echo "✗ $APP não existe. Rode ./build_app.sh antes."; exit 1; }

# Fundo (gera se faltar).
[ -f Resources/dmg_bg.png ] || swift make_dmg_bg.swift Resources/dmg_bg.png

echo "▸ Preparando conteúdo…"
STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
mkdir "$STAGING/.background"
cp Resources/dmg_bg.png "$STAGING/.background/bg.png"

echo "▸ Criando DMG temporário…"
rm -f "$RW" "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGING" -fs HFS+ \
    -format UDRW -ov "$RW" >/dev/null

DEV=$(hdiutil attach "$RW" -readwrite -noverify -noautoopen | egrep '^/dev/' | head -1 | awk '{print $1}')
MOUNT="/Volumes/$VOL"

echo "▸ Ajustando layout da janela (Finder)…"
osascript <<EOF
tell application "Finder"
    tell disk "$VOL"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {300, 150, 900, 550}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 100
        set background picture of opts to file ".background:bg.png"
        set position of item "$APP_NAME.app" of container window to {150, 195}
        set position of item "Applications" of container window to {450, 195}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

sync
hdiutil detach "$DEV" >/dev/null

echo "▸ Comprimindo…"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW"
rm -rf "$STAGING"

echo "✓ DMG montado: $DMG"
