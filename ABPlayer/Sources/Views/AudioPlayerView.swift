import Observation
import SwiftData
import SwiftUI

// MARK: - Isolated Progress View (prevents parent re-renders on currentTime updates)

private struct PlaybackProgressView: View {
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

// MARK: - Audio Player View

struct AudioPlayerView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(SessionTracker.self) private var sessionTracker
  @Environment(\.modelContext) private var modelContext

  @Bindable var audioFile: AudioFile

  @AppStorage("audioPlayerShowContentPanel") private var showContentPanel: Bool = true

  // Progress bar seeking state
  @State private var isSeeking: Bool = false
  @State private var seekValue: Double = 0
  @State private var wasPlayingBeforeSeek: Bool = false

  // Persisted panel widths
  let minWidthOfPlayerSection: CGFloat = 380
  let minWidthOfContentPanel: CGFloat = 300
  let dividerWidth: CGFloat = 8
  @AppStorage("playerSectionWidth") private var playerSectionWidth: Double = 380
  @State private var draggingWidth: Double?  // Temporary width during drag, avoids I/O on every frame

  // Volume Persistence
  @AppStorage("playerVolume") private var playerVolume: Double = 1.0
  @State private var showVolumePopover: Bool = false
  @State private var volumeDebounceTask: Task<Void, Never>?

  // Loop Mode Persistence
  @AppStorage("playerLoopMode") private var storedLoopMode: String = LoopMode.none.rawValue

  var body: some View {
    GeometryReader { geometry in
      let availableWidth = geometry.size.width
      let effectiveWidth = clampWidth(
        draggingWidth ?? playerSectionWidth, availableWidth: availableWidth)

      HStack(spacing: 0) {
        // Left: Player controls + Content (Transcription/PDF)
        playerSection
          .frame(minWidth: minWidthOfPlayerSection)
          .frame(width: showContentPanel ? effectiveWidth : nil)

        // Right: Segments panel - takes remaining space
        if showContentPanel {
          // Draggable divider for playerSection
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
                  let newWidth = (draggingWidth ?? playerSectionWidth) + value.translation.width
                  draggingWidth = clampWidth(newWidth, availableWidth: availableWidth)
                }
                .onEnded { _ in
                  if let finalWidth = draggingWidth {
                    playerSectionWidth = finalWidth  // Persist only once at the end
                  }
                  draggingWidth = nil
                }
            )

          // SegmentsSection takes remaining space
          SegmentsSection(audioFile: audioFile)
            .frame(minWidth: minWidthOfContentPanel, maxWidth: .infinity)
            .padding()
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
      .animation(.easeInOut(duration: 0.25), value: showContentPanel)
      .onChange(of: showContentPanel) { _, isShowing in
        if isShowing {
          playerSectionWidth = clampWidth(playerSectionWidth, availableWidth: availableWidth)
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
            showContentPanel ? "Hide Segments" : "Show Segments",
            systemImage: showContentPanel ? "sidebar.trailing" : "sidebar.trailing"
          )
        }
        .help(showContentPanel ? "Hide segments panel" : "Show segments panel")
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
      // Sync initial volume
      playerManager.setVolume(Float(playerVolume))
    }
    .help("Volume")
  }

  private var playbackControls: some View {
    HStack(spacing: 8) {
      Button {
        let targetTime = playerManager.currentTime - 5
        playerManager.seek(to: targetTime)
      } label: {
        Image(systemName: "gobackward.5")
          .resizable()
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .keyboardShortcut("f", modifiers: [])

      Button {
        playerManager.togglePlayPause()
      } label: {
        Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .resizable()
          .frame(width: 40, height: 40)
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.space, modifiers: [])

      Button {
        let targetTime = playerManager.currentTime + 10
        playerManager.seek(to: targetTime)
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
    PlaybackProgressView(
      isSeeking: $isSeeking,
      seekValue: $seekValue,
      wasPlayingBeforeSeek: $wasPlayingBeforeSeek
    )
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

    return String(format: "%d:%02d", minutes, seconds)
  }
}
