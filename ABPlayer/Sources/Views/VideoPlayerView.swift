import AVKit
import OSLog
import Observation
import SwiftData
import SwiftUI

// MARK: - Video Player View

struct VideoPlayerView: View {
  @Environment(PlayerManager.self) private var playerManager
  @Environment(SessionTracker.self) private var sessionTracker
  @Environment(\.modelContext) private var modelContext

  @Bindable var audioFile: ABFile
  
  @State private var viewModel = VideoPlayerViewModel()

  var body: some View {
    videoPlayerSection
      .task {
        viewModel.setup(with: playerManager)
        if playerManager.currentFile?.id != audioFile.id,
          playerManager.currentFile != nil
        {
          await playerManager.load(audioFile: audioFile)
        }
      }
  }

  // MARK: - Components
  
  private var videoPlayerSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 1. Video Player Area
      ZStack {
        Group {
          if let player = playerManager.player {
            NativeVideoPlayer(player: player)
          } else {
            ZStack {
              Color.black
              ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            }
          }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
        
        if let message = viewModel.hudMessage {
          Text(message)
            .font(.title)
            .padding(.all, 16)
            .background(.black.opacity(0.6))
            .foregroundStyle(.white)
            .cornerRadius(8)
            .id(message)
            .opacity(viewModel.isHudVisible ? 1 : 0)
            .scaleEffect(viewModel.isHudVisible ? 1 : 0.5)
        }
      }

      // 2. Controls Area (Fixed height)
      VStack(spacing: 12) {
        VideoProgressView(
          isSeeking: $viewModel.isSeeking,
          seekValue: $viewModel.seekValue,
          wasPlayingBeforeSeek: $viewModel.wasPlayingBeforeSeek
        )
        
        VideoControlsView(viewModel: viewModel)
          .padding(.horizontal)

        Text(audioFile.displayName)
          .font(.title)
          .fontWeight(.semibold)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
      }
    }
  }
}
