import SwiftData
import SwiftUI

/// Displays synchronized subtitles with current playback position highlighted
struct SubtitleView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Query private var vocabularies: [Vocabulary]

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
  @State private var vocabularyMap: [String: Vocabulary] = [:]

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
                vocabularyMap: vocabularyMap,
                selectedWordIndex: selectedWord?.cueID == cue.id ? selectedWord?.wordIndex : nil,
                onWordSelected: { wordIndex in
                  handleWordSelection(wordIndex: wordIndex, cueID: cue.id)
                },
                onHidePopover: {
                  hidePopover()
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
        .transaction { $0.animation = nil }
        .onScrollPhaseChange { _, newPhase in
          handleScrollPhaseChange(newPhase)
        }
        .onChange(of: currentCueID) { _, newValue in
          guard !isUserScrolling, let id = newValue else { return }
          proxy.scrollTo(id, anchor: .center)
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
    .onAppear {
      updateVocabularyMap()
    }
    .onChange(of: vocabularies) { _, _ in
      updateVocabularyMap()
    }
  }

  private func updateVocabularyMap() {
    vocabularyMap = Dictionary(
      vocabularies.map { ($0.word, $0) }, uniquingKeysWith: { first, _ in first })
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

  /// Only hides the popover without resuming playback
  private func hidePopover() {
    selectedWord = nil
  }

  /// Hides the popover and resumes playback if it was paused by word click
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

  let cue: SubtitleCue
  let isActive: Bool
  let fontSize: Double
  let vocabularyMap: [String: Vocabulary]
  let selectedWordIndex: Int?
  let onWordSelected: (Int?) -> Void
  let onHidePopover: () -> Void
  let onTap: () -> Void

  @State private var isHovered = false
  @State private var isMenuHovered = false

  private let words: [String]

  init(
    cue: SubtitleCue,
    isActive: Bool,
    fontSize: Double,
    vocabularyMap: [String: Vocabulary],
    selectedWordIndex: Int?,
    onWordSelected: @escaping (Int?) -> Void,
    onHidePopover: @escaping () -> Void,
    onTap: @escaping () -> Void
  ) {
    self.cue = cue
    self.isActive = isActive
    self.fontSize = fontSize
    self.vocabularyMap = vocabularyMap
    self.selectedWordIndex = selectedWordIndex
    self.onWordSelected = onWordSelected
    self.onHidePopover = onHidePopover
    self.onTap = onTap
    self.words = cue.text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
  }

  private var attributedText: AttributedString {
    var result = AttributedString()
    for (index, word) in words.enumerated() {
      var wordPart = AttributedString(word)
      wordPart.foregroundColor = wordColor(for: word)
      result.append(wordPart)
      if index < words.count - 1 {
        result.append(AttributedString(" "))
      }
    }
    return result
  }

  /// Normalize a word for vocabulary lookup (lowercase, trim punctuation)
  private func normalize(_ word: String) -> String {
    word.lowercased().trimmingCharacters(in: .punctuationCharacters)
  }

  /// Find vocabulary entry for a word
  private func findVocabulary(for word: String) -> Vocabulary? {
    let normalized = normalize(word)
    return vocabularyMap[normalized]
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
        .font(.system(size: max(11, fontSize - 4), design: .monospaced))
        .foregroundStyle(isActive ? .primary : .tertiary)
        .frame(width: 52, alignment: .trailing)

      if isActive {
        InteractiveAttributedTextView(
          words: words,
          fontSize: fontSize,
          selectedWordIndex: selectedWordIndex,
          difficultyLevelProvider: { difficultyLevel(for: $0) },
          onWordSelected: { index in
            onWordSelected(selectedWordIndex == index ? nil : index)
          },
          onDismiss: {
            onWordSelected(nil)
          },
          onForgot: { word in
            incrementForgotCount(for: word)
          },
          onRemembered: { word in
            incrementRememberedCount(for: word)
          },
          onRemove: { word in
            removeVocabulary(for: word)
          },
          onMenuHoverChanged: { hovering in
            isMenuHovered = hovering
          },
          forgotCount: { forgotCount(for: $0) },
          rememberedCount: { rememberedCount(for: $0) },
          createdAt: { createdAt(for: $0) }
        )
        .alignmentGuide(.firstTextBaseline) { context in
          let font = NSFont.systemFont(ofSize: fontSize)
          return context.height + font.descender
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popover(
          isPresented: Binding(
            get: { selectedWordIndex != nil },
            set: { if !$0 { onWordSelected(nil) } }
          ),
          arrowEdge: .top
        ) {
          if let selectedIndex = selectedWordIndex, selectedIndex < words.count {
            WordMenuView(
              word: words[selectedIndex],
              onDismiss: { onWordSelected(nil) },
              onForgot: { incrementForgotCount(for: $0) },
              onRemembered: { incrementRememberedCount(for: $0) },
              onRemove: { removeVocabulary(for: $0) },
              onHoverChanged: { isMenuHovered = $0 },
              forgotCount: forgotCount(for: words[selectedIndex]),
              rememberedCount: rememberedCount(for: words[selectedIndex]),
              createdAt: createdAt(for: words[selectedIndex])
            )
          }
        }
        .onDisappear {
          onHidePopover()
        }
      } else {
        Text(attributedText)
          .font(.system(size: fontSize))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 2)
          .padding(.vertical, 1)
      }
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 12)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(backgroundColor)
        .onTapGesture {
          if !isActive {
            onTap()
          } else if selectedWordIndex != nil && !isMenuHovered {
            onWordSelected(nil)
          }
        }
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(isActive ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
    )
    .contentShape(Rectangle())
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

// MARK: - Interactive Attributed Text View

private struct InteractiveAttributedTextView: NSViewRepresentable {
  let words: [String]
  let fontSize: Double
  let selectedWordIndex: Int?
  let difficultyLevelProvider: (String) -> Int?
  let onWordSelected: (Int) -> Void
  let onDismiss: () -> Void
  let onForgot: (String) -> Void
  let onRemembered: (String) -> Void
  let onRemove: (String) -> Void
  let onMenuHoverChanged: (Bool) -> Void
  let forgotCount: (String) -> Int
  let rememberedCount: (String) -> Int
  let createdAt: (String) -> Date?

  func makeNSView(context: Context) -> InteractiveNSTextView {
    let textView = InteractiveNSTextView()
    textView.isEditable = false
    textView.isSelectable = false
    textView.backgroundColor = .clear
    textView.textContainerInset = NSSize(width: 2, height: 1)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.coordinator = context.coordinator
    
    textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
    textView.setContentCompressionResistancePriority(.required, for: .vertical)
    
    return textView
  }

  func updateNSView(_ textView: InteractiveNSTextView, context: Context) {
    context.coordinator.updateState(
      words: words,
      selectedWordIndex: selectedWordIndex,
      fontSize: fontSize,
      difficultyLevelProvider: difficultyLevelProvider,
      onWordSelected: onWordSelected,
      onDismiss: onDismiss,
      onForgot: onForgot,
      onRemembered: onRemembered,
      onRemove: onRemove,
      onMenuHoverChanged: onMenuHoverChanged,
      forgotCount: forgotCount,
      rememberedCount: rememberedCount,
      createdAt: createdAt
    )
    textView.textStorage?.setAttributedString(context.coordinator.buildAttributedString())
    textView.updateHoverState(hoveredIndex: textView.hoveredWordIndex)
    textView.invalidateIntrinsicContentSize()
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: InteractiveNSTextView, context: Context) -> CGSize? {
    guard let layoutManager = nsView.layoutManager,
          let textContainer = nsView.textContainer else {
      return nil
    }
    
    let width = proposal.width ?? 400
    textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    
    layoutManager.ensureLayout(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)
    
    let inset = nsView.textContainerInset
    let height = usedRect.height + inset.height * 2
    
    return CGSize(width: width, height: height)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      words: words,
      selectedWordIndex: selectedWordIndex,
      fontSize: fontSize,
      difficultyLevelProvider: difficultyLevelProvider,
      onWordSelected: onWordSelected,
      onDismiss: onDismiss,
      onForgot: onForgot,
      onRemembered: onRemembered,
      onRemove: onRemove,
      onMenuHoverChanged: onMenuHoverChanged,
      forgotCount: forgotCount,
      rememberedCount: rememberedCount,
      createdAt: createdAt
    )
  }

  class Coordinator: NSObject {
    var words: [String]
    var selectedWordIndex: Int?
    var fontSize: Double
    var difficultyLevelProvider: (String) -> Int?
    var onWordSelected: (Int) -> Void
    var onDismiss: () -> Void
    var onForgot: (String) -> Void
    var onRemembered: (String) -> Void
    var onRemove: (String) -> Void
    var onMenuHoverChanged: (Bool) -> Void
    var forgotCount: (String) -> Int
    var rememberedCount: (String) -> Int
    var createdAt: (String) -> Date?

    init(
      words: [String],
      selectedWordIndex: Int?,
      fontSize: Double,
      difficultyLevelProvider: @escaping (String) -> Int?,
      onWordSelected: @escaping (Int) -> Void,
      onDismiss: @escaping () -> Void,
      onForgot: @escaping (String) -> Void,
      onRemembered: @escaping (String) -> Void,
      onRemove: @escaping (String) -> Void,
      onMenuHoverChanged: @escaping (Bool) -> Void,
      forgotCount: @escaping (String) -> Int,
      rememberedCount: @escaping (String) -> Int,
      createdAt: @escaping (String) -> Date?
    ) {
      self.words = words
      self.selectedWordIndex = selectedWordIndex
      self.fontSize = fontSize
      self.difficultyLevelProvider = difficultyLevelProvider
      self.onWordSelected = onWordSelected
      self.onDismiss = onDismiss
      self.onForgot = onForgot
      self.onRemembered = onRemembered
      self.onRemove = onRemove
      self.onMenuHoverChanged = onMenuHoverChanged
      self.forgotCount = forgotCount
      self.rememberedCount = rememberedCount
      self.createdAt = createdAt
    }

    func updateState(
      words: [String],
      selectedWordIndex: Int?,
      fontSize: Double,
      difficultyLevelProvider: @escaping (String) -> Int?,
      onWordSelected: @escaping (Int) -> Void,
      onDismiss: @escaping () -> Void,
      onForgot: @escaping (String) -> Void,
      onRemembered: @escaping (String) -> Void,
      onRemove: @escaping (String) -> Void,
      onMenuHoverChanged: @escaping (Bool) -> Void,
      forgotCount: @escaping (String) -> Int,
      rememberedCount: @escaping (String) -> Int,
      createdAt: @escaping (String) -> Date?
    ) {
      self.words = words
      self.selectedWordIndex = selectedWordIndex
      self.fontSize = fontSize
      self.difficultyLevelProvider = difficultyLevelProvider
      self.onWordSelected = onWordSelected
      self.onDismiss = onDismiss
      self.onForgot = onForgot
      self.onRemembered = onRemembered
      self.onRemove = onRemove
      self.onMenuHoverChanged = onMenuHoverChanged
      self.forgotCount = forgotCount
      self.rememberedCount = rememberedCount
      self.createdAt = createdAt
    }

    func buildAttributedString() -> NSAttributedString {
      let result = NSMutableAttributedString()
      let font = NSFont.systemFont(ofSize: fontSize)

      for (index, word) in words.enumerated() {
        let attributes: [NSAttributedString.Key: Any] = [
          .font: font,
          .foregroundColor: baseColorForWord(word),
          NSAttributedString.Key("wordIndex"): index
        ]
        let wordString = NSAttributedString(string: word, attributes: attributes)
        result.append(wordString)
        
        if index < words.count - 1 {
          result.append(NSAttributedString(string: " ", attributes: [.font: font]))
        }
      }
      
      return result
    }

    func baseColorForWord(_ word: String) -> NSColor {
      guard let level = difficultyLevelProvider(word), level > 0 else {
        return .labelColor
      }
      switch level {
      case 1: return .systemGreen
      case 2: return .systemYellow
      default: return .systemRed
      }
    }

    @MainActor
    func handleClick(at point: NSPoint, in textView: NSTextView) {
      guard let wordIndex = findWordIndex(at: point, in: textView) else {
        onDismiss()
        return
      }
      onWordSelected(wordIndex)
    }

    @MainActor
    func handleMouseMoved(at point: NSPoint, in textView: NSTextView) -> Int? {
      return findWordIndex(at: point, in: textView)
    }

    @MainActor
    private func findWordIndex(at point: NSPoint, in textView: NSTextView) -> Int? {
      guard let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer,
            let textStorage = textView.textStorage else { return nil }

      let characterIndex = layoutManager.characterIndex(
        for: point,
        in: textContainer,
        fractionOfDistanceBetweenInsertionPoints: nil
      )

      guard characterIndex < textStorage.length else { return nil }

      return textStorage.attribute(NSAttributedString.Key("wordIndex"), at: characterIndex, effectiveRange: nil) as? Int
    }
  }
}

private class InteractiveNSTextView: NSTextView {
  weak var coordinator: InteractiveAttributedTextView.Coordinator?
  private var trackingArea: NSTrackingArea?
  var hoveredWordIndex: Int?
  weak var popoverViewController: NSViewController?

  override var firstBaselineOffsetFromTop: CGFloat {
    guard let layoutManager = layoutManager,
          let textContainer = textContainer,
          let textStorage = textStorage,
          textStorage.length > 0 else {
      return textContainerInset.height
    }
    
    let glyphRange = layoutManager.glyphRange(for: textContainer)
    guard glyphRange.length > 0 else {
      return textContainerInset.height
    }
    
    let firstLineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
    let firstLineBaselineOffset = layoutManager.typesetter.baselineOffset(
      in: layoutManager,
      glyphIndex: 0
    )
    
    return textContainerInset.height + firstLineFragmentRect.origin.y + firstLineBaselineOffset
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    
    if let trackingArea = trackingArea {
      removeTrackingArea(trackingArea)
    }
    
    let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
    trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
    addTrackingArea(trackingArea!)
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    coordinator?.handleClick(at: point, in: self)
  }

  override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let newHoveredWordIndex = coordinator?.handleMouseMoved(at: point, in: self)
    
    if newHoveredWordIndex != hoveredWordIndex {
      hoveredWordIndex = newHoveredWordIndex
      updateHoverState(hoveredIndex: newHoveredWordIndex)
    }
  }

  override func mouseExited(with event: NSEvent) {
    if hoveredWordIndex != nil {
      hoveredWordIndex = nil
      updateHoverState(hoveredIndex: nil)
    }
  }

  func updateHoverState(hoveredIndex: Int?) {
    guard let textStorage = textStorage, let coordinator = coordinator else { return }
    
    textStorage.beginEditing()
    
    textStorage.enumerateAttribute(NSAttributedString.Key("wordIndex"), in: NSRange(location: 0, length: textStorage.length)) { value, range, _ in
      guard let wordIndex = value as? Int, wordIndex < coordinator.words.count else { return }
      
      let isHovered = wordIndex == hoveredIndex
      let isSelected = wordIndex == coordinator.selectedWordIndex
      let isHighlighted = isHovered || isSelected
      
      let word = coordinator.words[wordIndex]
      let baseColor = coordinator.baseColorForWord(word)
      let foregroundColor = isHighlighted ? NSColor.controlAccentColor : baseColor
      let backgroundColor = isHighlighted ? NSColor.controlAccentColor.withAlphaComponent(0.15) : .clear
      
      textStorage.addAttribute(.foregroundColor, value: foregroundColor, range: range)
      textStorage.addAttribute(.backgroundColor, value: backgroundColor, range: range)
    }
    
    textStorage.endEditing()
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
      Circle()
        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)

      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          Color.accentColor,
          style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.linear(duration: 1), value: progress)

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
