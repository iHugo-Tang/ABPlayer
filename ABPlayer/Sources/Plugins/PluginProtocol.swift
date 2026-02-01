import SwiftUI

@MainActor
protocol Plugin: Identifiable {
  var id: String { get }
  var name: String { get }
  var icon: String { get }
  
  func open()
}
