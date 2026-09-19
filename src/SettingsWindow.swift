import Cocoa
import ApplicationServices

/// Small first-run / settings window: launch-at-login toggle,
/// Accessibility permission status, and a usage hint.
/// Always used from the main thread (menu actions, main-queue callbacks).
final class SettingsWindowController: NSWindowController {
  /// App-lifetime instance: menu items hold their target weakly, so a local
  /// would deallocate and gray out the Settings… item.
  static let shared = SettingsWindowController()

  private var loginSwitch: NSSwitch!
  private var loginLabel: NSTextField!
  private var accessLabel: NSTextField!
  private var accessButton: NSButton!
  private var loginErrorLabel: NSTextField!
  private var accessPoll: Timer?
  private var menubarSwitch: NSSwitch!

  init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 430, height: 285),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "dock-numbers"
    window.center()
    window.isReleasedWhenClosed = false
    super.init(window: window)
    buildUI()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) { fatalError() }

  private func buildUI() {
    guard let content = window?.contentView else { return }
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 14
    stack.edgeInsets = NSEdgeInsets(top: 18, left: 22, bottom: 18, right: 22)
    stack.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: content.topAnchor),
      stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
    ])

    let title = NSTextField(labelWithString: "dock-numbers")
    title.font = .systemFont(ofSize: 15, weight: .semibold)
    stack.addArrangedSubview(title)

    let hint = NSTextField(wrappingLabelWithString: "Hold Option to show numbers on Dock icons, then press 1–9 or 0 to switch apps.")
    hint.font = .systemFont(ofSize: 13)
    hint.textColor = .secondaryLabelColor
    stack.addArrangedSubview(hint)

    stack.addArrangedSubview(NSBox.horizontalSeparator())

    let loginRow = NSStackView()
    loginRow.orientation = .horizontal
    loginRow.alignment = .centerY
    loginRow.spacing = 10
    loginSwitch = NSSwitch()
    loginSwitch.target = self
    loginSwitch.action = #selector(loginToggled(_:))
    loginRow.addArrangedSubview(loginSwitch)
    loginLabel = NSTextField(labelWithString: "Start automatically when you log in")
    loginLabel.font = .systemFont(ofSize: 13)
    loginRow.addArrangedSubview(loginLabel)
    stack.addArrangedSubview(loginRow)

    loginErrorLabel = NSTextField(labelWithString: "")
    loginErrorLabel.font = .systemFont(ofSize: 12)
    loginErrorLabel.textColor = .systemRed
    loginErrorLabel.isHidden = true
    stack.addArrangedSubview(loginErrorLabel)

    let accessRow = NSStackView()
    accessRow.orientation = .horizontal
    accessRow.alignment = .centerY
    accessRow.spacing = 10
    accessLabel = NSTextField(labelWithString: "")
    accessLabel.font = .systemFont(ofSize: 13)
    accessRow.addArrangedSubview(accessLabel)
    accessButton = NSButton(title: "Open System Settings…", target: self, action: #selector(openAccessibilitySettings(_:)))
    accessButton.bezelStyle = .rounded
    accessRow.addArrangedSubview(accessButton)
    stack.addArrangedSubview(accessRow)

    let themeRow = NSStackView()
    themeRow.orientation = .horizontal
    themeRow.alignment = .centerY
    themeRow.spacing = 10
    let themeLabel = NSTextField(labelWithString: "Appearance")
    themeLabel.font = .systemFont(ofSize: 13)
    themeRow.addArrangedSubview(themeLabel)
    let themePopup = NSPopUpButton()
    themePopup.addItems(withTitles: AppAppearance.allCases.map(\.label))
    themePopup.selectItem(withTitle: AppAppearance.current.label)
    themePopup.target = self
    themePopup.action = #selector(appearanceChanged(_:))
    themeRow.addArrangedSubview(themePopup)
    stack.addArrangedSubview(themeRow)

    let menubarRow = NSStackView()
    menubarRow.orientation = .horizontal
    menubarRow.alignment = .centerY
    menubarRow.spacing = 10
    let menubarSwitch = NSSwitch()
    self.menubarSwitch = menubarSwitch
    menubarSwitch.target = self
    menubarSwitch.action = #selector(menubarToggled(_:))
    menubarRow.addArrangedSubview(menubarSwitch)
    let menubarLabel = NSTextField(labelWithString: "Show menu bar icon")
    menubarLabel.font = .systemFont(ofSize: 13)
    menubarRow.addArrangedSubview(menubarLabel)
    stack.addArrangedSubview(menubarRow)

    refreshAll()
    NotificationCenter.default.addObserver(
      self, selector: #selector(refreshAccessibility),
      name: NSApplication.didBecomeActiveNotification, object: nil
    )
  }

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

private extension NSBox {
  static func horizontalSeparator() -> NSBox {
    let box = NSBox()
    box.boxType = .separator
    return box
  }
}
