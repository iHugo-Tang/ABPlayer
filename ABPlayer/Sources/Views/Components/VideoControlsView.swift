import SwiftUI
import Observation

struct VideoControlsView: View {
  @Bindable var viewModel: VideoPlayerViewModel
  @Environment(AudioPlayerManager.self) private var playerManager
  
  var body: some View {
    ZStack(alignment: .center) {
      HStack {
        // Loop Mode & Volume
        HStack(spacing: 12) {
          loopModeMenu
          VolumeControl(playerVolume: $viewModel.playerVolume)
        }

        Spacer()

        VideoTimeDisplay(isSeeking: viewModel.isSeeking, seekValue: viewModel.seekValue)
      }

      // Playback Controls
      playbackControls
    }
  }
  
  private var loopModeMenu: some View {
    Menu {
      ForEach(LoopMode.allCases, id: \.self) { mode in
        Button {
          viewModel.updateLoopMode(mode)
        } label: {
          HStack {
            Image(systemName: mode.iconName)
            Text(mode.displayName)
          }
        }
      }
    } label: {
      Image(
        systemName: playerManager.loopMode != .none
          ? "\(playerManager.loopMode.iconName).circle.fill"
          : "repeat.circle"
      )
      .font(.title)
      .foregroundStyle(playerManager.loopMode != .none ? .blue : .primary)
    }
    .buttonStyle(.plain)
    .help("Loop mode: \(playerManager.loopMode.displayName)")
  }
  
  private var playbackControls: some View {
    HStack(spacing: 16) {
      Button {
        viewModel.seekBack()
      } label: {
        Image(systemName: "gobackward.5")
          .font(.title)
      }
      .buttonStyle(.plain)
      .keyboardShortcut("f", modifiers: [])

      Button {
        viewModel.togglePlayPause()
      } label: {
        Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .font(.system(size: 36))
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.space, modifiers: [])

      Button {
        viewModel.seekForward()
      } label: {
        Image(systemName: "goforward.10")
          .font(.title)
      }
      .buttonStyle(.plain)
      .keyboardShortcut("g", modifiers: [])
    }
  }
}
