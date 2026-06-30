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

// White clamp-J: a heavy "J" + a clamped bar (mirrors JigMark).
NSColor.white.setFill()
let jFont = NSFont.systemFont(ofSize: side*0.5, weight: .black)
let jAttrs: [NSAttributedString.Key: Any] = [.font: jFont, .foregroundColor: NSColor.white]
let j = NSAttributedString(string: "J", attributes: jAttrs)
let jSize = j.size()
j.draw(at: NSPoint(x: (side - jSize.width)/2 + side*0.02, y: (side - jSize.height)/2 - side*0.02))
// Clamp bar across the J hook (lower-left).
let bar = NSBezierPath(roundedRect:
    NSRect(x: side*0.30, y: side*0.40, width: side*0.16, height: side*0.07),
    xRadius: side*0.02, yRadius: side*0.02)
bar.fill()

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("icon render failed\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
