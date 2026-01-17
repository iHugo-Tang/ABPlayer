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

  @AppStorage("videoPlayerShowContentPanel") private var showContentPanel: Bool = true

  // Progress bar seeking state
  @State private var isSeeking: Bool = false
  @State private var seekValue: Double = 0
  @State private var wasPlayingBeforeSeek: Bool = false

  // Persisted panel widths - Independent from AudioPlayerView
  let minWidthOfPlayerSection: CGFloat = 480
  let minWidthOfContentPanel: CGFloat = 300
  let dividerWidth: CGFloat = 8
  @AppStorage("videoPlayerSectionWidth") private var videoPlayerSectionWidth: Double = 480  // Wider default for video
  @State private var draggingWidth: Double?  // Temporary width during drag, avoids I/O on every frame

  // Volume Persistence
  @AppStorage("playerVolume") private var playerVolume: Double = 1.0
  @State private var volumeDebounceTask: Task<Void, Never>?

  // Loop Mode Persistence
  @AppStorage("playerLoopMode") private var storedLoopMode: String = LoopMode.none.rawValue

  var body: some View {
    GeometryReader { geometry in
      let availableWidth = geometry.size.width
      let effectiveWidth = clampWidth(
        draggingWidth ?? videoPlayerSectionWidth, availableWidth: availableWidth)

      HStack(spacing: 0) {
        // Left: Video Player + Controls
        videoSection
          .frame(minWidth: minWidthOfPlayerSection)
          .frame(width: showContentPanel ? effectiveWidth : nil)

        // Right: Content panel (PDF, Subtitles only) - takes remaining space
        if showContentPanel {
          // Draggable divider
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
                    (draggingWidth ?? videoPlayerSectionWidth) + value.translation.width
                  draggingWidth = clampWidth(newWidth, availableWidth: availableWidth)
                }
                .onEnded { _ in
                  if let finalWidth = draggingWidth {
                    videoPlayerSectionWidth = finalWidth  // Persist only once at the end
                  }
                  draggingWidth = nil
                }
            )

          // SegmentsSection takes remaining space
          SegmentsSection(audioFile: audioFile)
            .frame(minWidth: minWidthOfContentPanel, maxWidth: .infinity)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
      .animation(.easeInOut(duration: 0.25), value: showContentPanel)
      .onChange(of: showContentPanel) { _, isShowing in
        if isShowing {
          videoPlayerSectionWidth = clampWidth(
            videoPlayerSectionWidth, availableWidth: availableWidth)
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        HStack(spacing: 6) {
          Image(systemName: "timer")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
          Text(timeString(from: Double(sessionTracker.displaySeconds)))
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .help("Session practice time")
      }

      ToolbarItem(placement: .primaryAction) {
        Button {
          showContentPanel.toggle()
        } label: {
          Label(
            showContentPanel ? "Hide Panel" : "Show Panel",
            systemImage: showContentPanel ? "sidebar.trailing" : "sidebar.trailing"
          )
        }
        .help(showContentPanel ? "Hide content panel" : "Show content panel")
      }
    }
    .onChange(of: playerVolume) { _, newValue in
      volumeDebounceTask?.cancel()
      volumeDebounceTask = Task {
        try? await Task.sleep(for: .milliseconds(100))
        guard !Task.isCancelled else { return }
        playerManager.setVolume(Float(newValue))
      }
    }
    .onChange(of: playerManager.loopMode) { _, newValue in
      storedLoopMode = newValue.rawValue
    }
    .task {
      // Restore persisted loop mode
      if let mode = LoopMode(rawValue: storedLoopMode) {
        playerManager.loopMode = mode
      }
      if playerManager.currentFile?.id != audioFile.id,
        playerManager.currentFile != nil
      {
        await playerManager.load(audioFile: audioFile)
      }
    }
  }

  // MARK: - Video Section

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
        progressRow
        controlsRow
        Divider()
        ContentPanelView(audioFile: audioFile)
      }
//      .padding()
      .background(.thinMaterial)
    }
  }

  // MARK: - Progress Row

  private var progressRow: some View {
    VideoProgressView(
      isSeeking: $isSeeking,
      seekValue: $seekValue,
      wasPlayingBeforeSeek: $wasPlayingBeforeSeek
    )
  }

  // MARK: - Controls Row

  private var controlsRow: some View {
    ZStack(alignment: .center) {
      HStack {
        // Loop Mode & Volume
        HStack(spacing: 12) {
          Menu {
            ForEach(LoopMode.allCases, id: \.self) { mode in
              Button {
                playerManager.loopMode = mode
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

          VolumeControl(playerVolume: $playerVolume)
        }

        Spacer()

        VideoTimeDisplay(isSeeking: isSeeking, seekValue: seekValue)
      }

      // Playback Controls
      HStack(spacing: 16) {
        Button {
          let targetTime = playerManager.currentTime - 5
          playerManager.seek(to: targetTime)
        } label: {
          Image(systemName: "gobackward.5")
            .font(.title)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("f", modifiers: [])

        Button {
          playerManager.togglePlayPause()
        } label: {
          Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: 36))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.space, modifiers: [])

        Button {
          let targetTime = playerManager.currentTime + 10
          playerManager.seek(to: targetTime)
        } label: {
          Image(systemName: "goforward.10")
            .font(.title)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("g", modifiers: [])
      }
    }
  }

  // MARK: - Layout Helpers

  private func clampWidth(_ width: Double, availableWidth: CGFloat) -> Double {
    let maxWidth = Double(availableWidth) - dividerWidth - minWidthOfContentPanel
    return min(max(width, minWidthOfPlayerSection), max(maxWidth, minWidthOfPlayerSection))
  }

  // MARK: - Helpers

  private func timeString(from value: Double) -> String {
    guard value.isFinite, value >= 0 else {
      return "0:00"
    }

    let totalSeconds = Int(value.rounded())
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    // Optional: Handle hours if needed, but minutes:seconds is usually fine for short clips
    // For movies, might want hours.
    if minutes >= 60 {
      let hours = minutes / 60
      let remainingMinutes = minutes % 60
      return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
    }

    return String(format: "%d:%02d", minutes, seconds)
  }
}
