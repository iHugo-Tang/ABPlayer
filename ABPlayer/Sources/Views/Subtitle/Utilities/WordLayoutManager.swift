import AppKit
import Foundation

/// Manages word frame caching and hit detection for interactive text
class WordLayoutManager {
  private(set) var wordFrames: [CGRect] = []
  
  /// Cache word bounding rectangles for hover detection
  func cacheWordFrames(
    wordRanges: [NSRange],
    in textView: NSTextView
  ) {
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
  
  /// Find word index at given point using cached frames or layout manager
  func findWordIndex(
    at point: NSPoint,
    in textView: NSTextView,
    wordRanges: [NSRange]
  ) -> Int? {
    let containerInset = textView.textContainerInset
    
    let hoverAreaFrame = textView.bounds.insetBy(
      dx: containerInset.width * 2,
      dy: containerInset.height * 2
    )
    
    guard hoverAreaFrame.contains(point) else {
      return nil
    }
    
    if !wordFrames.isEmpty && wordFrames.count == wordRanges.count {
      assert(wordFrames.count == wordRanges.count, "Cached frames count must match word ranges")
      
      for (index, frame) in wordFrames.enumerated() {
        if frame.contains(point) {
          assert(index < wordRanges.count, "Found index must be within word ranges")
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
    
    let wordIndex = textStorage.attribute(NSAttributedString.Key("wordIndex"), at: characterIndex, effectiveRange: nil) as? Int
    if let wordIndex {
      assert(wordIndex >= 0 && wordIndex < wordRanges.count, "Word index from attribute must be valid")
    }
    return wordIndex
  }
  
  /// Get bounding rect for word at index
  func boundingRect(
    forWordAt index: Int,
    wordRanges: [NSRange],
    in textView: NSTextView
  ) -> CGRect? {
    assert(index >= 0, "Word index must be non-negative")
    assert(index < wordRanges.count, "Word index must be within range")
    
    guard index < wordRanges.count,
          let layoutManager = textView.layoutManager,
          let textContainer = textView.textContainer else {
      return nil
    }
    
    let range = wordRanges[index]
    let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
    var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
    rect.origin.x += textView.textContainerInset.width
    rect.origin.y += textView.textContainerInset.height
    
    assert(rect.width >= 0 && rect.height >= 0, "Bounding rect must have non-negative dimensions")
    return rect
  }
  
  /// Clear cached frames
  func clearCache() {
    wordFrames.removeAll()
  }
}
