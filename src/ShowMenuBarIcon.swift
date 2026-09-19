import Cocoa

/// Show/hide the menu-bar status item via UserDefaults.
/// The status item is created/destroyed in DockNumbers.runChrome.
enum ShowMenuBarIcon {
  private static let key = "showMenuBarIcon"

  static var isEnabled: Bool {
    get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: key) }
  }

  static func setEnabled(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: key)
  }
}