import AppKit
import Foundation

/// Builds attributed strings for interactive subtitle text
/// Handles word-based formatting with vocabulary difficulty colors
struct AttributedStringBuilder {
  let fontSize: Double
  let defaultTextColor: NSColor
  let difficultyLevelProvider: (String) -> Int?
  
  /// Result containing the attributed string and word ranges
  struct Result {
    let attributedString: NSAttributedString
    let wordRanges: [NSRange]
  }
  
  /// Build attributed string from words with color coding
  func build(words: [String]) -> Result {
    var wordRanges: [NSRange] = []
    let result = NSMutableAttributedString()
    let font = NSFont.systemFont(ofSize: fontSize)
    
    for (index, word) in words.enumerated() {
      assert(!word.isEmpty, "Words should not be empty")
      
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: colorForWord(word),
        NSAttributedString.Key("wordIndex"): index
      ]
      
      let startLocation = result.length
      let wordString = NSAttributedString(string: word, attributes: attributes)
      result.append(wordString)
      let endLocation = result.length
      
      let range = NSRange(location: startLocation, length: endLocation - startLocation)
      assert(range.length > 0, "Word range should have positive length")
      wordRanges.append(range)
      
      if index < words.count - 1 {
        result.append(NSAttributedString(string: " ", attributes: [.font: font]))
      }
    }
    
    assert(wordRanges.count == words.count, "Word ranges count must match words count")
    return Result(attributedString: result, wordRanges: wordRanges)
  }
  
  /// Get color for word based on difficulty level
  func colorForWord(_ word: String) -> NSColor {
    guard let level = difficultyLevelProvider(word), level > 0 else {
      return defaultTextColor
    }
    switch level {
    case 1: return .systemGreen
    case 2: return .systemYellow
    default: return .systemRed
    }
  }
}
