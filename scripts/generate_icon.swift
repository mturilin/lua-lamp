import Cocoa

// ============================================================================
// Lua Lamp — App Icon Generator
// Generates Retina macOS .icns and high-res multi-platform PNG icons
// using the Glowing Retro Lava Lamp artwork.
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

// Soft realistic macOS drop shadow
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
shadow.shadowOffset = NSSize(width: 0, height: -24)
shadow.shadowBlurRadius = 36
shadow.set()

// Deep charcoal base matching artwork background
let darkBg = NSColor(calibratedRed: 16/255.0, green: 16/255.0, blue: 18/255.0, alpha: 1.0)
darkBg.setFill()
squirclePath.fill()

// Clip contents within squircle
ctx.saveGState()
squirclePath.addClip()

// Locate artwork source
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let rootDir = (scriptDir as NSString).deletingLastPathComponent
let resourcesDir = (rootDir as NSString).appendingPathComponent("resources")
let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

let artworkCandidates = [
    (resourcesDir as NSString).appendingPathComponent("glowing_retro_lava_lamp.png"),
    (homeDir as NSString).appendingPathComponent("Downloads/Glowing Retro Lava Lamp.png"),
    (rootDir as NSString).appendingPathComponent("glowing_retro_lava_lamp.png")
]

var loadedImage: NSImage?
for path in artworkCandidates {
    if FileManager.default.fileExists(atPath: path), let img = NSImage(contentsOfFile: path) {
        loadedImage = img
        break
    }
}

if let lavaImg = loadedImage {
    // Center the glowing retro lava lamp inside the squircle
    // Scale slightly (0.95) to give the metallic tip and base elegant breathing room
    let scale: CGFloat = 0.95
    let drawW = 824.0 * scale
    let drawH = 824.0 * scale
    let drawX = 100.0 + (824.0 - drawW) / 2.0
    let drawY = 100.0 + (824.0 - drawH) / 2.0
    lavaImg.draw(in: NSRect(x: drawX, y: drawY, width: drawW, height: drawH),
                 from: NSRect(origin: .zero, size: lavaImg.size),
                 operation: .sourceOver,
                 fraction: 1.0)
} else {
    print("Warning: Glowing Retro Lava Lamp artwork not found, falling back to background")
}

// Subtle inner border highlight
ctx.setLineWidth(1.5)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
squirclePath.stroke()

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
try? fileManager.removeItem(atPath: defaultLinuxPng)
try? fileManager.copyItem(atPath: (resourcesDir as NSString).appendingPathComponent("lualamp_256x256.png"), toPath: defaultLinuxPng)

// Run iconutil to create .icns
try? fileManager.removeItem(atPath: outIcns)
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

print("✓ All icon assets successfully generated for macOS and Linux with Glowing Retro Lava Lamp!")
