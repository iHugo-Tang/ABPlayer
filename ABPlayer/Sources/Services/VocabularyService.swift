import Foundation
import Observation
import SwiftData

/// Service responsible for managing vocabulary operations
/// Provides centralized vocabulary lookup, CRUD operations, and cache management
@Observable
@MainActor
final class VocabularyService {
  private let modelContext: ModelContext
  
  /// Internal cache mapping normalized words to Vocabulary entities
  private var vocabularyMap: [String: Vocabulary] = [:]
  
  /// Version counter for cache invalidation - incremented whenever vocabulary data changes
  /// Views can observe this to trigger re-renders when vocabulary updates
  private(set) var version = 0
  
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
    refreshVocabularyMap()
  }
  
  // MARK: - Public API
  
  /// Normalize a word for vocabulary lookup (lowercase, trim punctuation)
  func normalize(_ word: String) -> String {
    word.lowercased().trimmingCharacters(in: .punctuationCharacters)
  }
  
  /// Find vocabulary entry for a word
  /// - Parameter word: The word to look up (will be normalized internally)
  /// - Returns: Vocabulary entry if found, nil otherwise
  func findVocabulary(for word: String) -> Vocabulary? {
    let normalized = normalize(word)
    return vocabularyMap[normalized]
  }
  
  /// Get difficulty level for a word (nil if not in vocabulary or level is 0)
  /// - Parameter word: The word to check
  /// - Returns: Difficulty level (1-3) or nil
  func difficultyLevel(for word: String) -> Int? {
    guard let vocab = findVocabulary(for: word), vocab.difficultyLevel > 0 else {
      return nil
    }
    return vocab.difficultyLevel
  }
  
  /// Increment forgot count for a word (creates new entry if not exists)
  /// - Parameter word: The word to mark as forgotten
  func incrementForgotCount(for word: String) {
    let normalized = normalize(word)
    if let vocab = vocabularyMap[normalized] {
      vocab.forgotCount += 1
    } else {
      let newVocab = Vocabulary(word: normalized, forgotCount: 1)
      modelContext.insert(newVocab)
      vocabularyMap[normalized] = newVocab
    }
    version += 1
  }
  
  /// Increment remembered count for a word (only if already in vocabulary)
  /// - Parameter word: The word to mark as remembered
  func incrementRememberedCount(for word: String) {
    let normalized = normalize(word)
    // Only increment if word exists - you can't "remember" a word you never "forgot"
    if let vocab = vocabularyMap[normalized] {
      vocab.rememberedCount += 1
      version += 1
    }
  }
  
  /// Remove vocabulary entry for a word
  /// - Parameter word: The word to remove
  func removeVocabulary(for word: String) {
    let normalized = normalize(word)
    if let vocab = vocabularyMap[normalized] {
      modelContext.delete(vocab)
      vocabularyMap.removeValue(forKey: normalized)
      version += 1
    }
  }
  
  /// Get forgot count for a word (0 if not in vocabulary)
  /// - Parameter word: The word to check
  /// - Returns: Number of times the word was forgotten
  func forgotCount(for word: String) -> Int {
    findVocabulary(for: word)?.forgotCount ?? 0
  }
  
  /// Get remembered count for a word (0 if not in vocabulary)
  /// - Parameter word: The word to check
  /// - Returns: Number of times the word was remembered
  func rememberedCount(for word: String) -> Int {
    findVocabulary(for: word)?.rememberedCount ?? 0
  }
  
  /// Get creation date for a word (nil if not in vocabulary)
  /// - Parameter word: The word to check
  /// - Returns: Date when the word was first added to vocabulary
  func createdAt(for word: String) -> Date? {
    findVocabulary(for: word)?.createdAt
  }
  
  // MARK: - Internal Cache Management
  
  /// Refresh the internal vocabulary map from ModelContext
  /// Should be called when external changes to vocabulary data occur
  func refreshVocabularyMap() {
    let descriptor = FetchDescriptor<Vocabulary>()
    let vocabularies = (try? modelContext.fetch(descriptor)) ?? []
    
    vocabularyMap = Dictionary(
      vocabularies.map { ($0.word, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    version += 1
  }
}
