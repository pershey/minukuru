import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/icon-master.png"
let size = CGSize(width: 1024, height: 1024)

let image = NSImage(size: size)
image.lockFocus()

let cream = NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.92, alpha: 1.0)
let warmCream = NSColor(calibratedRed: 0.96, green: 0.91, blue: 0.82, alpha: 1.0)
let brown = NSColor(calibratedRed: 0.46, green: 0.27, blue: 0.10, alpha: 1.0)
let stroke = NSColor(calibratedRed: 0.86, green: 0.77, blue: 0.62, alpha: 1.0)
let gold = NSColor(calibratedRed: 0.89, green: 0.67, blue: 0.20, alpha: 1.0)

NSGraphicsContext.current?.imageInterpolation = .high

let background = NSBezierPath(roundedRect: CGRect(origin: .zero, size: size), xRadius: 230, yRadius: 230)
let gradient = NSGradient(starting: cream, ending: warmCream)!
gradient.draw(in: background, angle: -35)

stroke.setStroke()
background.lineWidth = 10
background.stroke()

let badgeRect = CGRect(x: 664, y: 776, width: 244, height: 96)
let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 48, yRadius: 48)
cream.withAlphaComponent(0.95).setFill()
badge.fill()
stroke.setStroke()
badge.lineWidth = 6
badge.stroke()

let badgeBarRect = CGRect(x: 690, y: 812, width: 192, height: 24)
let badgeBar = NSBezierPath(roundedRect: badgeBarRect, xRadius: 12, yRadius: 12)
gold.withAlphaComponent(0.95).setFill()
badgeBar.fill()

let panelRect = CGRect(x: 182, y: 248, width: 660, height: 548)
let panel = NSBezierPath(roundedRect: panelRect, xRadius: 150, yRadius: 150)
NSColor.white.withAlphaComponent(0.7).setFill()
panel.fill()
stroke.setStroke()
panel.lineWidth = 8
panel.stroke()

for index in 0..<3 {
    let inset = CGFloat(index) * 62
    let rect = CGRect(x: 324 + inset, y: 446 + inset * 0.45, width: 220 - inset * 0.65, height: 220 - inset * 0.65)
    let circle = NSBezierPath(ovalIn: rect)
    (index == 1 ? brown : brown.withAlphaComponent(0.22)).setStroke()
    circle.lineWidth = index == 1 ? 26 : 18
    circle.stroke()
}

let dot = NSBezierPath(ovalIn: CGRect(x: 486, y: 543, width: 52, height: 52))
gold.setFill()
dot.fill()

let lines: [(CGFloat, CGFloat, CGFloat)] = [
    (332, 372, 244),
    (370, 322, 292),
    (408, 276, 182)
]

for (y, x, width) in lines {
    let bar = NSBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: 28), xRadius: 14, yRadius: 14)
    brown.withAlphaComponent(y == 372 ? 0.28 : 1.0).setFill()
    bar.fill()
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

image.unlockFocus()

if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath)")
} else {
    fputs("Failed to create PNG data\n", stderr)
    exit(1)
}
