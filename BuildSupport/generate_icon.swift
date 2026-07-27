import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let backgroundRect = NSRect(origin: .zero, size: size).insetBy(dx: 64, dy: 64)
let background = NSBezierPath(
    roundedRect: backgroundRect,
    xRadius: 220,
    yRadius: 220
)

NSGraphicsContext.current?.saveGraphicsState()
let outerShadow = NSShadow()
outerShadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
outerShadow.shadowBlurRadius = 42
outerShadow.shadowOffset = NSSize(width: 0, height: -22)
outerShadow.set()
NSColor.black.setFill()
background.fill()
NSGraphicsContext.current?.restoreGraphicsState()

NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.17, blue: 0.24, alpha: 1),
    NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.24, alpha: 1),
    NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.07, alpha: 1),
])?.draw(in: background, angle: -52)

NSGraphicsContext.current?.saveGraphicsState()
background.addClip()
let glow = NSBezierPath(ovalIn: NSRect(x: 85, y: 570, width: 620, height: 500))
NSGradient(colors: [
    NSColor(calibratedRed: 0.20, green: 0.90, blue: 0.70, alpha: 0.34),
    NSColor(calibratedRed: 0.18, green: 0.48, blue: 0.95, alpha: 0.06),
    NSColor.clear,
])?.draw(in: glow, relativeCenterPosition: NSPoint(x: -0.28, y: 0.20))
NSGraphicsContext.current?.restoreGraphicsState()

background.lineWidth = 8
NSColor.white.withAlphaComponent(0.18).setStroke()
background.stroke()

let innerBackground = NSBezierPath(
    roundedRect: backgroundRect.insetBy(dx: 14, dy: 14),
    xRadius: 204,
    yRadius: 204
)
innerBackground.lineWidth = 3
NSColor.white.withAlphaComponent(0.10).setStroke()
innerBackground.stroke()

let batteryOuterRect = NSRect(x: 168, y: 292, width: 650, height: 430)
let batteryOuter = NSBezierPath(
    roundedRect: batteryOuterRect,
    xRadius: 112,
    yRadius: 112
)

NSGraphicsContext.current?.saveGraphicsState()
let batteryShadow = NSShadow()
batteryShadow.shadowColor = NSColor.black.withAlphaComponent(0.58)
batteryShadow.shadowBlurRadius = 28
batteryShadow.shadowOffset = NSSize(width: 0, height: -15)
batteryShadow.set()
NSColor.black.setFill()
batteryOuter.fill()
NSGraphicsContext.current?.restoreGraphicsState()

NSGradient(colors: [
    NSColor(calibratedWhite: 1.00, alpha: 1),
    NSColor(calibratedRed: 0.72, green: 0.78, blue: 0.82, alpha: 1),
    NSColor(calibratedWhite: 0.96, alpha: 1),
    NSColor(calibratedWhite: 0.50, alpha: 1),
])?.draw(in: batteryOuter, angle: -90)

let batteryCavity = NSBezierPath(
    roundedRect: batteryOuterRect.insetBy(dx: 42, dy: 42),
    xRadius: 73,
    yRadius: 73
)
NSGradient(colors: [
    NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.07, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.14, alpha: 1),
])?.draw(in: batteryCavity, angle: 90)

let batteryTerminal = NSBezierPath(
    roundedRect: NSRect(x: 817, y: 420, width: 70, height: 174),
    xRadius: 28,
    yRadius: 28
)
NSGradient(colors: [
    NSColor(calibratedWhite: 0.98, alpha: 1),
    NSColor(calibratedWhite: 0.60, alpha: 1),
    NSColor(calibratedWhite: 0.84, alpha: 1),
])?.draw(in: batteryTerminal, angle: 0)

let terminalHighlight = NSBezierPath(
    roundedRect: NSRect(x: 826, y: 443, width: 16, height: 126),
    xRadius: 8,
    yRadius: 8
)
NSColor.white.withAlphaComponent(0.46).setFill()
terminalHighlight.fill()

let fillRect = NSRect(x: 226, y: 350, width: 390, height: 314)
let fill = NSBezierPath(
    roundedRect: fillRect,
    xRadius: 58,
    yRadius: 58
)
NSGradient(colors: [
    NSColor(calibratedRed: 0.38, green: 0.98, blue: 0.68, alpha: 1),
    NSColor(calibratedRed: 0.06, green: 0.72, blue: 0.43, alpha: 1),
    NSColor(calibratedRed: 0.03, green: 0.47, blue: 0.31, alpha: 1),
])?.draw(in: fill, angle: -90)

let fillHighlight = NSBezierPath(
    roundedRect: NSRect(x: 246, y: 570, width: 350, height: 70),
    xRadius: 34,
    yRadius: 34
)
NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.45),
    NSColor.white.withAlphaComponent(0),
])?.draw(in: fillHighlight, angle: -90)

let fillEdge = NSBezierPath(
    roundedRect: fillRect.insetBy(dx: 2, dy: 2),
    xRadius: 56,
    yRadius: 56
)
fillEdge.lineWidth = 4
NSColor.white.withAlphaComponent(0.34).setStroke()
fillEdge.stroke()

let bolt = NSBezierPath()
bolt.move(to: NSPoint(x: 578, y: 775))
bolt.line(to: NSPoint(x: 424, y: 514))
bolt.line(to: NSPoint(x: 536, y: 514))
bolt.line(to: NSPoint(x: 462, y: 238))
bolt.line(to: NSPoint(x: 671, y: 563))
bolt.line(to: NSPoint(x: 554, y: 563))
bolt.close()

NSGraphicsContext.current?.saveGraphicsState()
let boltShadow = NSShadow()
boltShadow.shadowColor = NSColor(calibratedRed: 1, green: 0.52, blue: 0.06, alpha: 0.72)
boltShadow.shadowBlurRadius = 28
boltShadow.shadowOffset = NSSize(width: 0, height: -8)
boltShadow.set()
NSColor(calibratedRed: 1, green: 0.65, blue: 0.08, alpha: 1).setFill()
bolt.fill()
NSGraphicsContext.current?.restoreGraphicsState()

NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.98, blue: 0.54, alpha: 1),
    NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.12, alpha: 1),
    NSColor(calibratedRed: 0.96, green: 0.40, blue: 0.04, alpha: 1),
])?.draw(in: bolt, angle: -65)

bolt.lineWidth = 3
NSColor.white.withAlphaComponent(0.42).setStroke()
bolt.stroke()

image.unlockFocus()

guard
    CommandLine.arguments.count > 1,
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let data = bitmap.representation(using: .png, properties: [:])
else {
    exit(1)
}

try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
