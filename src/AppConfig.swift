import Foundation

/// Portable settings in ~/.config/dock-numbers/config.yml (XDG-style).
/// Hand- and script-editable; the app applies them at launch and reloads
/// them when the settings window opens. No third-party YAML dependency:
/// the format is flat `key: value` pairs, parsed below.
struct AppConfig: Equatable {
  var startAtLogin = false
  var showMenuBarIcon = true
  var appearance = AppAppearance.system
  /// Badge show delay in milliseconds, clamped to 0...500.
  var badgeDelayMs = 100

  static let fileURL: URL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/dock-numbers/config.yml", isDirectory: false)

  /// Live copy used across the app. Mutate then save(), or reload() from disk.
  static var shared = load()

  mutating func reload() {
    self = Self.load()
  }

  // MARK: - Load / save

  static func load() -> AppConfig {
    guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
      // First run (or deleted file): migrate legacy UserDefaults, then persist.
      var fresh = AppConfig()
      fresh.startAtLogin = LaunchAtLogin.isEnabled
      if let v = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool {
        fresh.showMenuBarIcon = v
      }
      if let raw = UserDefaults.standard.string(forKey: "appearance"),
         let a = AppAppearance(rawValue: raw) {
        fresh.appearance = a
      }
      fresh.save()
      return fresh
    }
    var config = AppConfig()
    let dict = parse(text)
    if let raw = dict["start_at_login"], let b = parseBool(raw) {
      config.startAtLogin = b
    }
    if let raw = dict["show_menu_bar_icon"], let b = parseBool(raw) {
      config.showMenuBarIcon = b
    }
    if let raw = dict["appearance"], let a = AppAppearance(rawValue: raw.lowercased()) {
      config.appearance = a
    }
    if let raw = dict["badge_delay_ms"], let ms = Int(raw) {
      config.badgeDelayMs = min(max(ms, 0), 500)
    }
    return config
  }

  func save() {
    let text = """
      # dock-numbers settings — portable, safe to edit by hand or scripts.
      # Regenerated only when missing; your edits are preserved.
      start_at_login: \(startAtLogin)
      show_menu_bar_icon: \(showMenuBarIcon)
      appearance: \(appearance.rawValue)  # system | light | dark
      badge_delay_ms: \(badgeDelayMs)  # 0...500

      """
    do {
      try FileManager.default.createDirectory(
        at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
      )
      try text.write(to: Self.fileURL, atomically: true, encoding: .utf8)
    } catch {
      NSLog("dock-numbers: couldn't save config: \(error)")
    }
  }

  // MARK: - Minimal flat-YAML parsing

  private static func parse(_ text: String) -> [String: String] {
    var out: [String: String] = [:]
    for line in text.components(separatedBy: .newlines) {
      let t = line.trimmingCharacters(in: .whitespaces)
      guard !t.isEmpty, !t.hasPrefix("#") else { continue }
      let parts = t.split(separator: ":", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { continue }
      var value = parts[1].trimmingCharacters(in: .whitespaces)
      if let range = value.range(of: " #") {
        value = String(value[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
      }
      out[parts[0].trimmingCharacters(in: .whitespaces).lowercased()] = value
    }
    return out
  }

  private static func parseBool(_ raw: String) -> Bool? {
    switch raw.lowercased() {
    case "true", "yes", "on", "1": return true
    case "false", "no", "off", "0": return false
    default: return nil
    }
  }
}
