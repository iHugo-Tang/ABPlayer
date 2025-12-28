import Observation
import SwiftData
import SwiftUI

struct PlayerView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(SessionTracker.self) private var sessionTracker
  @Environment(\.modelContext) private var modelContext

  @Bindable var audioFile: AudioFile

  @State private var showContentPanel: Bool = true
  @AppStorage("segmentSortDescendingByStartTime") private var isSegmentSortDescendingByStartTime:
    Bool = true

  // Progress bar seeking state
  @State private var isSeeking: Bool = false
  @State private var seekValue: Double = 0

  // Persisted panel widths
  @AppStorage("playerSectionWidth") private var playerSectionWidth: Double = 360

  var body: some View {
    GeometryReader { geometry in
      let availableWidth = geometry.size.width

      HStack(spacing: 0) {
        // Left: Player controls + Segments
        playerSection
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
                  // Constrain: min 300, max leaves at least 200 for content panel
                  playerSectionWidth = min(max(newWidth, 300), Double(availableWidth) - 208)
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
    .onAppear {
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
      loopControls
      Divider()
      segmentsSection
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

        Menu {
          ForEach(LoopMode.allCases, id: \.self) { mode in
            Button {
              playerManager.loopMode = mode
            } label: {
              HStack {
                Text(mode.displayName)
                if playerManager.loopMode == mode {
                  Image(systemName: "checkmark")
                }
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

      Spacer()

      playbackControls
    }
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
            // 开始拖拽
            isSeeking = true
          } else {
            // 结束拖拽，执行seek
            playerManager.seek(to: seekValue)
            isSeeking = false
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

  private var loopControls: some View {
    VStack(alignment: .leading) {
      HStack {
        Button("Set A", action: playerManager.setPointA)
          .keyboardShortcut("x", modifiers: [])

        Button("Set B", action: playerManager.setPointB)
          .keyboardShortcut("c", modifiers: [])

        Button("Save") {
          saveCurrentSegment()
        }
        .keyboardShortcut("b", modifiers: [])
        .disabled(!playerManager.hasValidLoopRange)

        Button("Clear", action: playerManager.clearLoop)
          .keyboardShortcut("v", modifiers: [])

        if let pointA = playerManager.pointA {
          Text("A: \(timeString(from: pointA))")
        }

        if let pointB = playerManager.pointB {
          Text("B: \(timeString(from: pointB))")
        }

        Spacer()
      }

    }
    .captionStyle()
  }

  // MARK: - Segments Section

  private var segmentsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Saved Segments")
          .font(.headline)

        HStack {
          Button {
            jumpToPreviousSegment()
          } label: {
            Image(systemName: "backward.end")
          }
          .disabled(audioFile.segments.isEmpty)
          .keyboardShortcut(.leftArrow, modifiers: [])

          Button {
            jumpToNextSegment()
          } label: {
            Image(systemName: "forward.end")
          }
          .disabled(audioFile.segments.isEmpty)
          .keyboardShortcut(.rightArrow, modifiers: [])
        }

        Spacer()

        Button {
          isSegmentSortDescendingByStartTime.toggle()
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "arrow.up.arrow.down")
            Text(isSegmentSortDescendingByStartTime ? "Start ↓" : "Start ↑")
          }
        }
        .buttonStyle(.borderless)
        .help(
          "Sort segments by start time \(isSegmentSortDescendingByStartTime ? "descending" : "ascending")"
        )

      }

      if segments.isEmpty {
        ContentUnavailableView(
          "No segments saved",
          systemImage: "lines.measurement.horizontal",
          description: Text("Set A and B, then tap \"Save Current A-B\".")
        )
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity, alignment: .center)
      } else {
        List(
          selection: Binding(
            get: { playerManager.currentSegmentID },
            set: { newID in
              playerManager.currentSegmentID = newID
              if let segmentID = newID,
                let segment = audioFile.segments.first(where: { $0.id == segmentID })
              {
                playerManager.apply(segment: segment)
              }
            }
          )
        ) {
          ForEach(segments) { segment in
            HStack {
              VStack(alignment: .leading) {
                Text(segment.label)
                Text(
                  "\(timeString(from: segment.startTime)) - \(timeString(from: segment.endTime))"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
              }

              Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
              selectSegment(segment)
            }
            .contextMenu {
              Button(role: .destructive) {
                deleteSegment(segment)
              } label: {
                Label("Delete Segment", systemImage: "trash")
              }
            }
          }
        }
        .frame(minHeight: 120, maxHeight: .infinity)
      }
    }
    .frame(maxHeight: .infinity)
  }

  // MARK: - Segment Actions

  private var segments: [LoopSegment] {
    audioFile.segments.sorted { first, second in
      if isSegmentSortDescendingByStartTime {
        return first.startTime > second.startTime
      } else {
        return first.startTime < second.startTime
      }
    }
  }

  private func saveCurrentSegment() {
    // Delegate to playerManager which handles all the logic
    _ = playerManager.saveCurrentSegment()
  }

  private func deleteSegment(_ segment: LoopSegment) {
    guard let indexInArray = audioFile.segments.firstIndex(where: { $0.id == segment.id }) else {
      return
    }

    let removedIndex = audioFile.segments[indexInArray].index

    let removedSegment = audioFile.segments.remove(at: indexInArray)
    modelContext.delete(removedSegment)

    for segment in audioFile.segments where segment.index > removedIndex {
      segment.index -= 1
    }

    if playerManager.currentSegmentID == segment.id {
      playerManager.currentSegmentID = audioFile.segments.first?.id
      playerManager.clearLoop()
    }
  }

  private func selectSegment(_ segment: LoopSegment) {
    // apply() sets currentSegmentID internally
    playerManager.apply(segment: segment)
  }

  private func currentSegmentIndex() -> Int {
    if let currentSegmentID = playerManager.currentSegmentID,
      let index = segments.firstIndex(where: { $0.id == currentSegmentID })
    {
      return index
    }
    return 0
  }

  private func applySegment(at index: Int) {
    guard segments.indices.contains(index) else {
      return
    }
    let segment = segments[index]
    selectSegment(segment)
  }

  private func jumpToPreviousSegment() {
    guard !segments.isEmpty else { return }
    let currentIndex = currentSegmentIndex()
    let newIndex = max(0, currentIndex - 1)
    applySegment(at: newIndex)
  }

  private func jumpToNextSegment() {
    guard !segments.isEmpty else { return }
    let currentIndex = currentSegmentIndex()
    let newIndex = min(segments.count - 1, currentIndex + 1)
    applySegment(at: newIndex)
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
