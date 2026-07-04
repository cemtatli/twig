import AppKit

let outPath = CommandLine.arguments[1]
let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

// Background tile — brand orange with a subtle vertical gradient.
let tileRect = NSRect(x: side*0.07, y: side*0.07, width: side*0.86, height: side*0.86)
let radius = side * 0.22
let tile = NSBezierPath(roundedRect: tileRect, xRadius: radius, yRadius: radius)
let grad = NSGradient(starting: NSColor(red: 1.0, green: 0.416, blue: 0.102, alpha: 1),
                      ending:   NSColor(red: 0.859, green: 0.302, blue: 0.051, alpha: 1))!
grad.draw(in: tile, angle: -90)

// White twig: diagonal stem + two round-tipped offshoots (mirrors TwigMark).
NSColor.white.setStroke()
NSColor.white.setFill()
let w = side * 0.13 * 0.86            // stroke weight, scaled to tile
func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    // TwigMark unit coords (y-down) -> icon coords (y-up), inset to the tile.
    NSPoint(x: side * (0.07 + 0.86 * x), y: side * (0.07 + 0.86 * (1 - y)))
}
func stem(_ t: CGFloat) -> NSPoint { pt(0.28 + 0.44 * t, 0.90 - 0.80 * t) }
let path = NSBezierPath()
path.lineWidth = w
path.lineCapStyle = .round
path.move(to: pt(0.28, 0.90)); path.line(to: pt(0.72, 0.10))
path.move(to: stem(0.42));     path.line(to: pt(0.88, 0.48))
path.move(to: stem(0.68));     path.line(to: pt(0.18, 0.20))
path.stroke()
for budAt in [pt(0.88, 0.48), pt(0.18, 0.20)] {
    let r = w * 0.8
    NSBezierPath(ovalIn: NSRect(x: budAt.x - r, y: budAt.y - r,
                                width: r * 2, height: r * 2)).fill()
}

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("icon render failed\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
