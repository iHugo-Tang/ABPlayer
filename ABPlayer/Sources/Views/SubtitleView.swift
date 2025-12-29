import SwiftUI

/// Displays synchronized subtitles with current playback position highlighted
struct SubtitleView: View {
  @Environment(AudioPlayerManager.self) private var playerManager

  let cues: [SubtitleCue]
  /// Binding to expose countdown seconds to parent (nil when not paused)
  @Binding var countdownSeconds: Int?

  /// Duration for resume countdown in seconds
  private static let pauseDuration = 3

  @State private var currentCueID: UUID?
  /// Indicates user is manually scrolling; pauses auto-scroll and highlight tracking
  @State private var isUserScrolling = false
  /// Task to handle countdown and resume tracking
  @State private var scrollResumeTask: Task<Void, Never>?

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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
      .onScrollPhaseChange { _, newPhase in
        handleScrollPhaseChange(newPhase)
      }
      .onChange(of: currentCueID) { _, newValue in
        // Only auto-scroll when not user scrolling
        guard !isUserScrolling, let id = newValue else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
          proxy.scrollTo(id, anchor: .center)
        }
      }
      .onChange(of: cues) { _, _ in
        // Reset all scrolling states when cues change
        scrollResumeTask?.cancel()
        scrollResumeTask = nil
        isUserScrolling = false
        currentCueID = nil
        countdownSeconds = nil
      }
    }
    .task {
      await trackCurrentCue()
    }
  }

  private func handleScrollPhaseChange(_ phase: ScrollPhase) {
    switch phase {
    case .interacting:
      // User started scrolling - pause tracking and start/restart countdown
      scrollResumeTask?.cancel()
      isUserScrolling = true
      countdownSeconds = Self.pauseDuration

      // Start unified countdown and resume task
      scrollResumeTask = Task {
        for remaining in (0..<Self.pauseDuration).reversed() {
          try? await Task.sleep(for: .seconds(1))
          guard !Task.isCancelled else { return }
          countdownSeconds = remaining > 0 ? remaining : nil
        }
        isUserScrolling = false
      }

    default:
      break
    }
  }

  private func trackCurrentCue() async {
    while !Task.isCancelled {
      // Skip tracking when user is manually scrolling
      if !isUserScrolling {
        let currentTime = playerManager.currentTime
        let activeCue = cues.first { cue in
          currentTime >= cue.startTime && currentTime < cue.endTime
        }

        if activeCue?.id != currentCueID {
          await MainActor.run {
            currentCueID = activeCue?.id
          }
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

  @State private var isHovered = false

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(timeString(from: cue.startTime))
          .font(.system(.subheadline, design: .monospaced))
          .foregroundStyle(isActive ? .primary : .tertiary)
          .frame(width: 52, alignment: .trailing)

        Text(cue.text)
          .font(.system(.title3))
          .foregroundStyle(isActive ? .primary : .secondary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.vertical, 14)
      .padding(.horizontal, 12)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(backgroundColor)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(isActive ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
      }
    }
    .animation(.easeInOut(duration: 0.2), value: isActive)
  }

  private var backgroundColor: Color {
    if isActive {
      return Color.accentColor.opacity(0.12)
    } else if isHovered {
      return Color.primary.opacity(0.04)
    } else {
      return Color.clear
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
