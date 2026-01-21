import Observation
import SwiftData
import SwiftUI

struct SegmentsSection: View {
  @Environment(PlayerManager.self) private var playerManager
  @Environment(\.modelContext) private var modelContext

  @Bindable var audioFile: ABFile

  @AppStorage("segmentSortDescendingByStartTime") private var isSegmentSortDescendingByStartTime:
    Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        // Loop Controls Group
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
        }
        .fixedSize(horizontal: true, vertical: false)

        HStack {
          if let pointA = playerManager.pointA {
            Text("A: \(timeString(from: pointA))")
              .foregroundStyle(.secondary)
          }

          if let pointB = playerManager.pointB {
            Text("B: \(timeString(from: pointB))")
              .foregroundStyle(.secondary)
          }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .frame(height: 16)  // Reserve height to avoid layout jump
      }
      .buttonStyle(.bordered)
      .controlSize(.small)

      HStack {
        Text("Saved Segments".uppercased())
          .font(.headline)

        Spacer()

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

        Button {
          isSegmentSortDescendingByStartTime.toggle()
        } label: {
          HStack(spacing: 4) {
            // Image(systemName: "arrow.up.arrow.down")
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
