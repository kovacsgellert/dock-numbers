import Cocoa

/// Persistent mini-badges: keeps an always-on overlay in sync with the Dock
/// while `badgesAlwaysVisible` is set — apps opening/closing renumber live.
/// Hold-to-show takes over while Option is held; this stands down meanwhile.
final class PersistentBadges: NSObject {
  private let overlay: OverlayManager
  private weak var hotkey: HotkeyManager?
  private var active = false
  private var lastKey: [String] = []
  private var debounce: DispatchWorkItem?

  init(overlay: OverlayManager, hotkey: HotkeyManager) {
    self.overlay = overlay
    self.hotkey = hotkey
    super.init()
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(self, selector: #selector(scheduleRefresh),
                       name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    center.addObserver(self, selector: #selector(scheduleRefresh),
                       name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(sync),
                                           name: .appConfigChanged, object: nil)
    // Poll for the rest (reorders, Dock moves, hand-edited config).
    Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      self?.sync()
    }
  }

  var isActive: Bool { active }

  /// Identity + coarse position: renumbers on open/close/reorder, ignores
   /// sub-pixel jitter (e.g. Dock magnification hover) to avoid flicker.
  private static func key(_ apps: [DockApp]) -> [String] {
    apps.map {
      "\($0.index)|\($0.title)|\($0.bundleURL?.path ?? "")|\(Int($0.frame.minX / 4))|\(Int($0.frame.minY / 4))"
    }
  }

  @objc func sync() {
    guard AppConfig.shared.badgesAlwaysVisible, hotkey?.isOptionHeld == false else {
      if active {
        active = false
        lastKey = []
        Task { await overlay.hide() }
      }
      return
    }
    let apps = DockReader.runningAppItems()
    let k = Self.key(apps)
    guard !active || k != lastKey else { return }
    active = true
    lastKey = k
    Task { await overlay.show(apps: apps, style: .persistent) }
  }

  @objc private func scheduleRefresh() {
    // The Dock animates opens/quits; re-read once it settles.
    debounce?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.sync() }
    debounce = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
  }
}
