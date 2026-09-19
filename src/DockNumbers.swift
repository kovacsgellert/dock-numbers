import Cocoa
import ApplicationServices

@main
struct DockNumbers {
  static func main() {
    let args = CommandLine.arguments
    if args.contains("--daemon") || (args.count == 1 && isAppBundle) {
      runDaemon()
      return
    }
    if args.contains("--list") {
      let apps = DockReader.runningAppItems()
      if apps.isEmpty { print("(no dock apps found)"); return }
      for a in apps {
        let f = a.frame
        print("\(a.index % 10): \(a.title) [\(a.bundleIdentifier ?? "-")] frame=\(Int(f.origin.x)),\(Int(f.origin.y)) \(Int(f.width))x\(Int(f.height))")
      }
      print("\nTip: swift run dock-numbers --activate <number>")
      return
    }
    if let i = args.firstIndex(of: "--activate"), args.count > i + 1,
       let n = Int(args[i + 1]) {
      let apps = DockReader.runningAppItems()
      // User presses 1-9,0 where 0 = 10th
      let idx = (n == 0) ? 10 : n
      guard let app = apps.first(where: { $0.index == idx }) else {
        print("No app for number \(n)"); exit(1)
      }
      print("Activating \(app.title)...")
      exit(AppActivator.activate(app) ? 0 : 1)
    }
    print("Usage: dock-numbers [--list] [--activate <1-9,0>] [--daemon]")
  }

  /// True when running as dock-numbers.app rather than a bare binary.
  static var isAppBundle: Bool {
    Bundle.main.bundleURL.pathExtension == "app"
  }

  /// Menu-bar-style daemon: hold Option to badge Dock icons, press a number to switch.
  static func runDaemon() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    AppAppearance.apply()
    let delegate = AppDelegate()
    app.delegate = delegate
    let overlay = OverlayManager()
    let hotkey = HotkeyManager()
    var current: [DockApp] = []
    var pendingShow: DispatchWorkItem?
    /// Hold-to-show delay: quick Option taps (e.g. Option+letter combos) never flash badges.
    let showDelay: TimeInterval = 0.1

    hotkey.onOptionDown = {
      // Resolve targets immediately so a fast Option+number still switches,
      // but only paint the badges if Option is actually being held.
      current = DockReader.runningAppItems()
      let snapshot = current
      let work = DispatchWorkItem { Task { await overlay.show(apps: snapshot) } }
      pendingShow = work
      DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: work)
    }
    hotkey.onOptionUp = {
      pendingShow?.cancel()
      pendingShow = nil
      current = []
      Task { await overlay.hide() }
    }
    hotkey.onNumber = { number in
      let idx = (number == 0) ? 10 : number
      if let target = current.first(where: { $0.index == idx }) {
        _ = AppActivator.activate(target)
      }
    }

    guard hotkey.start() else {
      // Launched on its own (e.g. via Finder) without Accessibility yet:
      // stay alive, prompt, and let the settings window guide the user.
      // The tap is retried whenever the app activates (see runChrome).
      AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
      print("WARNING: no Accessibility permission yet — badges disabled until granted.")
      runChrome(settings: SettingsWindowController.shared, hotkey: hotkey, forceSettings: true)
      app.run()
      return
    }

    runChrome(settings: SettingsWindowController.shared, hotkey: hotkey, forceSettings: false)
    print("dock-numbers daemon running. Hold Option to show numbers, press 1-9/0 to switch. Ctrl+C to quit.")
    app.run()
  }

  /// Retained so the item can be removed when the user hides it (status bar
  /// does not retain items in a way we can reclaim without our own reference).
  static var statusItem: NSStatusItem?

  /// Menu-bar presence (LSUIElement apps have no Dock icon): Settings + Quit,
  /// first-launch window, and event-tap retry once Accessibility is granted.
  static func runChrome(settings: SettingsWindowController, hotkey: HotkeyManager, forceSettings: Bool) {
    updateStatusItem(settings: settings)

    // If the tap couldn't start (no Accessibility), keep retrying on a timer:
    // granting permission in System Settings never activates us, so an
    // activation-only retry can miss it entirely.
    // Note: `hotkey` is retained by the observer/timer blocks for the app's lifetime.
    Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
      if !hotkey.isRunning, hotkey.start() {
        print("Event tap started — badges enabled.")
      }
    }
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { _ in
      if !hotkey.isRunning, hotkey.start() {
        print("Event tap started — badges enabled.")
      }
    }

    // First launch shows the settings window (login toggle lives there).
    let launchedKey = "hasLaunchedBefore"
    if forceSettings || !UserDefaults.standard.bool(forKey: launchedKey) {
      UserDefaults.standard.set(true, forKey: launchedKey)
      DispatchQueue.main.async { settings.show() }
    }
  }

  /// Create or remove the menu-bar item to match the user setting.
  /// Called at launch and live from the settings toggle.
  static func updateStatusItem(settings: SettingsWindowController) {
    if ShowMenuBarIcon.isEnabled {
      guard statusItem == nil else { return }
      let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
      if let button = item.button {
        button.toolTip = "dock-numbers"
        if let url = Bundle.main.url(forResource: "menubar", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
          icon.isTemplate = true
          icon.size = CGSize(width: 18, height: 18)
          button.image = icon
        } else {
          button.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "dock-numbers")
        }
      }
      let menu = NSMenu()
      let settingsItem = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: "")
      settingsItem.target = settings
      settingsItem.action = #selector(SettingsWindowController.showFromMenu(_:))
      menu.addItem(settingsItem)
      menu.addItem(.separator())
      menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
      item.menu = menu
      statusItem = item
    } else if let item = statusItem {
      NSStatusBar.system.removeStatusItem(item)
      statusItem = nil
    }
  }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    // Launch from Spotlight / click on running app → show settings.
    SettingsWindowController.shared.show()
    return true
  }
}
