import ServiceManagement

/// Start-at-login via the modern SMAppService API (macOS 13+).
/// Only meaningful when running as the .app bundle; calls from a bare
/// binary will throw, which the settings UI surfaces as an error.
enum LaunchAtLogin {
  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  static func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }
}
