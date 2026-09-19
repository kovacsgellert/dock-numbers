import Cocoa
import ApplicationServices

/// Settings window, macOS System Settings style: icon header, grouped boxes,
/// centered About footer. Always used from the main thread.
final class SettingsWindowController: NSWindowController {
  private var loginSwitch: NSSwitch!
  private var loginErrorLabel: NSTextField!
  private var accessLabel: NSTextField!
  private var accessButton: NSButton!
  private var menubarSwitch: NSSwitch!
  private var accessPoll: Timer?

  init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: 460),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "dock-numbers"
    window.center()
    window.isReleasedWhenClosed = false
    super.init(window: window)
    buildUI()
    fitToContent()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) { fatalError() }

  static let shared = SettingsWindowController()

  // MARK: - Layout

  private func buildUI() {
    guard let content = window?.contentView else { return }
    let stack = NSStackView()
    stack.identifier = NSUserInterfaceItemIdentifier("root")
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 14
    stack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
    stack.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: content.topAnchor),
      stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
    ])

    // Header: app icon + name + hint.
    let header = NSStackView()
    header.orientation = .horizontal
    header.alignment = .centerY
    header.spacing = 12
    let iconView = NSImageView(image: NSApp.applicationIconImage)
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      iconView.widthAnchor.constraint(equalToConstant: 56),
      iconView.heightAnchor.constraint(equalToConstant: 56),
    ])
    header.addArrangedSubview(iconView)
    let titleStack = NSStackView()
    titleStack.orientation = .vertical
    titleStack.spacing = 2
    let title = NSTextField(labelWithString: "dock-numbers")
    title.font = .systemFont(ofSize: 16, weight: .semibold)
    titleStack.addArrangedSubview(title)
    let hint = NSTextField(wrappingLabelWithString: "Hold Option for numbers, press 1–9 or 0 to switch apps.")
    hint.font = .systemFont(ofSize: 12)
    hint.textColor = .secondaryLabelColor
    titleStack.addArrangedSubview(hint)
    header.addArrangedSubview(titleStack)
    stack.addArrangedSubview(header)

    // General group.
    loginSwitch = NSSwitch()
    loginSwitch.target = self
    loginSwitch.action = #selector(loginToggled(_:))
    let menubarSwitchLocal = NSSwitch()
    menubarSwitchLocal.target = self
    menubarSwitchLocal.action = #selector(menubarToggled(_:))
    menubarSwitch = menubarSwitchLocal
    let themePopup = NSPopUpButton()
    themePopup.addItems(withTitles: AppAppearance.allCases.map(\.label))
    themePopup.selectItem(withTitle: AppAppearance.current.label)
    themePopup.target = self
    themePopup.action = #selector(appearanceChanged(_:))
    stack.addArrangedSubview(section(title: "General", rows: [
      ("Start automatically when you log in", loginSwitch),
      ("Show menu bar icon", menubarSwitchLocal),
      ("Appearance", themePopup),
    ]))

    loginErrorLabel = NSTextField(labelWithString: "")
    loginErrorLabel.font = .systemFont(ofSize: 12)
    loginErrorLabel.textColor = .systemRed
    loginErrorLabel.isHidden = true
    stack.addArrangedSubview(loginErrorLabel)

    // Accessibility group.
    accessLabel = NSTextField(labelWithString: "")
    accessLabel.font = .systemFont(ofSize: 13)
    accessButton = NSButton(title: "Open System Settings…", target: self, action: #selector(openAccessibilitySettings(_:)))
    accessButton.bezelStyle = .rounded
    stack.addArrangedSubview(section(title: "Accessibility", rows: [(nil, accessLabel), (nil, accessButton)]))

    // About footer.
    let footer = NSStackView()
    footer.orientation = .vertical
    footer.alignment = .centerX
    footer.spacing = 2
    footer.translatesAutoresizingMaskIntoConstraints = false
    let aboutName = NSTextField(labelWithString: "Made by Gellert Kovacs")
    aboutName.font = .systemFont(ofSize: 12)
    aboutName.textColor = .secondaryLabelColor
    aboutName.alignment = .center
    footer.addArrangedSubview(aboutName)
    let repoURL = URL(string: "https://github.com/kovacsgellert/dock-numbers")!
    let aboutLink = NSTextField(wrappingLabelWithString: "")
    aboutLink.isEditable = false
    aboutLink.isSelectable = true
    aboutLink.alignment = .center
    aboutLink.attributedStringValue = NSAttributedString(
      string: "github.com/kovacsgellert/dock-numbers",
      attributes: [.link: repoURL, .font: NSFont.systemFont(ofSize: 12)]
    )
    footer.addArrangedSubview(aboutLink)
    stack.addArrangedSubview(footer)

    refreshAll()
    NotificationCenter.default.addObserver(
      self, selector: #selector(refreshAccessibility),
      name: NSApplication.didBecomeActiveNotification, object: nil
    )
  }

  /// Caption + rounded group with label/control rows (nil label = full-width row).
  private func section(title: String, rows: [(String?, NSView)]) -> NSView {
    let wrap = NSStackView()
    wrap.orientation = .vertical
    wrap.spacing = 6
    wrap.translatesAutoresizingMaskIntoConstraints = false
    let caption = NSTextField(labelWithString: title)
    caption.font = .systemFont(ofSize: 13, weight: .semibold)
    caption.textColor = .secondaryLabelColor
    wrap.addArrangedSubview(caption)

    let boxView = NSView()
    boxView.wantsLayer = true
    boxView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    boxView.layer?.cornerRadius = 10
    boxView.translatesAutoresizingMaskIntoConstraints = false
    let inner = NSStackView()
    inner.orientation = .vertical
    inner.spacing = 12
    inner.translatesAutoresizingMaskIntoConstraints = false
    for (label, control) in rows {
      if let label {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        let l = NSTextField(labelWithString: label)
        l.font = .systemFont(ofSize: 13)
        l.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        row.addArrangedSubview(l)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(control)
        inner.addArrangedSubview(row)
      } else {
        inner.addArrangedSubview(control)
      }
    }
    boxView.addSubview(inner)
    NSLayoutConstraint.activate([
      inner.topAnchor.constraint(equalTo: boxView.topAnchor, constant: 12),
      inner.leadingAnchor.constraint(equalTo: boxView.leadingAnchor, constant: 14),
      inner.trailingAnchor.constraint(equalTo: boxView.trailingAnchor, constant: -14),
      inner.bottomAnchor.constraint(equalTo: boxView.bottomAnchor, constant: -12),
    ])
    wrap.addArrangedSubview(boxView)
    return wrap
  }

  /// Shrink the window to its content so nothing clips.
  private func fitToContent() {
    guard let window, let content = window.contentView else { return }
    content.layoutSubtreeIfNeeded()
    let fitting = content.fittingSize.height
    if fitting > 0, fitting < 800 {
      window.setContentSize(NSSize(width: 400, height: fitting))
      window.center()
    }
  }

  // MARK: - Behavior

  func show() {
    refreshAll()
    window?.center()
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate()
    // Live-update the permission row while open: the grant happens in
    // System Settings, so a one-time check would go stale.
    accessPoll?.invalidate()
    accessPoll = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      guard let self, window?.isVisible == true else { return }
      refreshAccessibility()
    }
  }

  @objc func showFromMenu(_: Any?) {
    show()
  }

  private func refreshAll() {
    loginSwitch.state = LaunchAtLogin.isEnabled ? .on : .off
    menubarSwitch.state = ShowMenuBarIcon.isEnabled ? .on : .off
    loginErrorLabel.isHidden = true
    refreshAccessibility()
  }

  @objc private func loginToggled(_ sender: NSSwitch) {
    loginErrorLabel.isHidden = true
    do {
      try LaunchAtLogin.setEnabled(sender.state == .on)
    } catch {
      loginErrorLabel.stringValue = "Couldn't change login item: \(error.localizedDescription)"
      loginErrorLabel.isHidden = false
      sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }
  }

  @objc private func menubarToggled(_ sender: NSSwitch) {
    ShowMenuBarIcon.setEnabled(sender.state == .on)
    DockNumbers.updateStatusItem(settings: SettingsWindowController.shared)
  }

  @objc private func refreshAccessibility() {
    let granted = AXIsProcessTrusted()
    accessLabel.stringValue = granted
      ? "Accessibility access: granted ✓"
      : "Accessibility access: required to badge the Dock"
    // No need to offer System Settings when there's nothing to fix.
    accessButton.isHidden = granted
  }

  @objc private func openAccessibilitySettings(_: NSButton) {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
  }

  @objc private func appearanceChanged(_ sender: NSPopUpButton) {
    guard let selected = AppAppearance.allCases.first(where: { $0.label == sender.titleOfSelectedItem }) else { return }
    AppAppearance.current = selected
    AppAppearance.apply()
  }
}
