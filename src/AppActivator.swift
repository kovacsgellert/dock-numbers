import Cocoa
import ApplicationServices

enum AppActivator {
  /// Activate the running app matching a Dock item. Returns true on success.
  static func activate(_ dockApp: DockApp) -> Bool {
    let running = NSWorkspace.shared.runningApplications
    var target: NSRunningApplication?

    if let bid = dockApp.bundleIdentifier {
      target = running.first { $0.bundleIdentifier == bid }
    }
    if target == nil, let url = dockApp.bundleURL {
      let path = url.path
      target = running.first { $0.bundleURL?.path == path }
    }
    if target == nil {
      target = running.first { $0.localizedName == dockApp.title }
    }
    guard let app = target else { return false }
    // If already frontmost, hide it. Otherwise activate.
    if app.isActive {
      app.hide()
    } else {
      _ = app.activate()
      // Like clicking the Dock icon: Finder with no windows opens a new one
      // instead of just focusing the menu bar.
      if app.bundleIdentifier == "com.apple.finder", finderWindowCount(pid: app.processIdentifier) == 0 {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
      }
    }
    return true
  }

  /// Number of Finder's real windows via Accessibility (no extra permission needed).
  /// Filters to role AXWindow: Finder also exposes non-window elements here.
  private static func finderWindowCount(pid: pid_t) -> Int {
    let finder = AXUIElementCreateApplication(pid)
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(finder, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement]
    else { return 0 }
    return windows.filter { w in
      var role: AnyObject?
      AXUIElementCopyAttributeValue(w, kAXRoleAttribute as CFString, &role)
      return (role as? String) == "AXWindow"
    }.count
  }
}
