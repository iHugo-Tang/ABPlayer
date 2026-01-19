import AVKit
import OSLog
import Observation
import SwiftData
import SwiftUI

// MARK: - Video Player View

struct VideoPlayerView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(SessionTracker.self) private var sessionTracker
  @Environment(\.modelContext) private var modelContext

  @Bindable var audioFile: ABFile
  
  @State private var viewModel = VideoPlayerViewModel()

  var body: some View {
    GeometryReader { geometry in
      let availableWidth = geometry.size.width
      let effectiveWidth = viewModel.clampWidth(
        viewModel.draggingWidth ?? viewModel.videoPlayerSectionWidth, availableWidth: availableWidth)

      HStack(spacing: 0) {
        // Left: Video Player + Controls
        videoSection
          .frame(minWidth: viewModel.minWidthOfPlayerSection)
          .frame(width: viewModel.showContentPanel ? effectiveWidth : nil)

        // Right: Content panel (PDF, Subtitles only) - takes remaining space
        if viewModel.showContentPanel {
          // Draggable divider
          divider(availableWidth: availableWidth)

          // SegmentsSection takes remaining space
          SegmentsSection(audioFile: audioFile)
            .frame(minWidth: viewModel.minWidthOfContentPanel, maxWidth: .infinity)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
      .animation(.easeInOut(duration: 0.25), value: viewModel.showContentPanel)
      .onChange(of: viewModel.showContentPanel) { _, isShowing in
        if isShowing {
          viewModel.videoPlayerSectionWidth = viewModel.clampWidth(
            viewModel.videoPlayerSectionWidth, availableWidth: availableWidth)
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        sessionTimeDisplay
      }

      ToolbarItem(placement: .primaryAction) {
        Button {
          viewModel.showContentPanel.toggle()
        } label: {
          Label(
            viewModel.showContentPanel ? "Hide Panel" : "Show Panel",
            systemImage: viewModel.showContentPanel ? "sidebar.trailing" : "sidebar.trailing"
          )
        }
        .help(viewModel.showContentPanel ? "Hide content panel" : "Show content panel")
      }
    }
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

  private func divider(availableWidth: CGFloat) -> some View {
    Rectangle()
      .fill(Color.gray.opacity(0.01))
      .frame(width: 8)
      .contentShape(Rectangle())
      .overlay(
        Rectangle()
          .fill(Color(nsColor: .separatorColor))
          .frame(width: 1)
      )
      .onHover { hovering in
        if hovering {
          NSCursor.resizeLeftRight.push()
        } else {
          NSCursor.pop()
        }
      }
      .gesture(
        DragGesture(minimumDistance: 1)
          .onChanged { value in
            let newWidth =
              (viewModel.draggingWidth ?? viewModel.videoPlayerSectionWidth) + value.translation.width
            viewModel.draggingWidth = viewModel.clampWidth(newWidth, availableWidth: availableWidth)
          }
          .onEnded { _ in
            if let finalWidth = viewModel.draggingWidth {
              viewModel.videoPlayerSectionWidth = finalWidth
            }
            viewModel.draggingWidth = nil
          }
      )
  }
  
  private var sessionTimeDisplay: some View {
    HStack(spacing: 6) {
      Image(systemName: "timer")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
      Text(viewModel.timeString(from: Double(sessionTracker.displaySeconds)))
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .foregroundStyle(.primary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(.ultraThinMaterial, in: Capsule())
    .help("Session practice time")
  }

  private var videoSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 1. Video Player Area
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
      .layoutPriority(1)

      // 2. Controls Area (Fixed height)
      VStack(spacing: 12) {
        VideoProgressView(
          isSeeking: $viewModel.isSeeking,
          seekValue: $viewModel.seekValue,
          wasPlayingBeforeSeek: $viewModel.wasPlayingBeforeSeek
        )
        
        VideoControlsView(viewModel: viewModel)
        
        Divider()
        ContentPanelView(audioFile: audioFile)
      }
      .background(.thinMaterial)
    }
  }
}
