import SwiftUI
import AppKit

struct SubtitleCueRow: View {
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
  @State private var lookupWord: String?
  @State private var lookupIndex: Int?
  @State private var lookupRequestID: Int = 0

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

  private func difficultyLevel(for word: String) -> Int? {
    vocabularyService.difficultyLevel(for: word)
  }

  private func forgotCount(for word: String) -> Int {
    vocabularyService.forgotCount(for: word)
  }

  private func rememberedCount(for word: String) -> Int {
    vocabularyService.rememberedCount(for: word)
  }

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

        subtitleTextView(textWidth: textWidth)
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
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
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
    } else if isHovered {
      return Color.primary.opacity(0.04)
    } else {
      return Color.clear
    }
  }

  private func subtitleTextView(textWidth: CGFloat) -> some View {
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
        lookupWord: lookupWord,
        lookupIndex: lookupIndex,
        lookupRequestID: lookupRequestID,
        onHeightChanged: { height in
          if contentHeight != height {
            contentHeight = height
          }
        },
        forgotCount: { forgotCount(for: $0) },
        rememberedCount: { rememberedCount(for: $0) },
        createdAt: { createdAt(for: $0) }
      )
      .alignmentGuide(.firstTextBaseline) { _ in
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
            onLookup: { word in
              guard let selectedWordIndex else { return }
              lookupWord = word
              lookupIndex = selectedWordIndex
              lookupRequestID += 1
            },
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

  private func timeString(from value: Double) -> String {
    guard value.isFinite, value >= 0 else { return "0:00" }
    let totalSeconds = Int(value.rounded())
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
  }
}
