#!/bin/bash
# Publica uma versão completa: build assinado/notarizado → commit → push →
# release no GitHub com o DMG anexado. A versão vem de build_app.sh (VERSION=).
# Mensagem opcional: MSG="texto" make publish
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(grep -E '^VERSION=' build_app.sh | head -1 | sed -E 's/VERSION="(.*)"/\1/')
TAG="v$VERSION"
DMG="dist/WhereIsMyRAM.dmg"
MSG="${MSG:-Release $TAG}"

echo "▸ Publicando $TAG"

# 1. Build assinado + notarizado + DMG estilizado.
./release.sh

# 2. Commit (se houver mudanças) e push.
git add -A
if ! git diff --cached --quiet; then
    git commit -m "$MSG"
fi
git push

# 3. Release no GitHub (cria, ou atualiza o asset se a tag já existir).
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "▸ Release $TAG já existe — atualizando o DMG…"
    gh release upload "$TAG" "$DMG" --clobber
else
    gh release create "$TAG" "$DMG" --title "WhereIsMyRAM? $VERSION" --notes "$MSG"
fi

echo "✓ Publicado: $(gh release view "$TAG" --json url --jq .url)"
echo "  Download:  https://github.com/dockplusai-ops/WhereIsMyRAM/releases/latest/download/WhereIsMyRAM.dmg"
