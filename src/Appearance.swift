import Cocoa

/// App theme: follow the system, or force light/dark from Settings.
/// Applied to NSApp (settings window, menu) and read by badges at show time.
enum AppAppearance: String, CaseIterable {
  case system, light, dark

  private static let key = "appearance"

  static var current: AppAppearance {
    get { AppAppearance(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .system }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
  }

  /// Resolve to dark or light right now (override wins, else system).
  static var isDark: Bool {
    switch current {
    case .dark: return true
    case .light: return false
    case .system:
      return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
  }

  /// Push the override into AppKit (nil = follow the system).
  static func apply() {
    switch current {
    case .system: NSApp.appearance = nil
    case .light: NSApp.appearance = NSAppearance(named: .aqua)
    case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
    }
  }

  var label: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }
}
