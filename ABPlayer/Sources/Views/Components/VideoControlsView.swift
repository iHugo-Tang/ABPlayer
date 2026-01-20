import SwiftUI
import Observation

struct VideoControlsView: View {
  @Bindable var viewModel: VideoPlayerViewModel
  @Environment(AudioPlayerManager.self) private var playerManager
  @State private var showSubtitle = false
  
  var body: some View {
    ZStack(alignment: .center) {
      HStack {
        VideoTimeDisplay(isSeeking: viewModel.isSeeking, seekValue: viewModel.seekValue)
        
        Spacer()
        
        HStack {
          loopModeMenu
          
          Button {
            showSubtitle.toggle()
          } label: {
            Image(.closedCaption).renderingMode(.template).resizable().aspectRatio(contentMode: .fit).frame(width: 24)
          }
          .buttonStyle(.plain)
          .foregroundStyle(showSubtitle ? Color.accentColor : .primary)
          
          VolumeControl(playerVolume: $viewModel.playerVolume)
        }
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
          ? "\(playerManager.loopMode.iconName)"
          : "repeat"
      )
      .font(.title2)
      .foregroundStyle(playerManager.loopMode != .none ? Color.accentColor : .primary)
    }
    .buttonStyle(.plain)
    .help("Loop mode: \(playerManager.loopMode.displayName)")
  }
  
  private var playbackControls: some View {
    HStack(spacing: 16) {
      Button {
        // switch to previous item
      } label: {
        Image(systemName: "backward.end")
          .font(.title)
      }
      .buttonStyle(.plain)
      .keyboardShortcut("f", modifiers: [])
      
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
      
      Button {
        // switch to next item
      } label: {
        Image(systemName: "forward.end")
          .font(.title)
      }
      .buttonStyle(.plain)
      .keyboardShortcut("f", modifiers: [])
    }
  }
}
