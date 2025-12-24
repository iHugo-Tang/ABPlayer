import Foundation
import SwiftData

/// Cached transcription data for an audio file
@Model
final class Transcription {
  var id: UUID

  /// Audio file identifier (using bookmark data hash)
  var audioFileHash: String

  /// Original audio file name for display
  var audioFileName: String

  /// Cached cues stored as JSON
  @Attribute(.externalStorage)
  private var cachedCuesData: Data?

  /// Transcription creation date
  var createdAt: Date

  /// WhisperKit model used for transcription
  var modelUsed: String

  /// Language detected or specified
  var language: String?

  init(
    audioFileHash: String,
    audioFileName: String,
    cues: [SubtitleCue],
    modelUsed: String = "distil-large-v3",
    language: String? = nil
  ) {
    self.id = UUID()
    self.audioFileHash = audioFileHash
    self.audioFileName = audioFileName
    self.createdAt = Date()
    self.modelUsed = modelUsed
    self.language = language
    self.cues = cues
  }

  var cues: [SubtitleCue] {
    get {
      guard let data = cachedCuesData else { return [] }
      return (try? JSONDecoder().decode([SubtitleCue].self, from: data)) ?? []
    }
    set {
      cachedCuesData = try? JSONEncoder().encode(newValue)
    }
  }

  /// Generate hash from bookmark data for cache lookup
  static func hash(from bookmarkData: Data) -> String {
    var hasher = Hasher()
    hasher.combine(bookmarkData)
    return String(format: "%08x", hasher.finalize())
  }
}
