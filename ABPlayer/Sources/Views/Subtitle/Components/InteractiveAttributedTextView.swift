import SwiftUI
import AppKit
import OSLog

struct InteractiveAttributedTextView: NSViewRepresentable {
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
    var cachedWidth: CGFloat?
    var cachedSize: CGSize?
    
    private var layoutManager = WordLayoutManager()
    private var stringBuilder: AttributedStringBuilder {
      AttributedStringBuilder(
        fontSize: fontSize,
        defaultTextColor: defaultTextColor,
        difficultyLevelProvider: difficultyLevelProvider
      )
    }

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
      
      let result = stringBuilder.build(words: words)
      wordRanges = result.wordRanges
      cachedAttributedString = result.attributedString
      
      return result.attributedString
    }
    
    func cacheWordFrames(in textView: NSTextView) {
      layoutManager.cacheWordFrames(wordRanges: wordRanges, in: textView)
    }

    func baseColorForWord(_ word: String) -> NSColor {
      stringBuilder.colorForWord(word)
    }

    @MainActor
    func updateSelectedRect(in textView: NSTextView) {
      Task { @MainActor in
        guard let index = selectedWordIndex else {
          onWordRectChanged(nil)
          return
        }
        
        if let rect = layoutManager.boundingRect(forWordAt: index, wordRanges: wordRanges, in: textView) {
          onWordRectChanged(rect)
        } else {
          onWordRectChanged(nil)
        }
      }
    }

    @MainActor
    func handleClick(at point: NSPoint, in textView: NSTextView) {
      guard let wordIndex = layoutManager.findWordIndex(at: point, in: textView, wordRanges: wordRanges) else {
        onDismiss()
        return
      }
      onWordSelected(wordIndex)
    }

    @MainActor
    func handleMouseMoved(at point: NSPoint, in textView: NSTextView) -> Int? {
      if isScrolling { return nil }
      return layoutManager.findWordIndex(at: point, in: textView, wordRanges: wordRanges)
    }
  }
}

class InteractiveNSTextView: NSTextView {
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
