import SwiftUI
import AppKit

/// Um processo no ranking de memória.
struct ProcInfo: Identifiable {
    let id: String
    let name: String
    let bytes: UInt64
    let percent: Double   // % da memória física total
    let pids: [Int32]
    let icon: NSImage?
}

/// Estado observável do painel; o AppDelegate alimenta, o SwiftUI reage.
final class PanelModel: ObservableObject {
    @Published var cpu: Double = 0
    @Published var memUsed: UInt64 = 0
    @Published var memTotal: UInt64 = 0
    @Published var diskFree: UInt64 = 0
    @Published var diskTotal: UInt64 = 0
    @Published var top: [ProcInfo] = []
    @Published var loginEnabled: Bool = false
    @Published var cpuHistory: [Double] = []   // % (0–100), ~últimos 60s
    @Published var memHistory: [Double] = []
    @Published var downRate: Double = 0        // bytes/s
    @Published var upRate: Double = 0
    @Published var downHistory: [Double] = []  // bytes/s, ~últimos 60s
    @Published var upHistory: [Double] = []

    var onToggleLogin: ((Bool) -> Void)?
    var onQuit: (() -> Void)?
    var onKill: ((ProcInfo) -> Void)?

    var memFraction: Double { memTotal > 0 ? Double(memUsed) / Double(memTotal) : 0 }
    var diskFraction: Double {
        let used = diskTotal > diskFree ? diskTotal - diskFree : 0
        return diskTotal > 0 ? Double(used) / Double(diskTotal) : 0
    }
}

/// Painel Liquid Glass (macOS 26 Tahoe).
struct PanelView: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                MetricRowView(icon: "cpu", title: L.t("cpu"),
                              fraction: model.cpu / 100,
                              value: String(format: "%.0f%%", model.cpu),
                              baseColor: .blue,
                              history: model.cpuHistory)

                MetricRowView(icon: "memorychip", title: L.t("memory"),
                              fraction: model.memFraction,
                              value: String(format: "%.0f%%  ·  %@ / %@",
                                            model.memFraction * 100,
                                            Metrics.formatGB(model.memUsed),
                                            Metrics.formatGB(model.memTotal)),
                              baseColor: .purple,
                              history: model.memHistory)

                MetricRowView(icon: "internaldrive", title: L.t("disk"),
                              fraction: model.diskFraction,
                              value: "\(Metrics.formatGB(model.diskFree)) \(L.t("free")) / \(Metrics.formatGB(model.diskTotal))",
                              baseColor: .teal,
                              history: nil)

                NetworkRowView(down: model.downRate, up: model.upRate,
                               downHistory: model.downHistory, upHistory: model.upHistory)

                Divider().opacity(0.5)

                Text(L.t("topMemory"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 9) {
                        ForEach(model.top) { proc in
                            ProcessRowView(proc: proc) { model.onKill?(proc) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 6) // espaço para a barra de rolagem
                }
                .frame(height: 150)
                .scrollIndicators(.automatic)

                Divider().opacity(0.5)

                HStack {
                    Toggle(L.t("openAtLogin"), isOn: Binding(
                        get: { model.loginEnabled },
                        set: { model.onToggleLogin?($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    Spacer()
                    Button(L.t("quit")) { model.onQuit?() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                }
                .font(.system(size: 12))
            }
            .padding(18)
            .frame(width: 300, alignment: .leading)
            .glassEffect(.regular.tint(.blue.opacity(0.08)), in: .rect(cornerRadius: 26))
        }
        // Sem respiro no topo: gruda no menu bar. Laterais/baixo p/ a sombra do vidro.
        .padding([.horizontal, .bottom], 10)
    }
}

/// Linha do Top memória: nome, consumo e botão de encerrar (no hover).
struct ProcessRowView: View {
    let proc: ProcInfo
    let onKill: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon = proc.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Circle().fill(.tint).frame(width: 6, height: 6)
            }
            Text(proc.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text("\(String(format: "%.0f", proc.percent))%")
                .foregroundStyle(.primary)
            Text(Metrics.formatGB(proc.bytes))
                .foregroundStyle(.secondary)
                .frame(minWidth: 38, alignment: .trailing)
            Button(action: onKill) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(hovering ? Color.red : Color.secondary.opacity(0.5))
            .help(L.t("kill"))
        }
        .font(.system(size: 11).monospacedDigit())
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

/// Linha de métrica: ícone, título, barra colorida e valor.
struct MetricRowView: View {
    let icon: String
    let title: String
    let fraction: Double
    let value: String
    let baseColor: Color
    var history: [Double]? = nil

    /// Cor de severidade sobrepõe a cor base (>85% laranja, >95% vermelho).
    private var severity: Color? {
        switch fraction {
        case 0.95...: return .red
        case 0.85...: return .orange
        default: return nil
        }
    }
    private var barColor: Color { severity ?? baseColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(barColor)
                    .frame(width: 18)
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(value)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(severity ?? .secondary)
            }
            if let history {
                Sparkline(values: history, color: barColor)
            } else {
                CapsuleBar(fraction: fraction, color: barColor)
            }
        }
    }
}

/// Linha de rede: download e upload com gráfico duplo sobreposto.
struct NetworkRowView: View {
    let down: Double
    let up: Double
    let downHistory: [Double]
    let upHistory: [Double]

    private let downColor = Color.green
    private let upColor = Color.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(downColor)
                    .frame(width: 18)
                Text(L.t("network")).font(.system(size: 13, weight: .medium))
                Spacer()
                HStack(spacing: 10) {
                    Label(Metrics.formatRate(down), systemImage: "arrow.down")
                        .foregroundStyle(downColor)
                    Label(Metrics.formatRate(up), systemImage: "arrow.up")
                        .foregroundStyle(upColor)
                }
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11).monospacedDigit())
            }
            DualSparkline(down: downHistory, up: upHistory,
                          downColor: downColor, upColor: upColor)
        }
    }
}

