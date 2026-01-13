import SwiftUI
import Observation

// MARK: - Video Progress View

struct VideoProgressView: View {
  @Environment(AudioPlayerManager.self) private var playerManager

  @Binding var isSeeking: Bool
  @Binding var seekValue: Double
  @Binding var wasPlayingBeforeSeek: Bool

  var body: some View {
    Slider(
      value: Binding(
        get: { isSeeking ? seekValue : playerManager.currentTime },
        set: { newValue in seekValue = newValue }
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
    .controlSize(.small)
  }
}
