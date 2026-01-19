import Observation
import SwiftData
import SwiftUI

// MARK: - Audio Player View

struct AudioPlayerView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(SessionTracker.self) private var sessionTracker
  @Environment(\.modelContext) private var modelContext

  @Bindable var audioFile: ABFile
  
  @State private var viewModel = AudioPlayerViewModel()

  var body: some View {
    GeometryReader { geometry in
      let availableWidth = geometry.size.width
      let effectiveWidth = viewModel.clampWidth(
        viewModel.draggingWidth ?? viewModel.playerSectionWidth, availableWidth: availableWidth)

      HStack(spacing: 0) {
        // Left: Player controls + Content (Transcription/PDF)
        playerSection
          .frame(minWidth: viewModel.minWidthOfPlayerSection)
          .frame(width: viewModel.showContentPanel ? effectiveWidth : nil)

        // Right: Segments panel - takes remaining space
        if viewModel.showContentPanel {
          // Draggable divider for playerSection
          divider(availableWidth: availableWidth)

          // SegmentsSection takes remaining space
          SegmentsSection(audioFile: audioFile)
            .frame(minWidth: viewModel.minWidthOfContentPanel, maxWidth: .infinity)
            .padding()
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
      .animation(.easeInOut(duration: 0.25), value: viewModel.showContentPanel)
      .onChange(of: viewModel.showContentPanel) { _, isShowing in
        if isShowing {
          viewModel.playerSectionWidth = viewModel.clampWidth(viewModel.playerSectionWidth, availableWidth: availableWidth)
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
            viewModel.showContentPanel ? "Hide Segments" : "Show Segments",
            systemImage: viewModel.showContentPanel ? "sidebar.trailing" : "sidebar.trailing"
          )
        }
        .help(viewModel.showContentPanel ? "Hide segments panel" : "Show segments panel")
      }
    }
    .onAppear {
      viewModel.setup(with: playerManager)
      if playerManager.currentFile?.id != audioFile.id,
        playerManager.currentFile != nil
      {
        Task { await playerManager.load(audioFile: audioFile) }
      }
    }
    .onChange(of: audioFile) { _, newFile in
      Task {
        if playerManager.currentFile?.id != newFile.id {
          await playerManager.load(audioFile: newFile)
        }
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
            let newWidth = (viewModel.draggingWidth ?? viewModel.playerSectionWidth) + value.translation.width
            viewModel.draggingWidth = viewModel.clampWidth(newWidth, availableWidth: availableWidth)
          }
          .onEnded { _ in
            if let finalWidth = viewModel.draggingWidth {
              viewModel.playerSectionWidth = finalWidth
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

  // MARK: - Player Section

  private var playerSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      progressSection

      ContentPanelView(audioFile: audioFile)
    }
    .padding()
    .frame(maxHeight: .infinity)
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(audioFile.displayName)
          .font(.title)
          .fontWeight(.semibold)
          .lineLimit(1)

        HStack {
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

          // add a volume control
          volumeControl
            .padding(.trailing, 8)
        }
      }

      Spacer()

      playbackControls
    }
  }

  private var volumeControl: some View {
    Button {
      viewModel.showVolumePopover.toggle()
    } label: {
      Image(systemName: viewModel.playerVolume == 0 ? "speaker.slash" : "speaker.wave.3")
        .font(.title3)
        .frame(width: 24, height: 24)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $viewModel.showVolumePopover, arrowEdge: .bottom) {
      HStack(spacing: 8) {
        Slider(value: $viewModel.playerVolume, in: 0...2) {
          Text("Volume")
        }
        .frame(width: 150)

        HStack(spacing: 2) {
          Text("\(Int(viewModel.playerVolume * 100))%")
          if viewModel.playerVolume > 1.001 {
            Image(systemName: "bolt.fill")
              .foregroundStyle(.orange)
          }
        }
        .frame(width: 50, alignment: .trailing)
        .font(.caption2)
        .foregroundStyle(.secondary)

        Button {
          viewModel.resetVolume()
        } label: {
          Image(systemName: "arrow.counterclockwise")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Reset volume to 100%")
      }
      .padding()
    }
    .help("Volume")
  }

  private var playbackControls: some View {
    HStack(spacing: 8) {
      Button {
        viewModel.seekBack()
      } label: {
        Image(systemName: "gobackward.5")
          .resizable()
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .keyboardShortcut("f", modifiers: [])

      Button {
        viewModel.togglePlayPause()
      } label: {
        Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .resizable()
          .frame(width: 40, height: 40)
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.space, modifiers: [])

      Button {
        viewModel.seekForward()
      } label: {
        Image(systemName: "goforward.10")
          .resizable()
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .keyboardShortcut("g", modifiers: [])
    }
  }

  // MARK: - Progress Section

  private var progressSection: some View {
    AudioProgressView(
      isSeeking: $viewModel.isSeeking,
      seekValue: $viewModel.seekValue,
      wasPlayingBeforeSeek: $viewModel.wasPlayingBeforeSeek
    )
  }
}
