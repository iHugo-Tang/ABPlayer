import AVKit
import Observation
import SwiftData
import SwiftUI

struct VideoPlayerView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(SessionTracker.self) private var sessionTracker
  @Environment(\.modelContext) private var modelContext

  @Bindable var audioFile: AudioFile

  @State private var showContentPanel: Bool = true

  // Progress bar seeking state
  @State private var isSeeking: Bool = false
  @State private var seekValue: Double = 0
  @State private var wasPlayingBeforeSeek: Bool = false

  // Persisted panel widths - Independent from AudioPlayerView
  let minWidthOfPlayerSection: CGFloat = 480
  let minWidthOfContentPanel: CGFloat = 300
  let dividerWidth: CGFloat = 8
  @AppStorage("videoPlayerSectionWidth") private var videoPlayerSectionWidth: Double = 480  // Wider default for video

  // Volume Persistence
  @AppStorage("playerVolume") private var playerVolume: Double = 1.0
  @State private var showVolumePopover: Bool = false
  @State private var volumeDebounceTask: Task<Void, Never>?

  // Loop Mode Persistence
  @AppStorage("playerLoopMode") private var storedLoopMode: String = LoopMode.none.rawValue

  var body: some View {
    GeometryReader { geometry in
      let availableWidth = geometry.size.width
      let effectiveWidth = clampWidth(videoPlayerSectionWidth, availableWidth: availableWidth)

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
                  let newWidth = videoPlayerSectionWidth + value.translation.width
                  videoPlayerSectionWidth = clampWidth(newWidth, availableWidth: availableWidth)
                  print(
                    "[Debug] Video player section width: \(videoPlayerSectionWidth) effectiveWidth: \(effectiveWidth)"
                  )
                }
            )

          // ContentPanelView takes remaining space
          ContentPanelView(audioFile: audioFile)
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
          Text(timeString(from: sessionTracker.totalSeconds))
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

    .onAppear {
      // Restore persisted loop mode
      if let mode = LoopMode(rawValue: storedLoopMode) {
        playerManager.loopMode = mode
      }
      if playerManager.currentFile?.id != audioFile.id,
        playerManager.currentFile != nil
      {
        Task {
          await playerManager.load(audioFile: audioFile)
        }
      }
    }

  }

  // MARK: - Video Section

  private var videoSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 1. Video Player Area
      NativeVideoPlayer(player: playerManager.player)
        .aspectRatio(16 / 9, contentMode: .fit)
        .layoutPriority(1)

      // 2. Controls Area (Fixed height)
      VStack(spacing: 12) {
        progressRow
        controlsRow
        Divider()
        SegmentsSection(audioFile: audioFile)
      }
      .padding()
      .background(.thinMaterial)
    }
  }

  // MARK: - Progress Row

  private var progressRow: some View {
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

  // MARK: - Controls Row

  private var controlsRow: some View {
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
          .font(.title2)
          .foregroundStyle(playerManager.loopMode != .none ? .blue : .primary)
        }
        .buttonStyle(.plain)
        .help("Loop mode: \(playerManager.loopMode.displayName)")

        volumeControl
      }

      Spacer()

      // Playback Controls
      HStack(spacing: 16) {
        Button {
          let targetTime = playerManager.currentTime - 5
          playerManager.seek(to: targetTime)
        } label: {
          Image(systemName: "gobackward.5")
            .font(.title2)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("f", modifiers: [])

        Button {
          playerManager.togglePlayPause()
        } label: {
          Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: 32))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.space, modifiers: [])

        Button {
          let targetTime = playerManager.currentTime + 10
          playerManager.seek(to: targetTime)
        } label: {
          Image(systemName: "goforward.10")
            .font(.title2)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("g", modifiers: [])
      }

      Spacer()

      // Time & Duration
      HStack(spacing: 4) {
        Text(timeString(from: isSeeking ? seekValue : playerManager.currentTime))
        Text("/")
          .foregroundStyle(.secondary)
        Text(timeString(from: playerManager.duration))
      }
      .font(.body.monospacedDigit())
    }
  }

  private var volumeControl: some View {
    Button {
      showVolumePopover.toggle()
    } label: {
      Image(systemName: playerVolume == 0 ? "speaker.slash" : "speaker.wave.3")
        .font(.title3)
        .frame(width: 24, height: 24)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showVolumePopover, arrowEdge: .bottom) {
      HStack(spacing: 8) {
        Slider(value: $playerVolume, in: 0...2) {
          Text("Volume")
        }
        .frame(width: 150)

        HStack(spacing: 2) {
          Text("\(Int(playerVolume * 100))%")
          if playerVolume > 1.001 {
            Image(systemName: "bolt.fill")
              .foregroundStyle(.orange)
          }
        }
        .frame(width: 50, alignment: .trailing)
        .font(.caption2)
        .foregroundStyle(.secondary)

        Button {
          playerVolume = 1.0
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
    .onAppear {
      playerManager.setVolume(Float(playerVolume))
    }
    .help("Volume")
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
