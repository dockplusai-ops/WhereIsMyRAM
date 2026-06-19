#!/bin/bash
# Gera Resources/AppIcon.icns a partir de um SF Symbol.
set -euo pipefail
cd "$(dirname "$0")"

PNG="$(mktemp -d)/icon_1024.png"
ICONSET="$(mktemp -d)/AppIcon.iconset"

echo "▸ Renderizando símbolo…"
swift make_icon.swift "$PNG"

echo "▸ Gerando tamanhos…"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size       "$PNG" --out "$ICONSET/icon_${size}x${size}.png"      >/dev/null
    sips -z $((size*2)) $((size*2)) "$PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "✓ Resources/AppIcon.icns"
