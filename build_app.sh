#!/bin/bash
# Compila em release e monta o bundle WhereIsMyRAM.app.
set -euo pipefail

APP_NAME="WhereIsMyRAM"
DISPLAY_NAME="WhereIsMyRAM?"
BUNDLE_ID="com.gustavokarsten.whereismyram"
VERSION="1.1"

cd "$(dirname "$0")"

echo "▸ Compilando (release)…"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
APP_DIR="dist/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "▸ Montando bundle…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"

ICON_LINE=""
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$RES_DIR/AppIcon.icns"
    ICON_LINE="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
$ICON_LINE
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Gustavo Karsten</string>
</dict>
</plist>
PLIST

echo "▸ Assinando (ad-hoc)…"
codesign --force --deep --sign - "$APP_DIR"

echo "✓ Pronto: $APP_DIR"
echo "  Instalar:  cp -R \"$APP_DIR\" /Applications/"
echo "  Abrir:     open \"$APP_DIR\""
