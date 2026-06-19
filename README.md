# WhereIsMyRAM?

App de barra de menus para macOS (Tahoe / macOS 26) que mostra **CPU, memória e disco**
em tempo real, com um painel **Liquid Glass** detalhado e o ranking de processos que
mais consomem RAM.

- Resumo na barra: `CPU 7% · RAM 74% · SSD 386GB` (colorido por severidade)
- Painel de vidro com barras coloridas por métrica e **Top memória** (5 apps)
- **Abrir no login** (via `SMAppService`) e **Sair**
- Idioma automático: **PT / EN / ES** (cai para inglês)

## Requisitos

- macOS 26 (Tahoe) — usa a API `.glassEffect` / Liquid Glass
- Xcode 26+ (SDK do macOS 26) com a licença aceita (`sudo xcodebuild -license accept`)

## Estrutura

```
.
├── Package.swift              # Swift Package executável (macOS 26, Swift 5 mode)
├── Sources/WhereIsMyRAM/
│   ├── main.swift             # AppDelegate, NSStatusItem, NSPanel flutuante
│   ├── PanelView.swift        # painel SwiftUI Liquid Glass + PanelModel
│   ├── Metrics.swift          # CPU/RAM/disco (Mach) + top processos (ps)
│   └── Localization.swift     # strings PT/EN/ES
├── make_icon.swift / .sh      # gera Resources/AppIcon.icns
├── make_dmg_bg.swift          # gera o fundo do DMG
├── make_dmg.sh                # monta o DMG estilizado (seta p/ Applications)
├── build_app.sh               # compila release + monta o .app (assinatura ad-hoc)
├── release.sh                 # assina (Developer ID) + DMG + notariza + staple
└── Makefile                   # atalhos
```

## Desenvolvimento

```bash
make run        # compila e roda o binário direto (iteração rápida)
make install    # empacota o .app e instala em /Applications (ad-hoc) + abre
make icon       # regenera o ícone do app
make clean      # limpa build e dist
```

> `make run`/`make install` usam assinatura **ad-hoc** — funcionam só na sua máquina.
> Para distribuir, use `make release` (abaixo).

## Publicação (Developer ID, distribuição direta)

Este app roda `ps` (para o "Top memória"), o que é **bloqueado pelo sandbox da Mac App
Store**. Por isso usamos **Developer ID + notarização** e distribuímos um `.dmg`.

### Pré-requisitos (uma vez)

1. **Certificado Developer ID Application**
   Xcode › Settings › Accounts › *Manage Certificates…* › `+` › **Developer ID Application**.
   Confirme: `security find-identity -v -p codesigning`

2. **Credenciais de notarização** (senha específica de app em appleid.apple.com):
   ```bash
   xcrun notarytool store-credentials "WIMR" \
     --apple-id "SEU_APPLE_ID" --team-id "SEU_TEAM_ID" \
     --password "SENHA_ESPECIFICA_DE_APP"
   ```
   O perfil padrão usado pelo script é `WIMR` (ou defina `NOTARY_PROFILE`).

### Gerar o release

```bash
make release
```

Faz tudo: compila → assina com Developer ID + Hardened Runtime → monta o DMG estilizado →
**notariza** (aguarda a Apple) → faz o *staple*. Saída: **`dist/WhereIsMyRAM.dmg`**.

### Verificar

```bash
spctl -a -vvv -t install "dist/WhereIsMyRAM.app"   # → accepted / Notarized Developer ID
xcrun stapler validate "dist/WhereIsMyRAM.dmg"     # → worked
```

### Distribuir

Suba `dist/WhereIsMyRAM.dmg` no seu site ou em **GitHub Releases**. O usuário abre o DMG,
arrasta o app para **Applications** e roda sem aviso do Gatekeeper.

## Lançar nova versão

1. Bump da versão em `build_app.sh` (`VERSION="1.1"`).
2. `make release`.
3. Publicar o novo `.dmg`.
