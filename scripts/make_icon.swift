import AppKit
// Renders the Mémoire app icon: blue gradient, white sound-wave "M".
let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let colors = [NSColor(srgbRed: 0.04, green: 0.45, blue: 1, alpha: 1).cgColor, NSColor(srgbRed: 0.42, green: 0.74, blue: 1, alpha: 1).cgColor] as CFArray
let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
// concentric rings
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
for i in 1...4 { ctx.setLineWidth(6); let r = Double(i) * 150; ctx.strokeEllipse(in: CGRect(x: size/2 - r, y: size/2 - r, width: r*2, height: r*2)) }
// waveform bars forming an M silhouette
let heights: [Double] = [0.28, 0.5, 0.72, 0.5, 0.3, 0.5, 0.72, 0.5, 0.28]
let barW = 52.0, gap = 30.0
let total = Double(heights.count) * barW + Double(heights.count - 1) * gap
var x = (size - total) / 2
ctx.setFillColor(NSColor.white.cgColor)
for h in heights {
    let bh = h * size * 0.62
    let rect = CGRect(x: x, y: (size - bh) / 2, width: barW, height: bh)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: barW/2, cornerHeight: barW/2, transform: nil)); ctx.fillPath()
    x += barW + gap
}
// orange dot
ctx.setFillColor(NSColor(srgbRed: 1, green: 0.54, blue: 0.24, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: 760, y: 770, width: 64, height: 64))
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
