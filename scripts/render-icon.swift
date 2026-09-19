#!/usr/bin/env swift
// Renders dock-numbers artwork without design tools:
//   assets/icon-1024.png  - full-color app icon (dark glass tile + badges 1/2/3)
//   assets/menubar.png    - monochrome template (glass "1" disc, knocked-out glyph)
// Run: swift scripts/render-icon.swift
import Cocoa

let outDir = URL(fileURLWithPath: "assets", relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))

func write(_ image: NSImage, to name: String) throws {
  guard let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "encode failed"])
  }
  try png.write(to: outDir.appendingPathComponent(name))
}

// MARK: - App icon

func appIcon(size: CGFloat) -> NSImage {
  NSImage(size: CGSize(width: size, height: size), flipped: false) { rect in
    let tile = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.06, dy: size * 0.06),
                            xRadius: size * 0.24, yRadius: size * 0.24)
    // Dark glass tile.
    let bg = NSGradient(colors: [NSColor(calibratedWhite: 0.23, alpha: 1),
                                 NSColor(calibratedWhite: 0.08, alpha: 1)])!
    bg.draw(in: tile, angle: 90)
    // Rim light.
    NSColor.white.withAlphaComponent(0.35).setStroke()
    tile.lineWidth = size * 0.008
    tile.stroke()
    // Top gloss, fading smoothly over the whole tile (no seam).
    NSGraphicsContext.saveGraphicsState()
    tile.setClip()
    let gloss = NSGradient(colors: [NSColor.white.withAlphaComponent(0.20),
                                    NSColor.white.withAlphaComponent(0.0)])!
    gloss.draw(in: rect, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // Three frosted number badges.
    let labels = ["1", "2", "3"]
    let d = size * 0.21
    let gap = size * 0.045
    let total = d * 3 + gap * 2
    var x = (size - total) / 2
    let y = (size - d) / 2 - size * 0.01
    for label in labels {
      let badge = NSBezierPath(ovalIn: CGRect(x: x, y: y, width: d, height: d))
      NSColor(calibratedWhite: 0.32, alpha: 0.92).setFill()
      badge.fill()
      NSColor.white.withAlphaComponent(0.55).setStroke()
      badge.lineWidth = size * 0.006
      badge.stroke()
      let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: d * 0.52, weight: .semibold),
        .foregroundColor: NSColor.white,
      ]
      let s = NSAttributedString(string: label, attributes: attrs)
      let ts = s.size()
      s.draw(at: CGPoint(x: x + (d - ts.width) / 2, y: y + (d - ts.height) / 2 - d * 0.02))
      x += d + gap
    }
    return true
  }
}

// MARK: - Menu bar template (alpha-only: solid disc, knocked-out numeral)

func menuBarIcon() -> NSImage {
  let size: CGFloat = 44
  return NSImage(size: CGSize(width: size, height: size), flipped: false) { rect in
    let disc = NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4))
    NSColor.black.setFill()
    disc.fill()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4)).setClip()
    NSColor.black.withAlphaComponent(0.25).setFill()
    NSBezierPath(ovalIn: CGRect(x: 4, y: rect.height / 2, width: rect.width - 8, height: rect.height / 2 - 4)).fill()
    NSGraphicsContext.restoreGraphicsState()
    // Knock out the "1" so it renders as menu-bar foreground negative space.
    NSGraphicsContext.saveGraphicsState()
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24, weight: .semibold)]
    let s = NSAttributedString(string: "1", attributes: attrs)
    let ts = s.size()
    NSBezierPath(rect: rect).setClip()
    NSGraphicsContext.current?.cgContext.setBlendMode(.destinationOut)
    s.draw(at: CGPoint(x: (size - ts.width) / 2, y: (size - ts.height) / 2 - 1))
    NSGraphicsContext.restoreGraphicsState()
    return true
  }
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try write(appIcon(size: 1024), to: "icon-1024.png")
try write(menuBarIcon(), to: "menubar.png")
print("Wrote assets/icon-1024.png + assets/menubar.png")
