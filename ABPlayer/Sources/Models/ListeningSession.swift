import Foundation
import SwiftData

/// Model to track listening sessions - can be used for statistics
@Model
final class ListeningSession {
  var id: UUID
  var startedAt: Date
  var endedAt: Date?
  var duration: Double  // Total listening time in seconds

  init(
    id: UUID = UUID(),
    startedAt: Date = Date(),
    endedAt: Date? = nil,
    duration: Double = 0
  ) {
    self.id = id
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.duration = duration
  }
}
