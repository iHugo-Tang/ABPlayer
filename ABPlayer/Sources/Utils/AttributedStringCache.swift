import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class AttributedStringCache {
  struct CacheKey: Hashable {
    let cueID: UUID
    let fontSize: Double
    let defaultTextColor: NSColor
    let vocabularyVersion: Int
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(cueID)
      hasher.combine(fontSize)
      hasher.combine(vocabularyVersion)
    }
    
    static func == (lhs: CacheKey, rhs: CacheKey) -> Bool {
      lhs.cueID == rhs.cueID &&
      lhs.fontSize == rhs.fontSize &&
      lhs.defaultTextColor == rhs.defaultTextColor &&
      lhs.vocabularyVersion == rhs.vocabularyVersion
    }
  }
  
  private var cache: [CacheKey: NSAttributedString] = [:]
  
  func get(for key: CacheKey) -> NSAttributedString? {
    cache[key]
  }
  
  func set(_ value: NSAttributedString, for key: CacheKey) {
    cache[key] = value
  }
  
  func invalidate(for cueID: UUID) {
    cache = cache.filter { $0.key.cueID != cueID }
  }
  
  func invalidateAll() {
    cache.removeAll()
  }
}
