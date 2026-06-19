import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?

    private let model = PanelModel()
    private var hostingView: NSHostingView<PanelView>!
    private var panelWindow: NSPanel!
    private var clickMonitor: Any?

    private let interval = 2.0
    private var previousNet: (received: UInt64, sent: UInt64)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent",
                                   accessibilityDescription: "Sistema")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.target = self
            button.action = #selector(togglePanel)
        }

        model.onToggleLogin = { [weak self] _ in self?.toggleLogin() }
        model.onQuit = { NSApplication.shared.terminate(nil) }
        model.onKill = { [weak self] proc in self?.confirmKill(proc) }

        // Conteúdo SwiftUI com Liquid Glass real, em janela transparente
        // (NSHostingView é transparente, deixando o .glassEffect compor o fundo).
        hostingView = NSHostingView(rootView: PanelView(model: model))
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize

        panelWindow = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panelWindow.contentView = hostingView
        panelWindow.isOpaque = false
        panelWindow.backgroundColor = .clear
        panelWindow.hasShadow = false // a sombra/realce vem do próprio vidro
        panelWindow.level = .statusBar
        panelWindow.hidesOnDeactivate = false
        panelWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        _ = Metrics.cpuUsage() // baseline
        previousNet = Metrics.networkBytes() // baseline
        update()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    /// Atualiza o texto/cor da barra e o modelo do painel.
    private func update() {
        let cpu = Metrics.cpuUsage()
        let mem = Metrics.memory()
        let disk = Metrics.disk()

        model.cpu = cpu
        model.memUsed = mem.used
        model.memTotal = mem.total
        model.diskFree = disk.free
        model.diskTotal = disk.total

        // Rede: taxa = delta de bytes / intervalo (clampando wrap dos contadores).
        let net = Metrics.networkBytes()
        if let prev = previousNet {
            let dIn = net.received >= prev.received ? net.received - prev.received : 0
            let dOut = net.sent >= prev.sent ? net.sent - prev.sent : 0
            model.downRate = Double(dIn) / interval
            model.upRate = Double(dOut) / interval
        }
        previousNet = net

        // Histórico para as sparklines (~últimos 60s @ 2s = 30 amostras).
        let maxSamples = 30
        model.cpuHistory.append(cpu)
        model.memHistory.append(model.memFraction * 100)
        model.downHistory.append(model.downRate)
        model.upHistory.append(model.upRate)
        if model.cpuHistory.count > maxSamples { model.cpuHistory.removeFirst() }
        if model.memHistory.count > maxSamples { model.memHistory.removeFirst() }
        if model.downHistory.count > maxSamples { model.downHistory.removeFirst() }
        if model.upHistory.count > maxSamples { model.upHistory.removeFirst() }

        let worst = max(cpu / 100, model.memFraction, model.diskFraction)
        let color = alertColor(for: worst)

        let text = String(
            format: " CPU %.0f%% · RAM %.0f%% · SSD %@",
            cpu, model.memFraction * 100, Metrics.formatGB(disk.free)
        )
        if let button = statusItem.button {
            button.attributedTitle = NSAttributedString(string: text, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: color
            ])
            button.contentTintColor = (color == .labelColor) ? nil : color
        }
    }

    private func alertColor(for fraction: Double) -> NSColor {
        switch fraction {
        case 0.95...: return .systemRed
        case 0.85...: return .systemOrange
        default: return .labelColor
        }
    }

    // MARK: - Painel

    @objc private func togglePanel() {
        if panelWindow.isVisible { closePanel() } else { openPanel() }
    }

    private func openPanel() {
        // Top processos (caro) só ao abrir; demais métricas já estão no modelo.
        refreshTopMemory()
        model.loginEnabled = (SMAppService.mainApp.status == .enabled)

        positionPanel()
        panelWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        panelWindow.orderOut(nil)
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func refreshTopMemory() {
        let total = Metrics.memory().total
        model.top = Metrics.topMemoryProcesses(count: 20).map {
            let pct = total > 0 ? Double($0.bytes) / Double(total) * 100 : 0
            let icon = $0.path.isEmpty ? nil : NSWorkspace.shared.icon(forFile: $0.path)
            return ProcInfo(id: $0.name, name: $0.name, bytes: $0.bytes,
                            percent: pct, pids: $0.pids, icon: icon)
        }
    }

    /// Confirma e encerra (SIGTERM) os processos do app selecionado.
    private func confirmKill(_ proc: ProcInfo) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: L.t("killTitle"), proc.name)
        alert.informativeText = L.t("killBody")
        alert.addButton(withTitle: L.t("kill"))
        alert.addButton(withTitle: L.t("cancel"))
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            Metrics.terminate(pids: proc.pids)
            // Dá um tempo pro processo sair e recarrega a lista.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refreshTopMemory()
            }
        }
    }

    /// Posiciona a janela logo abaixo do ícone na barra de menus.
    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let size = hostingView.fittingSize
        panelWindow.setContentSize(size)

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        var x = screenRect.midX - size.width / 2
        let y = screenRect.minY - size.height + 1 // grudado logo abaixo do menu bar
        if let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame {
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        }
        panelWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Abrir no login

    private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Falha ao alternar login item: \(error)")
        }
        model.loginEnabled = (SMAppService.mainApp.status == .enabled)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
