// Gera o ícone do app WhereIsMyRAM?: chip de memória + badge "?".
// Uso: swift make_icon.swift <saida.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let size = 1024.0

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Fundo arredondado com gradiente (roxo → índigo, a cor da RAM no app).
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let bg = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.58, green: 0.38, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.30, green: 0.16, blue: 0.66, alpha: 1)
])!
gradient.draw(in: bg, angle: -90)

// Símbolo do chip de memória, branco, levemente deslocado para cima/esquerda.
func tinted(_ name: String, pointSize: Double, color: NSColor) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { return nil }
    let out = NSImage(size: base.size)
    out.lockFocus()
    color.set()
    let r = NSRect(origin: .zero, size: base.size)
    base.draw(in: r)
    r.fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

if let chip = tinted("memorychip", pointSize: size * 0.46, color: .white) {
    let s = chip.size
    let drawRect = NSRect(x: (size - s.width) / 2 - size * 0.04,
                          y: (size - s.height) / 2 + size * 0.05,
                          width: s.width, height: s.height)
    chip.draw(in: drawRect)
}

// Badge "?" no canto inferior direito.
let badgeR = size * 0.20
let badgeCenter = NSPoint(x: size * 0.70, y: size * 0.30)
let badgeRect = NSRect(x: badgeCenter.x - badgeR, y: badgeCenter.y - badgeR,
                       width: badgeR * 2, height: badgeR * 2)
NSColor.white.setFill()
NSBezierPath(ovalIn: badgeRect).fill()

let qFont = NSFont.systemFont(ofSize: badgeR * 1.7, weight: .bold)
let q = NSAttributedString(string: "?", attributes: [
    .font: qFont,
    .foregroundColor: NSColor(calibratedRed: 0.42, green: 0.22, blue: 0.85, alpha: 1)
])
let qSize = q.size()
q.draw(at: NSPoint(x: badgeCenter.x - qSize.width / 2,
                   y: badgeCenter.y - qSize.height / 2))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Falha ao gerar PNG\n".data(using: .utf8)!)
    exit(1)
}

try! png.write(to: URL(fileURLWithPath: outPath))
print("✓ \(outPath)")
