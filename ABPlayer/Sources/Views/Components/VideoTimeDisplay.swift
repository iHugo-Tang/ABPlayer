import SwiftUI
import Observation

// MARK: - Video Time Display

struct VideoTimeDisplay: View {
  @Environment(PlayerManager.self) private var playerManager

  let isSeeking: Bool
  let seekValue: Double

  var body: some View {
    HStack(spacing: 4) {
      Text(timeString(from: isSeeking ? seekValue : playerManager.currentTime))
      Text("/")
        .foregroundStyle(.secondary)
      Text(timeString(from: playerManager.duration))
    }
    .font(.body.monospacedDigit())
  }

  private func timeString(from value: Double) -> String {
    guard value.isFinite, value >= 0 else {
      return "0:00"
    }

    let totalSeconds = Int(value.rounded())
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60

    if minutes >= 60 {
      let hours = minutes / 60
      let remainingMinutes = minutes % 60
      return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
    }

    return String(format: "%d:%02d", minutes, seconds)
  }
}
