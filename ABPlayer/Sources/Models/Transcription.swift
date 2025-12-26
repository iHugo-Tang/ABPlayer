import Foundation
import SwiftData

/// Cached transcription data for an audio file
@Model
final class Transcription {
  var id: UUID

  /// Audio file identifier (using AudioFile's UUID)
  var audioFileId: String

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
    audioFileId: String,
    audioFileName: String,
    cues: [SubtitleCue],
    modelUsed: String = "distil-large-v3",
    language: String? = nil
  ) {
    self.id = UUID()
    self.audioFileId = audioFileId
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
}
