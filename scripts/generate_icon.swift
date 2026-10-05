import Cocoa

// ============================================================================
// Lua Lamp — Procedural App Icon Generator
// Generates Retina macOS .icns and high-res multi-platform PNG icons.
// ============================================================================

let size = 1024
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
let image = NSImage(size: canvas.size)

image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    print("Error: Could not obtain CGContext")
    exit(1)
}

// 1. Clear background
ctx.clear(canvas)

// 2. macOS Squircle base (824x824 centered within 1024x1024)
let iconRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185
let squirclePath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

// Soft drop shadow
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
shadow.shadowOffset = NSSize(width: 0, height: -26)
shadow.shadowBlurRadius = 38
shadow.set()

// Background Gradient: Deep midnight sapphire / Lua navy slate
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0).cgColor, // Top
    NSColor(red: 0.03, green: 0.05, blue: 0.11, alpha: 1.0).cgColor  // Bottom
] as CFArray
let bgLocations: [CGFloat] = [0.0, 1.0]

if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
    ctx.saveGState()
    squirclePath.addClip()
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()
}

// Clip everything inside squircle
ctx.saveGState()
squirclePath.addClip()

// 3. Subtle background radial orbital rings & technical grid
ctx.saveGState()
ctx.setLineWidth(1.8)
ctx.setStrokeColor(NSColor(red: 0.20, green: 0.35, blue: 0.60, alpha: 0.25).cgColor)

for r: CGFloat in [160, 260, 360] {
    ctx.strokeEllipse(in: CGRect(x: 512 - r, y: 530 - r, width: r * 2, height: r * 2))
}

// Lua Orbital Moon Accent (upper right)
let moonCenter = CGPoint(x: 710, y: 730)
let moonRadius: CGFloat = 34
ctx.setFillColor(NSColor(red: 0.0, green: 0.0, blue: 0.5, alpha: 0.35).cgColor)
ctx.fillEllipse(in: CGRect(x: moonCenter.x - moonRadius, y: moonCenter.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2))

let moonGoldColors = [
    NSColor(red: 0.95, green: 0.75, blue: 0.20, alpha: 0.9).cgColor,
    NSColor(red: 0.90, green: 0.55, blue: 0.10, alpha: 0.4).cgColor
] as CFArray
if let moonGrad = CGGradient(colorsSpace: colorSpace, colors: moonGoldColors, locations: [0.0, 1.0]) {
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: moonCenter.x - moonRadius, y: moonCenter.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2))
    ctx.clip()
    ctx.drawRadialGradient(moonGrad, startCenter: CGPoint(x: moonCenter.x - 8, y: moonCenter.y + 8), startRadius: 2, endCenter: moonCenter, endRadius: moonRadius, options: [])
    ctx.restoreGState()
}
ctx.restoreGState()

// 4. Volumetric Golden Lamp Glow (Ambient Warmth Behind Bulb)
ctx.saveGState()
let glowColors = [
    NSColor(red: 1.0, green: 0.88, blue: 0.45, alpha: 0.55).cgColor, // Bright core
    NSColor(red: 1.0, green: 0.68, blue: 0.15, alpha: 0.28).cgColor, // Amber bloom
    NSColor(red: 0.95, green: 0.45, blue: 0.05, alpha: 0.08).cgColor, // Outer halo
    NSColor(red: 0.95, green: 0.45, blue: 0.05, alpha: 0.0).cgColor   // Fade
] as CFArray
let glowLocations: [CGFloat] = [0.0, 0.30, 0.65, 1.0]
if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: glowLocations) {
    let bulbCenter = CGPoint(x: 512, y: 550)
    ctx.drawRadialGradient(glowGrad, startCenter: bulbCenter, startRadius: 20, endCenter: bulbCenter, endRadius: 280, options: [])
}
ctx.restoreGState()

// 5. Stylized Modern Lamp / Lightbulb Illustration
// A. Bulb Glass Silhouette
let bulbCenter = CGPoint(x: 512, y: 565)
let bulbRadius: CGFloat = 160

// Bulb Path (Sphere dome transitioning into socket neck)
let bulbPath = CGMutablePath()
// Start at neck left
let neckY: CGFloat = 390
let neckHalfWidth: CGFloat = 72
bulbPath.move(to: CGPoint(x: 512 - neckHalfWidth, y: neckY))
// Curve outwards to bottom of sphere
bulbPath.addCurve(
    to: CGPoint(x: 512 - bulbRadius, y: bulbCenter.y),
    control1: CGPoint(x: 512 - neckHalfWidth, y: 440),
    control2: CGPoint(x: 512 - bulbRadius, y: 490)
)
// Top dome arc
bulbPath.addArc(center: bulbCenter, radius: bulbRadius, startAngle: .pi, endAngle: 0, clockwise: true)
// Curve inwards from right side back down to neck right
bulbPath.addCurve(
    to: CGPoint(x: 512 + neckHalfWidth, y: neckY),
    control1: CGPoint(x: 512 + bulbRadius, y: 490),
    control2: CGPoint(x: 512 + neckHalfWidth, y: 440)
)
bulbPath.closeSubpath()

