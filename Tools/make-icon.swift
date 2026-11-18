// Genera Resources/AppIcon.icns.  Uso: swift Tools/make-icon.swift
// Concepto: squircle grafito; el notch cuelga del borde superior y debajo
// un anillo de cuota con degradado arcilla → ámbar que termina en un punto de luz.
import AppKit

let S: CGFloat = 1024

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func lerp(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
    let x = a.components!, y = b.components!
    return CGColor(srgbRed: x[0] + (y[0] - x[0]) * t, green: x[1] + (y[1] - x[1]) * t,
                   blue: x[2] + (y[2] - x[2]) * t, alpha: 1)
}

func render() -> CGImage {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // Rejilla de iconos de macOS: 824 pt de contenido centrado en 1024.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
    ctx.addPath(squircle); ctx.setFillColor(rgb(0x141416)); ctx.fillPath()
    ctx.restoreGState()

    // Un único anillo de cuota, plano, con remates redondos.
    let c = CGPoint(x: 512, y: 512), radius: CGFloat = 230, lw: CGFloat = 92
    ctx.setLineWidth(lw)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.09))
    ctx.addArc(center: c, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    let start = CGFloat.pi / 2
    ctx.setStrokeColor(rgb(0xE8835F))
    ctx.addArc(center: c, radius: radius, startAngle: start, endAngle: start - 0.72 * 2 * .pi, clockwise: true)
    ctx.strokePath()

    return ctx.makeImage()!
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appending(path: "build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let master = render()
func write(_ px: Int, _ name: String) {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(master, in: CGRect(x: 0, y: 0, width: px, height: px))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: iconset.appending(path: name))
}
for s in [16, 32, 128, 256, 512] {
    write(s, "icon_\(s)x\(s).png")
    write(s * 2, "icon_\(s)x\(s)@2x.png")
}
write(1024, "../AppIcon-1024.png")
print("iconset OK")
