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
    let isFinder = app.bundleIdentifier == "com.apple.finder"
    // If frontmost *with visible windows*, hide it (toggle). Otherwise
    // activate — and for Finder, restore minimized windows and open a new
    // one if there are none, mirroring a Dock click.
    if app.isActive, !isFinder || hasVisibleWindows(pid: app.processIdentifier) {
      app.hide()
    } else {
      _ = app.activate()
      if isFinder {
        unminimizeWindows(pid: app.processIdentifier)
        if finderWindowCount(pid: app.processIdentifier) == 0 {
          NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
        }
      }
    }
    return true
  }

  /// Real Finder windows (role AXWindow), excluding exposed non-windows.
  private static func standardWindows(pid: pid_t) -> [AXUIElement] {
    let finder = AXUIElementCreateApplication(pid)
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(finder, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement]
    else { return [] }
    return windows.filter { w in
      var role: AnyObject?
      AXUIElementCopyAttributeValue(w, kAXRoleAttribute as CFString, &role)
      return (role as? String) == "AXWindow"
    }
  }

  private static func isMinimized(_ w: AXUIElement) -> Bool {
    var v: AnyObject?
    AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &v)
    return (v as? NSNumber)?.boolValue == true
  }

  private static func hasVisibleWindows(pid: pid_t) -> Bool {
    standardWindows(pid: pid).contains { !isMinimized($0) }
  }

  private static func unminimizeWindows(pid: pid_t) {
    for w in standardWindows(pid: pid) where isMinimized(w) {
      AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
      AXUIElementPerformAction(w, kAXRaiseAction as CFString)
    }
  }

  /// Number of Finder's real windows via Accessibility (no extra permission needed).
  private static func finderWindowCount(pid: pid_t) -> Int {
    standardWindows(pid: pid).count
  }
}
