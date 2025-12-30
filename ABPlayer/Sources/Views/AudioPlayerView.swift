import Observation
import SwiftData
import SwiftUI

struct AudioPlayerView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(SessionTracker.self) private var sessionTracker
  @Environment(\.modelContext) private var modelContext

  @Bindable var audioFile: AudioFile

  @State private var showContentPanel: Bool = true

  // Progress bar seeking state
  @State private var isSeeking: Bool = false
  @State private var seekValue: Double = 0
  @State private var wasPlayingBeforeSeek: Bool = false

  // Persisted panel widths
  let minWidthOfPlayerSection: CGFloat = 380
  @AppStorage("playerSectionWidth") private var playerSectionWidth: Double = 380

  // Volume Persistence
  @AppStorage("playerVolume") private var playerVolume: Double = 1.0
  @State private var showVolumePopover: Bool = false

  // Loop Mode Persistence
  @AppStorage("playerLoopMode") private var storedLoopMode: String = LoopMode.none.rawValue

  var body: some View {
    GeometryReader { geometry in
      let availableWidth = geometry.size.width

      HStack(spacing: 0) {
        // Left: Player controls + Segments
        playerSection
          .frame(minWidth: minWidthOfPlayerSection)
          .frame(width: showContentPanel ? playerSectionWidth : nil)

        // Right: Content panel (PDF, Subtitles only) - takes remaining space
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
                  // Dragging right increases playerSection, left decreases
                  let newWidth = playerSectionWidth + value.translation.width
                  // Constrain: min minWidthOfPlayerSection, max leaves at least 200 for content panel
                  playerSectionWidth = min(
                    max(newWidth, minWidthOfPlayerSection), Double(availableWidth) - 208)
                }
            )

          // ContentPanelView takes remaining space
          ContentPanelView(audioFile: audioFile)
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
      .animation(.easeInOut(duration: 0.25), value: showContentPanel)
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
      playerManager.setVolume(Float(newValue))
    }
    .onChange(of: playerManager.loopMode) { _, newValue in
      storedLoopMode = newValue.rawValue
    }
    .onAppear {
      // Restore persisted loop mode
      if let mode = LoopMode(rawValue: storedLoopMode) {
        playerManager.loopMode = mode
      }
      if playerManager.currentFile?.id == audioFile.id,
        playerManager.currentFile != nil
      {
        playerManager.currentFile = audioFile
      } else {
        Task { await playerManager.load(audioFile: audioFile) }
      }
    }
  }

  // MARK: - Player Section

  private var playerSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      progressSection

      Divider()
      SegmentsSection(audioFile: audioFile)
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
        .frame(width: 20, height: 20)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showVolumePopover, arrowEdge: .bottom) {
      VStack(spacing: 8) {
        Slider(value: $playerVolume, in: 0...1) {
          Text("Volume")
        }
        .frame(width: 150)

        Text("\(Int(playerVolume * 100))%")
          .font(.caption2)
          .foregroundStyle(.secondary)
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
    VStack(alignment: .leading, spacing: 8) {
      Slider(
        value: Binding(
          get: {
            // 拖拽时使用本地值，否则使用实际播放时间
            isSeeking ? seekValue : playerManager.currentTime
          },
          set: { newValue in
            seekValue = newValue
            // 拖拽中不执行seek，松手后统一执行
          }
        ),
        in: 0...(playerManager.duration > 0 ? playerManager.duration : 1),
        onEditingChanged: { editing in
          if editing {
            // 开始拖拽/点击：暂停播放以防止时间更新导致闪烁
            isSeeking = true
            wasPlayingBeforeSeek = playerManager.isPlaying
            if playerManager.isPlaying {
              playerManager.togglePlayPause()
            }
          } else {
            // 结束拖拽/点击：跳转到指定时间，然后恢复播放
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

  // MARK: - Loop Controls

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
