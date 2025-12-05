import SwiftUI
import SwiftData
import Observation

struct PlayerView: View {
    @Environment(AudioPlayerManager.self) private var playerManager
    @Environment(\.modelContext) private var modelContext

    @Bindable var audioFile: AudioFile

    @State private var selectedSegmentID: UUID?
    @AppStorage("segmentSortDescendingByStartTime") private var isSegmentSortDescendingByStartTime: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            progressSection
            loopControls
            Divider()
            segmentsSection
            Spacer()
        }
        .padding()
        .onAppear {
            playerManager.load(audioFile: audioFile)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(audioFile.displayName)
                    .font(.title2)
                    .lineLimit(1)

                Text("A-B loop practice")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let binding = Binding(
                get: { playerManager.currentTime },
                set: { newValue in
                    playerManager.seek(to: newValue)
                }
            )

            Slider(
                value: binding,
                in: 0...(playerManager.duration > 0 ? playerManager.duration : 1),
                step: 0.01
            )

            HStack {
                Text(timeString(from: playerManager.currentTime))
                Spacer()
                Text(timeString(from: playerManager.duration))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var loopControls: some View {
        HStack(spacing: 12) {
            Button("Set A (x)", action: playerManager.setPointA)
                .keyboardShortcut("x", modifiers: [])

            Button("Set B (c)", action: playerManager.setPointB)
                .keyboardShortcut("c", modifiers: [])

            Button("Clear A/B (v)", action: playerManager.clearLoop)
                .keyboardShortcut("v", modifiers: [])

            if let pointA = playerManager.pointA {
                Text("A: \(timeString(from: pointA))")
            }

            if let pointB = playerManager.pointB {
                Text("B: \(timeString(from: pointB))")
            }
            
            Button {
                jumpToPreviousSegment()
            } label: {
                Label("Previous Segment", systemImage: "backward.fill")
            }
            .disabled(segments.isEmpty)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button {
                jumpToNextSegment()
            } label: {
                Label("Next Segment", systemImage: "forward.fill")
            }
            .disabled(segments.isEmpty)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .font(.caption)
    }

    private var segmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Saved Segments")
                    .font(.headline)

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
                .help("Sort segments by start time \(isSegmentSortDescendingByStartTime ? "descending" : "ascending")")

                Button("Save Current A-B") {
                    saveCurrentSegment()
                }
                .keyboardShortcut("b", modifiers: [])
                .disabled(!playerManager.isLooping)
            }

            if segments.isEmpty {
                Text("No segments saved yet. Set A and B, then tap \"Save Current A-B\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List(selection: $selectedSegmentID) {
                    ForEach(segments) { segment in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(segment.label)
                                Text("\(timeString(from: segment.startTime)) - \(timeString(from: segment.endTime))")
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

    private func saveCurrentSegment() {
        guard let pointA = playerManager.pointA,
              let pointB = playerManager.pointB,
              pointB > pointA else {
            return
        }

        if let existingSegment = audioFile.segments.first(
            where: { $0.startTime == pointA && $0.endTime == pointB }
        ) {
            selectedSegmentID = existingSegment.id
            return
        }

        let nextIndex = (audioFile.segments.map(\.index).max() ?? -1) + 1
        let label = "Segment \(nextIndex + 1)"

        let segment = LoopSegment(
            label: label,
            startTime: pointA,
            endTime: pointB,
            index: nextIndex,
            audioFile: audioFile
        )

        audioFile.segments.append(segment)
        selectedSegmentID = segment.id
    }

    private func deleteSegment(_ segment: LoopSegment) {
        guard let indexInArray = audioFile.segments.firstIndex(where: { $0.id == segment.id }) else {
            return
        }

        let removedIndex = audioFile.segments[indexInArray].index

        // 从模型中移除 segment
        let removedSegment = audioFile.segments.remove(at: indexInArray)
        modelContext.delete(removedSegment)

        // 重新整理 index，保持順序連續
        for segment in audioFile.segments where segment.index > removedIndex {
            segment.index -= 1
        }

        // 如果當前選中的就是被刪除的段，清理選中與循環狀態
        if selectedSegmentID == segment.id {
            selectedSegmentID = audioFile.segments.first?.id
            playerManager.clearLoop()
        }
    }

    private var segments: [LoopSegment] {
        audioFile.segments.sorted { first, second in
            if isSegmentSortDescendingByStartTime {
                return first.startTime > second.startTime
            } else {
                return first.startTime < second.startTime
            }
        }
    }

    private func selectSegment(_ segment: LoopSegment) {
        selectedSegmentID = segment.id
        playerManager.apply(segment: segment)
    }

    private func currentSegmentIndex() -> Int {
        if let selectedSegmentID,
           let index = segments.firstIndex(where: { $0.id == selectedSegmentID }) {
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
        guard !segments.isEmpty else {
            return
        }

        let currentIndex = currentSegmentIndex()
        let newIndex = max(0, currentIndex - 1)

        applySegment(at: newIndex)
    }

    private func jumpToNextSegment() {
        guard !segments.isEmpty else {
            return
        }

        let currentIndex = currentSegmentIndex()
        let newIndex = min(segments.count - 1, currentIndex + 1)

        applySegment(at: newIndex)
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