/// Dois gráficos sobrepostos (download preenchido + upload em linha), mesma escala.
struct DualSparkline: View {
    let down: [Double]
    let up: [Double]
    let downColor: Color
    let upColor: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let maxV = max(down.max() ?? 0, up.max() ?? 0, 1)
            ZStack {
                if down.count >= 2 {
                    Path { p in
                        let pts = points(down, maxV: maxV, w: w, h: h)
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [downColor.opacity(0.30), downColor.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                    line(down, maxV: maxV, w: w, h: h).stroke(
                        downColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
                if up.count >= 2 {
                    line(up, maxV: maxV, w: w, h: h).stroke(
                        upColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: 34)
    }

    private func points(_ values: [Double], maxV: Double, w: CGFloat, h: CGFloat) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let stepX = w / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * stepX, y: h - CGFloat(min(v / maxV, 1)) * h)
        }
    }

    private func line(_ values: [Double], maxV: Double, w: CGFloat, h: CGFloat) -> Path {
        Path { p in
            let pts = points(values, maxV: maxV, w: w, h: h)
            guard let first = pts.first else { return }
            p.move(to: first)
            pts.dropFirst().forEach { p.addLine(to: $0) }
        }
    }
}

/// Mini-gráfico de histórico (linha + área preenchida), escala 0–100.
struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let pts = points(width: w, height: h)
            ZStack {
                if pts.count >= 2 {
                    // Área preenchida sob a linha.
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0.03)],
                                         startPoint: .top, endPoint: .bottom))
                    // Linha.
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: 28)
    }

    private func points(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let stepX = width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            let clamped = min(max(v, 0), 100)
            return CGPoint(x: CGFloat(i) * stepX,
                           y: height - CGFloat(clamped) / 100 * height)
        }
    }
}

/// Barra de progresso fina e arredondada (cápsula) com preenchimento colorido.
struct CapsuleBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(color.gradient)
                    .frame(width: max(4, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}
