import Cocoa

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
    // If already frontmost, hide it (QuickDock behavior). Otherwise activate.
    if app.isActive {
      app.hide()
    } else {
      _ = app.activate()
    }
    return true
  }
}
