import SwiftUI

/// Displays synchronized subtitles with current playback position highlighted
struct SubtitleView: View {
  @Environment(AudioPlayerManager.self) private var playerManager

  let cues: [SubtitleCue]

  @State private var currentCueID: UUID?

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(cues) { cue in
            SubtitleCueRow(
              cue: cue,
              isActive: cue.id == currentCueID,
              onTap: {
                playerManager.seek(to: cue.startTime)
              }
            )
            .id(cue.id)
          }
        }
        .padding()
      }
      .onChange(of: currentCueID) { _, newValue in
        if let id = newValue {
          withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
      }
    }
    .task {
      await trackCurrentCue()
    }
  }

  private func trackCurrentCue() async {
    while !Task.isCancelled {
      let currentTime = playerManager.currentTime
      let activeCue = cues.first { cue in
        currentTime >= cue.startTime && currentTime < cue.endTime
      }

      if activeCue?.id != currentCueID {
        await MainActor.run {
          currentCueID = activeCue?.id
        }
      }

      try? await Task.sleep(for: .milliseconds(100))
    }
  }
}

// MARK: - Cue Row

private struct SubtitleCueRow: View {
  let cue: SubtitleCue
  let isActive: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 12) {
        Text(timeString(from: cue.startTime))
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
          .frame(width: 48, alignment: .trailing)

        Text(cue.text)
          .font(.body)
          .foregroundStyle(isActive ? .primary : .secondary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .animation(.easeInOut(duration: 0.15), value: isActive)
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

// MARK: - Empty State

struct SubtitleEmptyView: View {
  var body: some View {
    ContentUnavailableView(
      "No Subtitles",
      systemImage: "text.bubble",
      description: Text("This audio file has no associated subtitle file")
    )
  }
}
