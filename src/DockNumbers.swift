import Cocoa

@main
struct DockNumbers {
  static func main() {
    let args = CommandLine.arguments
    if args.contains("--daemon") {
      runDaemon()
      return
    }
    if args.contains("--list") || args.count == 1 {
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

  /// Menu-bar-style daemon: hold Option to badge Dock icons, press a number to switch.
  static func runDaemon() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
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
      print("ERROR: couldn't create event tap. Check Accessibility permission.")
      exit(1)
    }
    print("dock-numbers daemon running. Hold Option to show numbers, press 1-9/0 to switch. Ctrl+C to quit.")
    app.run()
  }
}