// Glass Interior Tint
ctx.saveGState()
let glassColors = [
    NSColor(red: 1.0, green: 0.95, blue: 0.80, alpha: 0.22).cgColor,
    NSColor(red: 0.20, green: 0.30, blue: 0.50, alpha: 0.12).cgColor
] as CFArray
if let glassGrad = CGGradient(colorsSpace: colorSpace, colors: glassColors, locations: [0.0, 1.0]) {
    ctx.addPath(bulbPath)
    ctx.clip()
    ctx.drawLinearGradient(glassGrad, start: CGPoint(x: 512, y: bulbCenter.y + bulbRadius), end: CGPoint(x: 512, y: neckY), options: [])
}
ctx.restoreGState()

// Glass Stroke
ctx.saveGState()
ctx.setLineWidth(5.0)
ctx.setStrokeColor(NSColor(red: 1.0, green: 0.92, blue: 0.65, alpha: 0.75).cgColor)
ctx.addPath(bulbPath)
ctx.strokePath()
ctx.restoreGState()

// B. Filament Mount Supports
ctx.saveGState()
ctx.setLineWidth(4.0)
ctx.setStrokeColor(NSColor(red: 0.7, green: 0.65, blue: 0.55, alpha: 0.7).cgColor)
// Left support wire
ctx.move(to: CGPoint(x: 480, y: neckY + 10))
ctx.addLine(to: CGPoint(x: 472, y: 520))
ctx.strokePath()
// Right support wire
ctx.move(to: CGPoint(x: 544, y: neckY + 10))
ctx.addLine(to: CGPoint(x: 552, y: 520))
ctx.strokePath()
ctx.restoreGState()

// C. Glowing Incandescent Filament ("L" shaped loop for Lua Lamp!)
ctx.saveGState()
let filamentPath = CGMutablePath()
filamentPath.move(to: CGPoint(x: 472, y: 520))
filamentPath.addCurve(to: CGPoint(x: 450, y: 590), control1: CGPoint(x: 460, y: 550), control2: CGPoint(x: 450, y: 570))
filamentPath.addCurve(to: CGPoint(x: 512, y: 645), control1: CGPoint(x: 450, y: 625), control2: CGPoint(x: 480, y: 645))
filamentPath.addCurve(to: CGPoint(x: 574, y: 590), control1: CGPoint(x: 544, y: 645), control2: CGPoint(x: 574, y: 625))
filamentPath.addCurve(to: CGPoint(x: 552, y: 520), control1: CGPoint(x: 574, y: 570), control2: CGPoint(x: 564, y: 550))

// Multi-pass bloom for high-intensity glow
// Outer bloom
ctx.setLineWidth(24.0)
ctx.setStrokeColor(NSColor(red: 1.0, green: 0.65, blue: 0.05, alpha: 0.35).cgColor)
ctx.setLineCap(.round)
ctx.addPath(filamentPath)
ctx.strokePath()

// Mid bloom
ctx.setLineWidth(14.0)
ctx.setStrokeColor(NSColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 0.75).cgColor)
ctx.addPath(filamentPath)
ctx.strokePath()

// Core hot white-gold filament wire
ctx.setLineWidth(6.0)
ctx.setStrokeColor(NSColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 1.0).cgColor)
ctx.addPath(filamentPath)
ctx.strokePath()
ctx.restoreGState()

// D. Lamp Base / Metallic Screw Threads
let socketBaseY: CGFloat = neckY
let socketHeight: CGFloat = 110
let socketWidth: CGFloat = 136
let socketX: CGFloat = 512 - socketWidth / 2

// Thread ribs (cylindrical segments)
let threadCount = 4
let threadH: CGFloat = 20
for i in 0..<threadCount {
    let ty = socketBaseY - CGFloat(i + 1) * (threadH + 2)
    let tw = socketWidth - CGFloat(i * 4)
    let tx = 512 - tw / 2
    let threadRect = CGRect(x: tx, y: ty, width: tw, height: threadH)
    let threadPath = NSBezierPath(roundedRect: threadRect, xRadius: 8, yRadius: 8)
    
    // Metallic gradient: Brushed steel & brass
    let brassColors = [
        NSColor(red: 0.70, green: 0.58, blue: 0.36, alpha: 1.0).cgColor,
        NSColor(red: 0.92, green: 0.82, blue: 0.58, alpha: 1.0).cgColor,
        NSColor(red: 0.50, green: 0.40, blue: 0.22, alpha: 1.0).cgColor
    ] as CFArray
    if let brassGrad = CGGradient(colorsSpace: colorSpace, colors: brassColors, locations: [0.0, 0.5, 1.0]) {
        ctx.saveGState()
        threadPath.addClip()
        ctx.drawLinearGradient(brassGrad, start: CGPoint(x: tx, y: ty), end: CGPoint(x: tx + tw, y: ty), options: [])
        ctx.restoreGState()
    }
}

