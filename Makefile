APP = WhereIsMyRAM
DIST = dist/$(APP).app

.PHONY: all build run icon app install uninstall release clean

all: app

## build: compila em debug
build:
	swift build

## run: compila e roda o binário direto (sem bundle/login item)
run: build
	-pkill -f "debug/$(APP)" 2>/dev/null || true
	.build/debug/$(APP)

## icon: gera Resources/AppIcon.icns
icon:
	./make_icon.sh

## app: compila release e monta dist/StatusBar.app
app:
	./build_app.sh

## install: empacota, copia pra /Applications e reabre
install: app
	-pkill -f "$(APP).app" 2>/dev/null || true
	rm -rf /Applications/$(APP).app
	cp -R $(DIST) /Applications/
	open /Applications/$(APP).app
	@echo "✓ Instalado e aberto."

## release: assina (Developer ID), empacota DMG, notariza e staple
release:
	./release.sh

## uninstall: remove de /Applications e mata o processo
uninstall:
	-pkill -f "$(APP).app" 2>/dev/null || true
	rm -rf /Applications/$(APP).app
	@echo "✓ Removido."

## clean: limpa artefatos de build
clean:
	swift package clean
	rm -rf dist
	@echo "✓ Limpo."
