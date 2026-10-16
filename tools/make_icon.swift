import AppKit
let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
func c(_ h: UInt32, _ a: CGFloat = 1) -> NSColor { NSColor(red: CGFloat((h>>16)&255)/255, green: CGFloat((h>>8)&255)/255, blue: CGFloat(h&255)/255, alpha: a) }
NSGradient(colors: [c(0x1A1240), c(0x0B0E26)])!.draw(in: NSRect(x: 0, y: 0, width: S, height: S), angle: -70)
// 2x2 board
let cell: CGFloat = 340, gap: CGFloat = 36, x0: CGFloat = (S - 2*cell - gap) / 2, y0 = x0
for r in 0..<2 { for col in 0..<2 {
    let rect = NSRect(x: x0 + CGFloat(col)*(cell+gap), y: y0 + CGFloat(r)*(cell+gap), width: cell, height: cell)
    c(0xFFFFFF, 0.10).setFill(); NSBezierPath(roundedRect: rect, xRadius: 70, yRadius: 70).fill()
    let sun = (r + col) % 2 == 1
    let m = rect.insetBy(dx: 62, dy: 62)
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = sun ? c(0xFFB333, 0.9) : c(0x6B9EFF, 0.8); sh.shadowBlurRadius = 36; sh.shadowOffset = .zero; sh.set()
    if sun {
        NSGradient(colors: [c(0xFFE14D), c(0xFF9F1A)])!.draw(in: NSBezierPath(ovalIn: m), relativeCenterPosition: .zero)
    } else {
        let p = NSBezierPath(ovalIn: m)
        let cut = NSBezierPath(ovalIn: m.offsetBy(dx: m.width*0.28, dy: m.height*0.10).insetBy(dx: m.width*0.04, dy: m.height*0.04))
        p.append(cut); p.windingRule = .evenOdd
        c(0x6B9EFF).setFill(); p.fill()
    }
    NSGraphicsContext.restoreGraphicsState()
}}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