// Bottom Contact Tip (black insulator and metal contact)
let insulatorY = socketBaseY - CGFloat(threadCount) * (threadH + 2) - 16
let insulatorRect = CGRect(x: 512 - 34, y: insulatorY, width: 68, height: 18)
ctx.setFillColor(NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).cgColor)
ctx.fillEllipse(in: insulatorRect)

let contactRect = CGRect(x: 512 - 18, y: insulatorY - 8, width: 36, height: 14)
ctx.setFillColor(NSColor(red: 0.65, green: 0.65, blue: 0.70, alpha: 1.0).cgColor)
ctx.fillEllipse(in: contactRect)

// 6. Glass Highlights & Gloss Reflection (Top-left curved specular arc)
ctx.saveGState()
let specPath = CGMutablePath()
specPath.addArc(center: bulbCenter, radius: bulbRadius - 16, startAngle: .pi * 0.65, endAngle: .pi * 0.88, clockwise: false)
ctx.setLineWidth(9.0)
ctx.setLineCap(.round)
ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.45).cgColor)
ctx.addPath(specPath)
ctx.strokePath()
ctx.restoreGState()

// 7. Subtle "LUA LAMP" bottom typography banner
let bannerY: CGFloat = 150
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 46, weight: .black),
    .foregroundColor: NSColor(red: 0.95, green: 0.85, blue: 0.40, alpha: 0.92),
    .kern: 5.0
]
let titleStr = NSAttributedString(string: "LUA LAMP", attributes: titleAttributes)
let titleSize = titleStr.size()
let titleOrigin = CGPoint(x: 512 - titleSize.width / 2, y: bannerY)
titleStr.draw(at: titleOrigin)

ctx.restoreGState() // End squircle clip
image.unlockFocus()

// ============================================================================
// Output Generation: PNG & .icns iconset
// ============================================================================

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Error: Could not render PNG")
    exit(1)
}

let fileManager = FileManager.default
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let rootDir = (scriptDir as NSString).deletingLastPathComponent
let resourcesDir = (rootDir as NSString).appendingPathComponent("resources")
let outPng = (resourcesDir as NSString).appendingPathComponent("icon.png")
let outIcns = (rootDir as NSString).appendingPathComponent("LuaLamp.icns")

do {
    try fileManager.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true, attributes: nil)
    try pngData.write(to: URL(fileURLWithPath: outPng))
    print("✓ Master PNG icon written to \(outPng)")
} catch {
    print("Error writing master PNG: \(error)")
    exit(1)
}

// Generate iconset for macOS iconutil
let iconsetDir = "/tmp/LuaLamp.iconset"
try? fileManager.removeItem(atPath: iconsetDir)
try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true, attributes: nil)

let sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in sizes {
    let targetPath = (iconsetDir as NSString).appendingPathComponent(name)
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    task.arguments = ["-z", "\(px)", "\(px)", outPng, "--out", targetPath]
    task.standardOutput = Pipe()
    task.standardError = Pipe()
    try? task.run()
    task.waitUntilExit()
}

// Also write standard Linux PNG icon sizes
for px in [16, 32, 48, 64, 128, 256, 512] {
    let linuxIconPath = (resourcesDir as NSString).appendingPathComponent("lualamp_\(px)x\(px).png")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    task.arguments = ["-z", "\(px)", "\(px)", outPng, "--out", linuxIconPath]
    task.standardOutput = Pipe()
    task.standardError = Pipe()
    try? task.run()
    task.waitUntilExit()
}
// Copy 256x256 as default resources/lualamp.png
let defaultLinuxPng = (resourcesDir as NSString).appendingPathComponent("lualamp.png")
try? fileManager.copyItem(atPath: (resourcesDir as NSString).appendingPathComponent("lualamp_256x256.png"), toPath: defaultLinuxPng)

// Run iconutil to create .icns
let iconutilTask = Process()
iconutilTask.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutilTask.arguments = ["-c", "icns", iconsetDir, "-o", outIcns]
try? iconutilTask.run()
iconutilTask.waitUntilExit()

if fileManager.fileExists(atPath: outIcns) {
    print("✓ macOS .icns written successfully to \(outIcns)")
} else {
    print("Warning: iconutil could not generate .icns")
}

print("✓ All icon assets successfully generated for macOS and Linux!")
