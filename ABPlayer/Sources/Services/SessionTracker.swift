import Foundation
import Observation
import SwiftData

/// Tracks listening sessions and persists playback progress.
/// This class is @MainActor to ensure safe SwiftData context access.
@MainActor
@Observable
final class SessionTracker {
  private var modelContext: ModelContext?
  private var currentSession: ListeningSession?
  private var pendingListeningTime: Double = 0
  private var lastSaveTime: Date = Date()

  /// Minimum interval between saves to avoid excessive context operations
  private let saveInterval: TimeInterval = 5.0

  /// Total seconds of listening time in the current session
  var totalSeconds: Double {
    currentSession?.duration ?? 0
  }

  func attachModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  /// Start a new listening session if one isn't already active
  func startSessionIfNeeded() {
    guard currentSession == nil else { return }

    let session = ListeningSession()
    currentSession = session
    modelContext?.insert(session)
    pendingListeningTime = 0
    lastSaveTime = Date()
  }

  /// Add listening time (called frequently during playback)
  /// Note: This does NOT trigger immediate saves - relies on SwiftData autosave
  func addListeningTime(_ delta: Double) {
    guard delta > 0 else { return }
    pendingListeningTime += delta
    currentSession?.duration += delta

    // SwiftData autosave handles persistence automatically
    // No explicit save calls to avoid CoreData context conflicts
  }

  /// Persist current playback progress (called on pause/stop)
  func persistProgress() {
    // SwiftData autosave handles this automatically
    // This method is kept for explicit save points (app termination)
    do {
      try modelContext?.save()
    } catch {
      // Silently fail - autosave will pick up changes
      print("[SessionTracker] Failed to save: \(error.localizedDescription)")
    }
  }

  /// End the current session if one is active
  func endSessionIfIdle() {
    guard let session = currentSession else { return }

    session.endedAt = Date()
    currentSession = nil
    pendingListeningTime = 0

    // Save on session end
    do {
      try modelContext?.save()
    } catch {
      print("[SessionTracker] Failed to save session end: \(error.localizedDescription)")
    }
  }
}
