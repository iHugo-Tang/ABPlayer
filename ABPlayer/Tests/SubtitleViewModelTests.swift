import AppKit
import Foundation
import Testing

@testable import ABPlayer

struct AttributedStringBuilderTests {
  
  @Test
  func testBuildBasicAttributedString() {
    let builder = AttributedStringBuilder(
      fontSize: 16.0,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { _ in nil }
    )
    
    let words = ["Hello", "world", "test"]
    let result = builder.build(words: words)
    
    #expect(result.wordRanges.count == 3)
    #expect(result.attributedString.string == "Hello world test")
  }
  
  @Test
  func testWordRangesCalculation() {
    let builder = AttributedStringBuilder(
      fontSize: 16.0,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { _ in nil }
    )
    
    let words = ["Hello", "world"]
    let result = builder.build(words: words)
    
    #expect(result.wordRanges[0].location == 0)
    #expect(result.wordRanges[0].length == 5)
    #expect(result.wordRanges[1].location == 6)
    #expect(result.wordRanges[1].length == 5)
  }
  
  @Test
  func testColorForWordWithoutDifficulty() {
    let builder = AttributedStringBuilder(
      fontSize: 16.0,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { _ in nil }
    )
    
    let color = builder.colorForWord("test")
    #expect(color == .labelColor)
  }
  
  @Test
  func testColorForWordWithDifficultyLevel1() {
    let builder = AttributedStringBuilder(
      fontSize: 16.0,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { word in
        word == "easy" ? 1 : nil
      }
    )
    
    let color = builder.colorForWord("easy")
    #expect(color == .systemGreen)
  }
  
  @Test
  func testColorForWordWithDifficultyLevel2() {
    let builder = AttributedStringBuilder(
      fontSize: 16.0,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { word in
        word == "medium" ? 2 : nil
      }
    )
    
    let color = builder.colorForWord("medium")
    #expect(color == .systemYellow)
  }
  
  @Test
  func testColorForWordWithDifficultyLevel3() {
    let builder = AttributedStringBuilder(
      fontSize: 16.0,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { word in
        word == "hard" ? 3 : nil
      }
    )
    
    let color = builder.colorForWord("hard")
    #expect(color == .systemRed)
  }
  
  @Test
  func testEmptyWordsArray() {
    let builder = AttributedStringBuilder(
      fontSize: 16.0,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { _ in nil }
    )
    
    let result = builder.build(words: [])
    #expect(result.wordRanges.isEmpty)
    #expect(result.attributedString.string.isEmpty)
  }
  
  @Test
  func testSingleWord() {
    let builder = AttributedStringBuilder(
      fontSize: 16.0,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { _ in nil }
    )
    
    let result = builder.build(words: ["Hello"])
    #expect(result.wordRanges.count == 1)
    #expect(result.attributedString.string == "Hello")
  }
  
  @Test
  func testFontAttributeApplied() {
    let fontSize: Double = 20.0
    let builder = AttributedStringBuilder(
      fontSize: fontSize,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { _ in nil }
    )
    
    let result = builder.build(words: ["Test"])
    let attributes = result.attributedString.attributes(at: 0, effectiveRange: nil)
    
    if let font = attributes[.font] as? NSFont {
      #expect(abs(font.pointSize - fontSize) < 0.01)
    } else {
      Issue.record("Font attribute not found")
    }
  }
  
  @Test
  func testWordIndexAttribute() {
    let builder = AttributedStringBuilder(
      fontSize: 16.0,
      defaultTextColor: .labelColor,
      difficultyLevelProvider: { _ in nil }
    )
    
    let result = builder.build(words: ["First", "Second"])
    
    let firstAttributes = result.attributedString.attributes(at: 0, effectiveRange: nil)
    let secondAttributes = result.attributedString.attributes(at: 6, effectiveRange: nil)
    
    #expect(firstAttributes[NSAttributedString.Key("wordIndex")] as? Int == 0)
    #expect(secondAttributes[NSAttributedString.Key("wordIndex")] as? Int == 1)
  }
}

struct SubtitleViewModelTests {
  
  @Test
  @MainActor
  func testInitialState() {
    let viewModel = SubtitleViewModel()
    
    #expect(viewModel.currentCueID == nil)
    #expect(viewModel.scrollState == .autoScrolling)
    #expect(viewModel.wordSelection == .none)
  }
  
