import SwiftUI
import Observation

@MainActor
@Observable
final class PluginManager {
  static let shared = PluginManager()
  
  private(set) var plugins: [any Plugin] = []
  
  private init() {
    plugins = [
      CounterPlugin.shared
    ]
  }
  
  func plugin(withID id: String) -> (any Plugin)? {
    plugins.first { $0.id == id }
  }
}
