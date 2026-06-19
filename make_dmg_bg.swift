// Gera o fundo do DMG (600x400) com uma seta do app para a pasta Applications.
// Uso: swift make_dmg_bg.swift <saida.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_bg.png"
let w = 600.0, h = 400.0

let image = NSImage(size: NSSize(width: w, height: h))
image.lockFocus()

// Fundo lavanda suave.
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.97, green: 0.96, blue: 0.99, alpha: 1),
    NSColor(calibratedRed: 0.90, green: 0.88, blue: 0.97, alpha: 1)
])!
gradient.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)

// Seta roxa apontando do app (esquerda) para Applications (direita).
let purple = NSColor(calibratedRed: 0.42, green: 0.22, blue: 0.85, alpha: 0.85)
purple.set()

let y = 200.0
let line = NSBezierPath()
line.lineWidth = 9
line.lineCapStyle = .round
line.move(to: NSPoint(x: 255, y: y))
line.line(to: NSPoint(x: 338, y: y))
line.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 350, y: y))
head.line(to: NSPoint(x: 326, y: y + 16))
head.line(to: NSPoint(x: 326, y: y - 16))
head.close()
head.fill()

// Texto de instrução no topo.
let text = NSAttributedString(string: "Arraste o app para a pasta Applications", attributes: [
    .font: NSFont.systemFont(ofSize: 17, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.35, alpha: 1)
])
let ts = text.size()
text.draw(at: NSPoint(x: (w - ts.width) / 2, y: 320))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Falha ao gerar PNG\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("✓ \(outPath)")