  @Test
  @MainActor
  func testHandleUserScroll() async {
    let viewModel = SubtitleViewModel()
    
    viewModel.handleUserScroll()
    
    #expect(viewModel.scrollState.isUserScrolling)
    if case .userScrolling(let countdown) = viewModel.scrollState {
      #expect(countdown == 3)
    } else {
      Issue.record("Expected userScrolling state")
    }
  }
  
  @Test
  @MainActor
  func testCancelScrollResume() {
    let viewModel = SubtitleViewModel()
    
    viewModel.handleUserScroll()
    viewModel.cancelScrollResume()
    
    #expect(viewModel.scrollState == .autoScrolling)
  }
  
  @Test
  @MainActor
  func testHandleWordSelection() {
    let viewModel = SubtitleViewModel()
    let cueID = UUID()
    var pauseCalled = false
    
    viewModel.handleWordSelection(
      wordIndex: 0,
      cueID: cueID,
      isPlaying: true,
      onPause: { pauseCalled = true }
    )
    
    #expect(pauseCalled)
    if case .selected(let selectedCueID, let wordIndex) = viewModel.wordSelection {
      #expect(selectedCueID == cueID)
      #expect(wordIndex == 0)
    } else {
      Issue.record("Expected selected state")
    }
  }
  
  @Test
  @MainActor
  func testDismissWord() {
    let viewModel = SubtitleViewModel()
    let cueID = UUID()
    var playCalled = false
    
    viewModel.handleWordSelection(
      wordIndex: 0,
      cueID: cueID,
      isPlaying: true,
      onPause: {}
    )
    
    viewModel.dismissWord(onPlay: { playCalled = true })
    
    #expect(playCalled)
    #expect(viewModel.wordSelection == .none)
  }
  
  @Test
  @MainActor
  func testFindActiveCueWithBinarySearch() {
    let viewModel = SubtitleViewModel()
    
    let cues = [
      SubtitleCue(startTime: 0.0, endTime: 2.0, text: "First"),
      SubtitleCue(startTime: 2.0, endTime: 4.0, text: "Second"),
      SubtitleCue(startTime: 4.0, endTime: 6.0, text: "Third"),
      SubtitleCue(startTime: 6.0, endTime: 8.0, text: "Fourth")
    ]
    
    viewModel.updateCurrentCue(time: 2.5, cues: cues)
    #expect(viewModel.currentCueID == cues[1].id)
    
    viewModel.updateCurrentCue(time: 5.0, cues: cues)
    #expect(viewModel.currentCueID == cues[2].id)
  }
  
  @Test
  @MainActor
  func testUpdateCurrentCueDoesNotUpdateDuringUserScroll() {
    let viewModel = SubtitleViewModel()
    
    let cues = [
      SubtitleCue(startTime: 0.0, endTime: 2.0, text: "First"),
      SubtitleCue(startTime: 2.0, endTime: 4.0, text: "Second")
    ]
    
    viewModel.updateCurrentCue(time: 1.0, cues: cues)
    let firstCueID = viewModel.currentCueID
    
    viewModel.handleUserScroll()
    viewModel.updateCurrentCue(time: 3.0, cues: cues)
    
    #expect(viewModel.currentCueID == firstCueID)
  }
  
  @Test
  @MainActor
  func testReset() {
    let viewModel = SubtitleViewModel()
    let cueID = UUID()
    
    viewModel.handleUserScroll()
    viewModel.handleWordSelection(wordIndex: 0, cueID: cueID, isPlaying: false, onPause: {})
    
    viewModel.reset()
    
    #expect(viewModel.scrollState == .autoScrolling)
    #expect(viewModel.currentCueID == nil)
    #expect(viewModel.wordSelection == .none)
  }
  
  @Test
  @MainActor
  func testHandleCueTap() {
    let viewModel = SubtitleViewModel()
    let cueID = UUID()
    var seekTime: Double?
    
    viewModel.handleUserScroll()
    
    viewModel.handleCueTap(
      cueID: cueID,
      onSeek: { seekTime = $0 },
      cueStartTime: 10.0
    )
    
    #expect(viewModel.tappedCueID == cueID)
    #expect(seekTime == 10.0)
    #expect(viewModel.scrollState == .autoScrolling)
  }
}
