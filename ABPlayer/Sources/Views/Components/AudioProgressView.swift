import SwiftUI
import Observation

struct AudioProgressView: View {
  @Environment(AudioPlayerManager.self) private var playerManager

  @Binding var isSeeking: Bool
  @Binding var seekValue: Double
  @Binding var wasPlayingBeforeSeek: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Slider(
        value: Binding(
          get: {
            isSeeking ? seekValue : playerManager.currentTime
          },
          set: { newValue in
            seekValue = newValue
          }
        ),
        in: 0...(playerManager.duration > 0 ? playerManager.duration : 1),
        onEditingChanged: { editing in
          if editing {
            isSeeking = true
            wasPlayingBeforeSeek = playerManager.isPlaying
            if playerManager.isPlaying {
              playerManager.togglePlayPause()
            }
          } else {
            playerManager.seek(to: seekValue)
            isSeeking = false
            if wasPlayingBeforeSeek {
              playerManager.togglePlayPause()
            }
          }
        }
      )

      HStack {
        Text(timeString(from: isSeeking ? seekValue : playerManager.currentTime))
        Spacer()
        Text(timeString(from: playerManager.duration))
      }
      .captionStyle()
      .foregroundStyle(.secondary)
    }
  }

  private func timeString(from value: Double) -> String {
    guard value.isFinite, value >= 0 else {
      return "0:00"
    }

    let totalSeconds = Int(value.rounded())
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60

    return String(format: "%d:%02d", minutes, seconds)
  }
}

