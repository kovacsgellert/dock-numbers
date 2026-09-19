import Cocoa

/// Which screen edge the Dock sits on. Badges go on the screen-center side.
enum DockSide {
  case left, right, bottom, top
}

private final class GlassBadgeView: NSVisualEffectView {
  init(diameter: CGFloat, text: String, dark: Bool) {
    super.init(frame: CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter)))
    // Dark: translucent-dark glass; light: frosted-light glass.
    material = dark ? .hudWindow : .popover
    blendingMode = .behindWindow
    state = .active
    wantsLayer = true
    layer?.cornerRadius = diameter / 2
    layer?.masksToBounds = true
    layer?.borderColor = NSColor.white.withAlphaComponent(dark ? 0.5 : 0.7).cgColor
    layer?.borderWidth = 1

    // Top-down specular gloss: the "liquid" cue.
    let gloss = CAGradientLayer()
    gloss.colors = [
      NSColor.white.withAlphaComponent(dark ? 0.28 : 0.5).cgColor,
      NSColor.white.withAlphaComponent(0.0).cgColor,
    ]
    gloss.startPoint = CGPoint(x: 0.5, y: 0.0)
    gloss.endPoint = CGPoint(x: 0.5, y: 1.0)
    gloss.frame = bounds
    gloss.cornerRadius = diameter / 2
    layer?.addSublayer(gloss)

    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 15, weight: .semibold)
    label.textColor = dark ? .white : .black
    label.alignment = .center
    // Vertically true-center: NSTextField doesn't center text within an
    // oversized frame, so center the field itself (intrinsic height) instead.
    label.translatesAutoresizingMaskIntoConstraints = false
    addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: centerXAnchor),
      label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0.5),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) { fatalError() }
}

private extension NSShadow {
  func withConfigured(color: NSColor, blur: CGFloat, offset: CGSize) -> NSShadow {
    let s = NSShadow()
    s.shadowColor = color
    s.shadowBlurRadius = blur
    s.shadowOffset = offset
    return s
  }
}

/// Floating number badges beside Dock icons.
/// AX frames use a top-left origin; Cocoa windows use bottom-left, so we flip Y.
final class OverlayManager {
  private var panels: [NSPanel] = []
  private let badgeSize: CGFloat = 28
  private let gap: CGFloat = 8

  @MainActor
  func show(apps: [DockApp]) {
    hide()
    guard let screen = NSScreen.screens.first else { return }
    let dark = AppAppearance.isDark
    let screenH = screen.frame.height
    let icons = apps.map { app -> (DockApp, CGRect) in
      let ax = app.frame
      let cocoa = CGRect(x: ax.minX, y: screenH - ax.maxY, width: ax.width, height: ax.height)
      return (app, cocoa)
    }
    let side = Self.detectSide(icons: icons.map(\.1), screen: screen.frame)

    for (app, icon) in icons {
      let origin: CGPoint
      switch side {
      case .right: // Dock on right -> badges to the left, vertically centered
        origin = CGPoint(x: icon.minX - gap - badgeSize, y: icon.midY - badgeSize / 2)
      case .left: // Dock on left -> badges to the right
        origin = CGPoint(x: icon.maxX + gap, y: icon.midY - badgeSize / 2)
      case .bottom: // Dock on bottom -> badges above
        origin = CGPoint(x: icon.midX - badgeSize / 2, y: icon.maxY + gap)
      case .top:
        origin = CGPoint(x: icon.midX - badgeSize / 2, y: icon.minY - gap - badgeSize)
      }
      let panel = NSPanel(
        contentRect: CGRect(origin: origin, size: CGSize(width: badgeSize, height: badgeSize)),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )
      panel.level = .screenSaver
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = true
      panel.ignoresMouseEvents = true
      panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

      panel.contentView = GlassBadgeView(diameter: badgeSize, text: "\(app.index % 10)", dark: dark)
      panel.alphaValue = 0
      panel.orderFrontRegardless()
      NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.12
        panel.animator().alphaValue = 1
      }
      panels.append(panel)
    }
  }

  @MainActor
  func hide() {
    for p in panels { p.orderOut(nil) }
    panels.removeAll()
  }

  /// Geometry-based: no Dock prefs needed, follows the icons wherever they are.
  static func detectSide(icons: [CGRect], screen: CGRect) -> DockSide {
    guard !icons.isEmpty else { return .right }
    let box = icons.reduce(icons[0]) { $0.union($1) }
    if box.width >= box.height {
      return box.midY < screen.midY ? .bottom : .top
    }
    return box.midX < screen.midX ? .left : .right
  }
}
