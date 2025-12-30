import SwiftData
import SwiftUI

/// Displays synchronized subtitles with current playback position highlighted
struct SubtitleView: View {
  @Environment(AudioPlayerManager.self) private var playerManager

  let cues: [SubtitleCue]
  /// Binding to expose countdown seconds to parent (nil when not paused)
  @Binding var countdownSeconds: Int?
  /// Font size for subtitle text
  let fontSize: Double

  /// Duration for resume countdown in seconds
  private static let pauseDuration = 3

  @State private var currentCueID: UUID?
  /// Indicates user is manually scrolling; pauses auto-scroll and highlight tracking
  @State private var isUserScrolling = false
  /// Task to handle countdown and resume tracking
  @State private var scrollResumeTask: Task<Void, Never>?
  /// Currently selected word info (cueID, wordIndex) - lifted to parent for cross-row dismiss
  @State private var selectedWord: (cueID: UUID, wordIndex: Int)?
  /// Tracks if playback was playing before word interaction (for cross-row dismiss)
  @State private var wasPlayingBeforeWordInteraction = false

  var body: some View {
    ZStack(alignment: .topTrailing) {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(cues) { cue in
              SubtitleCueRow(
                cue: cue,
                isActive: cue.id == currentCueID,
                fontSize: fontSize,
                selectedWordIndex: selectedWord?.cueID == cue.id ? selectedWord?.wordIndex : nil,
                onWordSelected: { wordIndex in
                  handleWordSelection(wordIndex: wordIndex, cueID: cue.id)
                },
                onTap: {
                  dismissWord()
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
          guard !isUserScrolling, let id = newValue else { return }
          withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
        .onChange(of: cues) { _, _ in
          scrollResumeTask?.cancel()
          scrollResumeTask = nil
          isUserScrolling = false
          currentCueID = nil
          countdownSeconds = nil
          selectedWord = nil
        }
      }

      // Countdown indicator overlay in top right corner
      if let countdown = countdownSeconds {
        CountdownRingView(countdown: countdown, total: Self.pauseDuration)
          .padding(12)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.2), value: countdownSeconds != nil)
    .task {
      await trackCurrentCue()
    }
  }

  private func handleWordSelection(wordIndex: Int?, cueID: UUID) {
    if let wordIndex {
      if selectedWord == nil {
        wasPlayingBeforeWordInteraction = playerManager.isPlaying
        if playerManager.isPlaying {
          playerManager.pause()
        }
      }
      selectedWord = (cueID, wordIndex)
    } else {
      dismissWord()
    }
  }

  private func dismissWord() {
    guard selectedWord != nil else { return }
    selectedWord = nil
    if wasPlayingBeforeWordInteraction {
      playerManager.play()
      wasPlayingBeforeWordInteraction = false
    }
  }

  private func handleScrollPhaseChange(_ phase: ScrollPhase) {
    guard case .interacting = phase else { return }

    scrollResumeTask?.cancel()
    isUserScrolling = true
    countdownSeconds = Self.pauseDuration

    scrollResumeTask = Task {
      for remaining in (0..<Self.pauseDuration).reversed() {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        countdownSeconds = remaining > 0 ? remaining : nil
      }
      isUserScrolling = false
    }
  }

  private func trackCurrentCue() async {
    // Small epsilon for floating-point comparison to avoid precision issues at boundaries
    let epsilon: Double = 0.001

    while !Task.isCancelled {
      if !isUserScrolling {
        let currentTime = playerManager.currentTime
        let activeCue = findActiveCue(at: currentTime, epsilon: epsilon)

        if activeCue?.id != currentCueID {
          await MainActor.run {
            currentCueID = activeCue?.id
          }
        }
      }

      try? await Task.sleep(for: .milliseconds(100))
    }
  }

  /// Uses binary search to find the cue containing the given time
  /// - Parameters:
  ///   - time: The current playback time
  ///   - epsilon: Small tolerance for floating-point comparison
  /// - Returns: The active cue, or nil if none contains the time
  private func findActiveCue(at time: Double, epsilon: Double) -> SubtitleCue? {
    guard !cues.isEmpty else { return nil }

    // Binary search to find the cue whose startTime is <= time
    var low = 0
    var high = cues.count - 1
    var result: Int? = nil

    while low <= high {
      let mid = (low + high) / 2
      if cues[mid].startTime <= time + epsilon {
        result = mid
        low = mid + 1
      } else {
        high = mid - 1
      }
    }

    // Verify the found cue actually contains the current time
    if let index = result {
      let cue = cues[index]
      // Use epsilon to handle boundary precision: time should be >= startTime - epsilon and < endTime + epsilon
      // But prefer strict < endTime to avoid overlapping with next cue
      if time >= cue.startTime - epsilon && time < cue.endTime {
        return cue
      }
    }

    return nil
  }
}

// MARK: - Cue Row

private struct SubtitleCueRow: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var vocabularies: [Vocabulary]

  let cue: SubtitleCue
  let isActive: Bool
  let fontSize: Double
  let selectedWordIndex: Int?
  let onWordSelected: (Int?) -> Void
  let onTap: () -> Void

  @State private var isHovered = false
  @State private var hoveredWordIndex: Int?
  @State private var isMenuHovered = false

  private var words: [String] {
    cue.text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
  }

  /// Normalize a word for vocabulary lookup (lowercase, trim punctuation)
  private func normalize(_ word: String) -> String {
    word.lowercased().trimmingCharacters(in: .punctuationCharacters)
  }

  /// Find vocabulary entry for a word
  private func findVocabulary(for word: String) -> Vocabulary? {
    let normalized = normalize(word)
    return vocabularies.first { $0.word == normalized }
  }

  /// Get difficulty level for a word (nil if not in vocabulary or level is 0)
  private func difficultyLevel(for word: String) -> Int? {
    guard let vocab = findVocabulary(for: word), vocab.difficultyLevel > 0 else {
      return nil
    }
    return vocab.difficultyLevel
  }

  /// Increment forgot count for a word (creates new entry if not exists)
  private func incrementForgotCount(for word: String) {
    if let vocab = findVocabulary(for: word) {
      vocab.forgotCount += 1
    } else {
      let newVocab = Vocabulary(word: normalize(word), forgotCount: 1)
      modelContext.insert(newVocab)
    }
  }

  /// Increment remembered count for a word (only if already in vocabulary)
  private func incrementRememberedCount(for word: String) {
    // Only increment if word exists - you can't "remember" a word you never "forgot"
    if let vocab = findVocabulary(for: word) {
      vocab.rememberedCount += 1
    }
  }

  /// Remove vocabulary entry for a word
  private func removeVocabulary(for word: String) {
    if let vocab = findVocabulary(for: word) {
      modelContext.delete(vocab)
    }
  }

  /// Get forgot count for a word (0 if not in vocabulary)
  private func forgotCount(for word: String) -> Int {
    findVocabulary(for: word)?.forgotCount ?? 0
  }

  /// Get remembered count for a word (0 if not in vocabulary)
  private func rememberedCount(for word: String) -> Int {
    findVocabulary(for: word)?.rememberedCount ?? 0
  }

  /// Get creation date for a word (nil if not in vocabulary)
  private func createdAt(for word: String) -> Date? {
    findVocabulary(for: word)?.createdAt
  }

  /// Get color for a word in non-active rows (secondary or difficulty color)
  private func wordColor(for word: String) -> Color {
    guard let level = difficultyLevel(for: word) else {
      return .secondary
    }
    switch level {
    case 1: return .green
    case 2: return .yellow
    default: return .red
    }
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(timeString(from: cue.startTime))
        .font(.system(.subheadline, design: .monospaced))
        .foregroundStyle(isActive ? .primary : .tertiary)
        .frame(width: 52, alignment: .trailing)

      if isActive {
        FlowLayout(alignment: .leading, spacing: 4) {
          ForEach(Array(words.enumerated()), id: \.offset) { index, word in
            InteractiveWordView(
              word: word,
              difficultyLevel: difficultyLevel(for: word),
              isHovered: hoveredWordIndex == index,
              isSelected: selectedWordIndex == index,
              onHoverChanged: { isHovering in
                hoveredWordIndex = isHovering ? index : nil
                if isHovering && selectedWordIndex != nil && selectedWordIndex != index
                  && !isMenuHovered
                {
                  onWordSelected(nil)
                }
              },
              onTap: {
                onWordSelected(selectedWordIndex == index ? nil : index)
              },
              onDismiss: {
                onWordSelected(nil)
              },
              onForgot: { cleaned in
                incrementForgotCount(for: cleaned)
              },
              onRemembered: { cleaned in
                incrementRememberedCount(for: cleaned)
              },
              onRemove: { cleaned in
                removeVocabulary(for: cleaned)
              },
              onMenuHoverChanged: { hovering in
                isMenuHovered = hovering
              },
              forgotCount: forgotCount(for: word),
              rememberedCount: rememberedCount(for: word),
              createdAt: createdAt(for: word),
              fontSize: fontSize
            )
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear {
          onWordSelected(nil)
        }
      } else {
        FlowLayout(alignment: .leading, spacing: 4) {
          ForEach(Array(words.enumerated()), id: \.offset) { _, word in
            Text(word)
              .font(.system(size: fontSize))
              .foregroundStyle(wordColor(for: word))
              .padding(.horizontal, 2)
              .padding(.vertical, 1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
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
    .contentShape(Rectangle())
    .onTapGesture {
      if !isActive {
        onTap()
      } else if selectedWordIndex != nil && !isMenuHovered {
        onWordSelected(nil)
      }
    }
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
      }
    }
    .onChange(of: isActive) { _, newValue in
      if !newValue && selectedWordIndex != nil {
        onWordSelected(nil)
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
    guard value.isFinite, value >= 0 else { return "0:00" }
    let totalSeconds = Int(value.rounded())
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
  }
}

// MARK: - Interactive Word View

private struct InteractiveWordView: View {
  let word: String
  let difficultyLevel: Int?
  let isHovered: Bool
  let isSelected: Bool
  let onHoverChanged: (Bool) -> Void
  let onTap: () -> Void
  let onDismiss: () -> Void
  let onForgot: (String) -> Void
  let onRemembered: (String) -> Void
  let onRemove: (String) -> Void
  let onMenuHoverChanged: (Bool) -> Void
  let forgotCount: Int
  let rememberedCount: Int
  let createdAt: Date?
  let fontSize: Double

  private var cleanedWord: String {
    word.lowercased().trimmingCharacters(in: .punctuationCharacters)
  }

  private var isHighlighted: Bool { isHovered || isSelected }

  /// Color based on difficulty level: 1=green, 2=yellow, >=3=red
  private var difficultyColor: Color? {
    guard let level = difficultyLevel, level > 0 else { return nil }
    switch level {
    case 1: return .green
    case 2: return .yellow
    default: return .red
    }
  }

  private var foregroundColor: Color {
    if isHighlighted {
      return Color.accentColor
    }
    return difficultyColor ?? .primary
  }

  var body: some View {
    Text(word)
      .font(.system(size: fontSize))
      .foregroundStyle(foregroundColor)
      .padding(.horizontal, 2)
      .padding(.vertical, 1)
      .background(
        RoundedRectangle(cornerRadius: 4)
          .fill(isHighlighted ? Color.accentColor.opacity(0.15) : Color.clear)
      )
      .onHover { onHoverChanged($0) }
      .onTapGesture { onTap() }
      .popover(
        isPresented: Binding(
          get: { isSelected },
          set: { if !$0 { onDismiss() } }
        ),
        arrowEdge: .bottom
      ) {
        WordMenuView(
          word: word, onDismiss: onDismiss, onForgot: onForgot,
          onRemembered: onRemembered, onRemove: onRemove,
          onHoverChanged: onMenuHoverChanged,
          forgotCount: forgotCount, rememberedCount: rememberedCount,
          createdAt: createdAt)
      }
  }
}

// MARK: - Word Menu

private struct WordMenuView: View {
  let word: String
  let onDismiss: () -> Void
  let onForgot: (String) -> Void
  let onRemembered: (String) -> Void
  let onRemove: (String) -> Void
  let onHoverChanged: (Bool) -> Void
  let forgotCount: Int
  let rememberedCount: Int
  let createdAt: Date?

  private var canRemember: Bool {
    guard forgotCount > 0, let createdAt = createdAt else { return false }
    // Must be at least 12 hours since creation
    return Date().timeIntervalSince(createdAt) >= 12 * 3600
  }

  private var cleanedWord: String {
    word.lowercased().trimmingCharacters(in: .punctuationCharacters)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Group {
        MenuButton(label: "Copy", systemImage: "doc.on.doc") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(cleanedWord, forType: .string)
          onDismiss()
        }

        MenuButton(
          label: "Forgot" + (forgotCount > 0 ? " (\(forgotCount))" : ""),
          systemImage: "xmark.circle"
        ) {
          onForgot(cleanedWord)
          onDismiss()
        }

        if canRemember {
          MenuButton(
            label: "Remember" + (rememberedCount > 0 ? " (\(rememberedCount))" : ""),
            systemImage: "checkmark.circle"
          ) {
            onRemembered(cleanedWord)
            onDismiss()
          }
        }

        if forgotCount > 0 || rememberedCount > 0 {
          // add a menu item to remove the word from the vocabulary
          MenuButton(label: "Remove", systemImage: "trash") {
            onRemove(cleanedWord)
            onDismiss()
          }
        }
      }
      .padding(4)
    }
    .frame(minWidth: 160)
    .onHover { onHoverChanged($0) }
  }
}

private struct MenuButton: View {
  let label: String
  let systemImage: String
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Label(label, systemImage: systemImage)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 4)
        .fill(isHovered ? Color.accentColor : Color.clear)
    )
    .foregroundStyle(isHovered ? .white : .primary)
    .onHover { isHovered = $0 }
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

// MARK: - Countdown Ring View

/// Circular countdown indicator with progress ring
private struct CountdownRingView: View {
  let countdown: Int
  let total: Int

  private var progress: Double {
    guard total > 0 else { return 0 }
    return Double(countdown) / Double(total)
  }

  var body: some View {
    ZStack {
      // Background ring
      Circle()
        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)

      // Progress ring
      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          Color.accentColor,
          style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.linear(duration: 1), value: progress)

      // Countdown number
      Text("\(countdown)")
        .font(.system(.caption, design: .rounded, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(.primary)
    }
    .frame(width: 32, height: 32)
    .padding(6)
    .background {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
  }
}
