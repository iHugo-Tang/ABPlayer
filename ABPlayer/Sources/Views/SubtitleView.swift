import OSLog
import SwiftData
import SwiftUI

/// Displays synchronized subtitles with current playback position highlighted
struct SubtitleView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(VocabularyService.self) private var vocabularyService

  let cues: [SubtitleCue]
  @Binding var countdownSeconds: Int?
  let fontSize: Double

  private static let pauseDuration = 3

  @State private var currentCueID: UUID?
  @State private var isUserScrolling = false
  @State private var scrollResumeTask: Task<Void, Never>?
  @State private var selectedWord: (cueID: UUID, wordIndex: Int)?
  @State private var wasPlayingBeforeWordInteraction = false
  @State private var tappedCueID: UUID?

  var body: some View {
    ZStack(alignment: .topTrailing) {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(cues) { cue in
              SubtitleCueRow(
                cue: cue,
                isActive: cue.id == currentCueID,
                isScrolling: isUserScrolling,
                fontSize: fontSize,
                selectedWordIndex: selectedWord?.cueID == cue.id ? selectedWord?.wordIndex : nil,
                onWordSelected: { wordIndex in
                  handleWordSelection(wordIndex: wordIndex, cueID: cue.id)
                },
                onHidePopover: {
                  hidePopover()
                },
                onTap: {
                  tappedCueID = cue.id
                  playerManager.seek(to: cue.startTime)
                  cancelScrollResume()
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
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
        .onChange(of: tappedCueID) { _, newValue in
          guard let id = newValue else { return }
          withAnimation(.easeInOut(duration: 0.3)) {
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

      VStack(alignment: .trailing, spacing: 8) {
        if let countdown = countdownSeconds {
          CountdownRingView(countdown: countdown, total: Self.pauseDuration)
            .transition(.scale.combined(with: .opacity))
        }
      }
      .padding(12)
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

  private func hidePopover() {
    selectedWord = nil
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

  private func cancelScrollResume() {
    scrollResumeTask?.cancel()
    scrollResumeTask = nil
    isUserScrolling = false
    countdownSeconds = nil
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
  @Environment(VocabularyService.self) private var vocabularyService

  let cue: SubtitleCue
  let isActive: Bool
  let isScrolling: Bool
  let fontSize: Double
  let selectedWordIndex: Int?
  let onWordSelected: (Int?) -> Void
  let onHidePopover: () -> Void
  let onTap: () -> Void

  @State private var isHovered = false
  @State private var popoverSourceRect: CGRect?
  @State private var isWordInteracting = false
  @State private var contentHeight: CGFloat = 0

  private let words: [String]

  init(
    cue: SubtitleCue,
    isActive: Bool,
    isScrolling: Bool,
    fontSize: Double,
    selectedWordIndex: Int?,
    onWordSelected: @escaping (Int?) -> Void,
    onHidePopover: @escaping () -> Void,
    onTap: @escaping () -> Void
  ) {
    self.cue = cue
    self.isActive = isActive
    self.isScrolling = isScrolling
    self.fontSize = fontSize
    self.selectedWordIndex = selectedWordIndex
    self.onWordSelected = onWordSelected
    self.onHidePopover = onHidePopover
    self.onTap = onTap
    self.words = cue.text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
  }


  /// Get difficulty level for a word (nil if not in vocabulary or level is 0)
  private func difficultyLevel(for word: String) -> Int? {
    vocabularyService.difficultyLevel(for: word)
  }

  /// Get forgot count for a word (0 if not in vocabulary)
  private func forgotCount(for word: String) -> Int {
    vocabularyService.forgotCount(for: word)
  }

  /// Get remembered count for a word (0 if not in vocabulary)
  private func rememberedCount(for word: String) -> Int {
    vocabularyService.rememberedCount(for: word)
  }

  /// Get creation date for a word (nil if not in vocabulary)
  private func createdAt(for word: String) -> Date? {
    vocabularyService.createdAt(for: word)
  }


  var body: some View {
    GeometryReader { geometry in
      let availableWidth = geometry.size.width
      let textWidth = availableWidth - 52 - 12
      
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(timeString(from: cue.startTime))
          .font(.system(size: max(11, fontSize - 4), design: .monospaced))
          .foregroundStyle(isActive ? Color.primary : Color.secondary)
          .frame(width: 52, alignment: .trailing)

        InteractiveAttributedTextView(
            cueID: cue.id,
            isScrolling: isScrolling,
            words: words,
            fontSize: fontSize,
            defaultTextColor: isActive ? NSColor(Color.primary) : NSColor(Color.secondary),
            selectedWordIndex: selectedWordIndex,
            difficultyLevelProvider: { difficultyLevel(for: $0) },
            vocabularyVersion: vocabularyService.version,
            onWordSelected: { index in
              isWordInteracting = true
              onWordSelected(selectedWordIndex == index ? nil : index)
              Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                isWordInteracting = false
              }
            },
            onDismiss: {
              onWordSelected(nil)
            },
            onForgot: { word in
              vocabularyService.incrementForgotCount(for: word)
            },
            onRemembered: { word in
              vocabularyService.incrementRememberedCount(for: word)
            },
            onRemove: { word in
              vocabularyService.removeVocabulary(for: word)
            },
            onWordRectChanged: { rect in
              if popoverSourceRect != rect {
                popoverSourceRect = rect
              }
            },
            onHeightChanged: { height in
              if contentHeight != height {
                contentHeight = height
              }
            },
            forgotCount: { forgotCount(for: $0) },
            rememberedCount: { rememberedCount(for: $0) },
            createdAt: { createdAt(for: $0) }
          )
          .alignmentGuide(.firstTextBaseline) { context in
            let font = NSFont.systemFont(ofSize: fontSize)
            let lineHeight = font.ascender + font.leading
            return lineHeight
          }
          .frame(width: textWidth, alignment: .leading)
          .popover(
            isPresented: Binding(
              get: { popoverSourceRect != nil },
              set: {
                if !$0 {
                  popoverSourceRect = nil
                  onWordSelected(nil)
                }
              }
            ),
            attachmentAnchor: .rect(.rect(popoverSourceRect ?? .zero)),
            arrowEdge: .bottom
          ) {
            if let selectedIndex = selectedWordIndex, selectedIndex < words.count {
              WordMenuView(
                word: words[selectedIndex],
                onDismiss: { onWordSelected(nil) },
                onForgot: { vocabularyService.incrementForgotCount(for: $0) },
                onRemembered: { vocabularyService.incrementRememberedCount(for: $0) },
                onRemove: { vocabularyService.removeVocabulary(for: $0) },
                forgotCount: forgotCount(for: words[selectedIndex]),
                rememberedCount: rememberedCount(for: words[selectedIndex]),
                createdAt: createdAt(for: words[selectedIndex])
              )
            }
          }
          .onDisappear {
            onHidePopover()
          }
      }
    }
    .frame(height: max(contentHeight, 23), alignment: .center)
    .padding(.vertical, 8)
    .padding(.horizontal, 8)
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
      guard !isWordInteracting else { return }

      if selectedWordIndex == nil {
        onTap()
      } else {
        onWordSelected(selectedWordIndex)
      }
    }
    .onHover { hovering in
      guard !isScrolling else {
        if isHovered { isHovered = false }
        return
      }
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
      }
    }
    .onChange(of: isScrolling) { _, isScrolling in
      if isScrolling {
        isHovered = false
      }
    }
    .onChange(of: isActive) { _, newValue in
      if !newValue {
        onWordSelected(nil)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: isActive)
  }

  private var backgroundColor: Color {
    if isActive {
      return Color.accentColor.opacity(0.12)
    } else if isHovered && !isScrolling {
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
  let cueID: UUID
  let isScrolling: Bool
  let words: [String]
  let fontSize: Double
  var defaultTextColor: NSColor = .labelColor
  let selectedWordIndex: Int?
  let difficultyLevelProvider: (String) -> Int?
  let vocabularyVersion: Int
  let onWordSelected: (Int) -> Void
  let onDismiss: () -> Void
  let onForgot: (String) -> Void
  let onRemembered: (String) -> Void
  let onRemove: (String) -> Void
  let onWordRectChanged: (CGRect?) -> Void
  let onHeightChanged: (CGFloat) -> Void
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
    let isFirstRender = context.coordinator.cachedAttributedString == nil
    let needsContentUpdate = isFirstRender ||
                             context.coordinator.cueID != cueID ||
                             context.coordinator.fontSize != fontSize ||
                             context.coordinator.defaultTextColor != defaultTextColor ||
                             context.coordinator.words != words ||
                             context.coordinator.vocabularyVersion != vocabularyVersion

    let needsSelectionUpdate = context.coordinator.selectedWordIndex != selectedWordIndex

    context.coordinator.difficultyLevelProvider = difficultyLevelProvider
    context.coordinator.vocabularyVersion = vocabularyVersion
    context.coordinator.onWordSelected = onWordSelected
    context.coordinator.onDismiss = onDismiss
    context.coordinator.onForgot = onForgot
    context.coordinator.onRemembered = onRemembered
    context.coordinator.onRemove = onRemove
    context.coordinator.onWordRectChanged = onWordRectChanged
    context.coordinator.forgotCount = forgotCount
    context.coordinator.rememberedCount = rememberedCount
    context.coordinator.createdAt = createdAt
    context.coordinator.isScrolling = isScrolling

    if needsContentUpdate {
      if context.coordinator.vocabularyVersion != vocabularyVersion {
        context.coordinator.cachedAttributedString = nil
      }
      context.coordinator.cachedSize = nil
      context.coordinator.updateState(
        cueID: cueID,
        words: words,
        selectedWordIndex: selectedWordIndex,
        fontSize: fontSize,
        defaultTextColor: defaultTextColor
      )
      textView.textStorage?.setAttributedString(context.coordinator.buildAttributedString())
      textView.invalidateIntrinsicContentSize()
    }

    if needsSelectionUpdate {
      textView.updateHoverState(
        oldHoveredIndex: context.coordinator.lastHoveredIndex,
        newHoveredIndex: textView.hoveredWordIndex,
        oldSelectedIndex: context.coordinator.lastSelectedIndex,
        newSelectedIndex: selectedWordIndex
      )
      context.coordinator.selectedWordIndex = selectedWordIndex
      context.coordinator.lastSelectedIndex = selectedWordIndex
      context.coordinator.updateSelectedRect(in: textView)
    } else if !isScrolling {
      if textView.hoveredWordIndex != context.coordinator.lastHoveredIndex {
         textView.updateHoverState(
          oldHoveredIndex: context.coordinator.lastHoveredIndex,
          newHoveredIndex: textView.hoveredWordIndex,
          oldSelectedIndex: nil,
          newSelectedIndex: nil
         )
         context.coordinator.lastHoveredIndex = textView.hoveredWordIndex
      }
    } else if isScrolling {
       if context.coordinator.lastHoveredIndex != nil {
         textView.updateHoverState(
          oldHoveredIndex: context.coordinator.lastHoveredIndex,
          newHoveredIndex: nil,
          oldSelectedIndex: nil,
          newSelectedIndex: nil
         )
         context.coordinator.lastHoveredIndex = nil
         textView.hoveredWordIndex = nil
       }
    }
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: InteractiveNSTextView, context: Context) -> CGSize? {
    guard let layoutManager = nsView.layoutManager,
          let textContainer = nsView.textContainer else {
      return nil
    }
    
    let width = proposal.width ?? 400
    
    if let cachedWidth = context.coordinator.cachedWidth,
       let cachedSize = context.coordinator.cachedSize,
       abs(cachedWidth - width) < 1.0 {
      Logger.ui.debug("hit cache \(words.first ?? "nil") w:\(cachedSize.width), h:\(cachedSize.height)")
      return cachedSize
    }
    
    textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    
    layoutManager.ensureLayout(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)
    if usedRect.isEmpty {
      return nil
    }
    
    let inset = nsView.textContainerInset
    let height = usedRect.height + inset.height * 2
    
    let size = CGSize(width: width, height: height)
    if width.isNormal && height.isNormal {
      context.coordinator.cachedWidth = width
      context.coordinator.cachedSize = size
    }
    
    DispatchQueue.main.async {
      onHeightChanged(height)
    }
    
    Logger.ui.debug("\(words.first ?? "nil") w:\(width), h:\(height)")
    
    return size
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      cueID: cueID,
      words: words,
      selectedWordIndex: selectedWordIndex,
      fontSize: fontSize,
      defaultTextColor: defaultTextColor,
      difficultyLevelProvider: difficultyLevelProvider,
      vocabularyVersion: vocabularyVersion,
      onWordSelected: onWordSelected,
      onDismiss: onDismiss,
      onForgot: onForgot,
      onRemembered: onRemembered,
      onRemove: onRemove,
      onWordRectChanged: onWordRectChanged,
      forgotCount: forgotCount,
      rememberedCount: rememberedCount,
      createdAt: createdAt
    )
  }

  class Coordinator: NSObject {
    var cueID: UUID
    var words: [String]
    var selectedWordIndex: Int?
    var fontSize: Double
    var defaultTextColor: NSColor
    var difficultyLevelProvider: (String) -> Int?
    var vocabularyVersion: Int
    var onWordSelected: (Int) -> Void
    var onDismiss: () -> Void
    var onForgot: (String) -> Void
    var onRemembered: (String) -> Void
    var onRemove: (String) -> Void
    var onWordRectChanged: (CGRect?) -> Void
    var forgotCount: (String) -> Int
    var rememberedCount: (String) -> Int
    var createdAt: (String) -> Date?
    var isScrolling = false

    var cachedAttributedString: NSAttributedString?
    var cachedVocabularyVersion: Int = 0
    var cachedDefaultTextColor: NSColor?
    var lastSelectedIndex: Int?
    var lastHoveredIndex: Int?
    var wordRanges: [NSRange] = []
    var wordFrames: [CGRect] = []
    var cachedWidth: CGFloat?
    var cachedSize: CGSize?

    init(
      cueID: UUID,
      words: [String],
      selectedWordIndex: Int?,
      fontSize: Double,
      defaultTextColor: NSColor,
      difficultyLevelProvider: @escaping (String) -> Int?,
      vocabularyVersion: Int,
      onWordSelected: @escaping (Int) -> Void,
      onDismiss: @escaping () -> Void,
      onForgot: @escaping (String) -> Void,
      onRemembered: @escaping (String) -> Void,
      onRemove: @escaping (String) -> Void,
      onWordRectChanged: @escaping (CGRect?) -> Void,
      forgotCount: @escaping (String) -> Int,
      rememberedCount: @escaping (String) -> Int,
      createdAt: @escaping (String) -> Date?
    ) {
      self.cueID = cueID
      self.words = words
      self.selectedWordIndex = selectedWordIndex
      self.fontSize = fontSize
      self.defaultTextColor = defaultTextColor
      self.difficultyLevelProvider = difficultyLevelProvider
      self.vocabularyVersion = vocabularyVersion
      self.onWordSelected = onWordSelected
      self.onDismiss = onDismiss
      self.onForgot = onForgot
      self.onRemembered = onRemembered
      self.onRemove = onRemove
      self.onWordRectChanged = onWordRectChanged
      self.forgotCount = forgotCount
      self.rememberedCount = rememberedCount
      self.createdAt = createdAt
    }

    func updateState(
      cueID: UUID,
      words: [String],
      selectedWordIndex: Int?,
      fontSize: Double,
      defaultTextColor: NSColor
    ) {
      self.cueID = cueID
      self.words = words
      self.selectedWordIndex = selectedWordIndex
      self.fontSize = fontSize
      self.defaultTextColor = defaultTextColor
    }

    func buildAttributedString() -> NSAttributedString {
      if let cached = cachedAttributedString,
         !wordRanges.isEmpty,
         cached.string.split(separator: " ").count == words.count,
         cachedVocabularyVersion == vocabularyVersion,
         cachedDefaultTextColor == defaultTextColor {
         return cached
      }

      cachedDefaultTextColor = defaultTextColor
      cachedVocabularyVersion = vocabularyVersion
      wordRanges.removeAll(keepingCapacity: true)
      wordFrames.removeAll(keepingCapacity: true)
      let result = NSMutableAttributedString()
      let font = NSFont.systemFont(ofSize: fontSize)

      for (index, word) in words.enumerated() {
        let attributes: [NSAttributedString.Key: Any] = [
          .font: font,
          .foregroundColor: baseColorForWord(word),
          NSAttributedString.Key("wordIndex"): index
        ]
        
        let startLocation = result.length
        let wordString = NSAttributedString(string: word, attributes: attributes)
        result.append(wordString)
        let endLocation = result.length
        
        wordRanges.append(NSRange(location: startLocation, length: endLocation - startLocation))
        
        if index < words.count - 1 {
          result.append(NSAttributedString(string: " ", attributes: [.font: font]))
        }
      }
      
      cachedAttributedString = result
      return result
    }
    
    func cacheWordFrames(in textView: NSTextView) {
      guard let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer else { return }
      
      wordFrames.removeAll(keepingCapacity: true)
      
      for range in wordRanges {
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textView.textContainerInset.width
        rect.origin.y += textView.textContainerInset.height
        wordFrames.append(rect)
      }
    }

    func baseColorForWord(_ word: String) -> NSColor {
      guard let level = difficultyLevelProvider(word), level > 0 else {
        return defaultTextColor
      }
      switch level {
      case 1: return .systemGreen
      case 2: return .systemYellow
      default: return .systemRed
      }
    }

    @MainActor
    func updateSelectedRect(in textView: NSTextView) {
      Task { @MainActor in
        guard let index = selectedWordIndex,
              index < wordRanges.count,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
          onWordRectChanged(nil)
          return
        }

        let range = wordRanges[index]
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textView.textContainerInset.width
        rect.origin.y += textView.textContainerInset.height
        onWordRectChanged(rect)
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
      if isScrolling { return nil }
      return findWordIndex(at: point, in: textView)
    }

    @MainActor
    private func findWordIndex(at point: NSPoint, in textView: NSTextView) -> Int? {
      let containerInset = textView.textContainerInset
      
      let hoverAreaFrame = textView.bounds.insetBy(
        dx: containerInset.width * 2,
        dy: containerInset.height * 2
      )
      
      guard hoverAreaFrame.contains(point) else {
        return nil
      }
      
      if !wordFrames.isEmpty && wordFrames.count == wordRanges.count {
        for (index, frame) in wordFrames.enumerated() {
          if frame.contains(point) {
            return index
          }
        }
        return nil
      }

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
    Logger.ui.debug("firstLineFragmentRect: \(String(describing: firstLineFragmentRect))")
    let firstLineBaselineOffset = layoutManager.typesetter.baselineOffset(
      in: layoutManager,
      glyphIndex: 0
    )
    
    return textContainerInset.height + firstLineFragmentRect.origin.y + firstLineBaselineOffset
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    
    coordinator?.cacheWordFrames(in: self)
    coordinator?.updateSelectedRect(in: self)
    
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
      let oldIndex = hoveredWordIndex
      hoveredWordIndex = newHoveredWordIndex
      updateHoverState(
        oldHoveredIndex: oldIndex,
        newHoveredIndex: newHoveredWordIndex,
        oldSelectedIndex: coordinator?.lastSelectedIndex,
        newSelectedIndex: coordinator?.lastSelectedIndex
      )
    }
  }

  override func mouseExited(with event: NSEvent) {
    if hoveredWordIndex != nil {
      let oldIndex = hoveredWordIndex
      hoveredWordIndex = nil
      updateHoverState(
        oldHoveredIndex: oldIndex,
        newHoveredIndex: nil,
        oldSelectedIndex: coordinator?.lastSelectedIndex,
        newSelectedIndex: coordinator?.lastSelectedIndex
      )
    }
  }

  func updateHoverState(oldHoveredIndex: Int?, newHoveredIndex: Int?, oldSelectedIndex: Int?, newSelectedIndex: Int?) {
    guard let textStorage = textStorage, let coordinator = coordinator else { return }

    var indicesToUpdate = [oldHoveredIndex, newHoveredIndex].compactMap { $0 }

    if let oldIndex = oldSelectedIndex, oldSelectedIndex != newSelectedIndex {
      indicesToUpdate.append(oldIndex)
    }
    if let newIndex = newSelectedIndex, oldSelectedIndex != newSelectedIndex {
      indicesToUpdate.append(newIndex)
    }

    let uniqueIndices = Array(Set(indicesToUpdate))
    if uniqueIndices.isEmpty { return }

    textStorage.beginEditing()

    for wordIndex in uniqueIndices {
       guard wordIndex < coordinator.wordRanges.count else { continue }
       let range = coordinator.wordRanges[wordIndex]

       let isHovered = wordIndex == newHoveredIndex
       let isSelected = wordIndex == newSelectedIndex
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
