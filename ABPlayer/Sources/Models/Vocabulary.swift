import Foundation
import SwiftData

/// Model to track vocabulary words the user is learning
@Model
final class Vocabulary {
  var id: UUID

  /// The base form of the word (原型)
  @Attribute(.unique)
  var word: String

  /// Number of times forgotten (忘记次数)
  var forgotCount: Int

  /// Number of times remembered (记得次数)
  var rememberedCount: Int

  /// Creation timestamp
  var createdAt: Date

  /// Optional past tense form (过去式)
  var pastTense: String?

  /// Optional past participle form (过去分词)
  var pastParticiple: String?

  /// Optional present participle form (现在进行时)
  var presentParticiple: String?

  /// Difficulty level based on forgot vs remembered count
  /// Returns max(0, forgotCount - rememberedCount)
  var difficultyLevel: Int {
    max(0, forgotCount - rememberedCount)
  }

  init(
    id: UUID = UUID(),
    word: String,
    forgotCount: Int = 0,
    rememberedCount: Int = 0,
    createdAt: Date = Date(),
    pastTense: String? = nil,
    pastParticiple: String? = nil,
    presentParticiple: String? = nil
  ) {
    self.id = id
    self.word = word
    self.forgotCount = forgotCount
    self.rememberedCount = rememberedCount
    self.createdAt = createdAt
    self.pastTense = pastTense
    self.pastParticiple = pastParticiple
    self.presentParticiple = presentParticiple
  }
}
