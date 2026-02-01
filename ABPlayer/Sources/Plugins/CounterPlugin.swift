import SwiftUI
import Observation
import AppKit

@MainActor
@Observable
final class CounterPluginSettings {
  var alwaysOnTop: Bool {
    didSet {
      UserDefaults.standard.set(alwaysOnTop, forKey: "counterPlugin.alwaysOnTop")
    }
  }
  
  init() {
    self.alwaysOnTop = UserDefaults.standard.bool(forKey: "counterPlugin.alwaysOnTop")
  }
}

@MainActor
@Observable
final class CounterPlugin {
  static let shared = CounterPlugin()
  
  let settings = CounterPluginSettings()
  
  private(set) var count: Int = 0
  private var windowController: NSWindowController?
  
  private init() {}
  
  func increment() {
    count += 1
  }
  
  func decrement() {
    count -= 1
  }
  
  func reset() {
    count = 0
  }
  
  func open() {
    if let controller = windowController,
       let window = controller.window,
       window.isVisible {
      window.makeKeyAndOrderFront(nil as Any?)
      return
    }
    
    let contentView = CounterPluginView(plugin: self)
    let hostingController = NSHostingController(rootView: contentView)
    
    let window = NSWindow(contentViewController: hostingController)
    window.title = "Counter"
    window.styleMask = [NSWindow.StyleMask.titled, .closable, .miniaturizable]
    window.setContentSize(NSSize(width: 300, height: 200))
    window.center()
    window.isReleasedWhenClosed = false
    window.level = settings.alwaysOnTop ? NSWindow.Level.floating : .normal
    
    let controller = NSWindowController(window: window)
    windowController = controller
    
    controller.showWindow(nil as Any?)
  }
  
  func updateWindowLevel() {
    windowController?.window?.level = settings.alwaysOnTop ? NSWindow.Level.floating : .normal
  }
}

@MainActor
extension CounterPlugin: Plugin {
  nonisolated var id: String { "counter" }
  var name: String { "Counter" }
  var icon: String { "number.circle" }
}
