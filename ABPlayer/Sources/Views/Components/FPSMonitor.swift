import SwiftUI

@Observable
class FPSMonitor {
  private(set) var fps: Int = 0
  private var lastUpdate = Date()
  private var frames: [Date] = []
  
  func tick() {
    let now = Date()
    frames.append(now)
    frames.removeAll { now.timeIntervalSince($0) > 1.0 }
    
    if now.timeIntervalSince(lastUpdate) >= 0.1 {
      fps = frames.count
      lastUpdate = now
    }
  }
}

struct FPSOverlay: View {
  @State private var monitor = FPSMonitor()
  
  var body: some View {
    Text("FPS: \(monitor.fps)")
      .font(.system(.caption, design: .monospaced))
      .padding(6)
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .task {
        while !Task.isCancelled {
          monitor.tick()
          try? await Task.sleep(for: .milliseconds(16))
        }
      }
  }
}
