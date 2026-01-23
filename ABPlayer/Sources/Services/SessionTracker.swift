import Foundation
import OSLog
import Observation
import SwiftData

/// Background actor to handle SwiftData operations for listening sessions.
/// This ensures all database operations happen off the main thread.
@ModelActor
actor SessionRecorder {
  private var currentSessionID: PersistentIdentifier?

  /// Start a new session on the background context
  func startNewSession() {
    let session = ListeningSession()
    modelContext.insert(session)
    do {
      try modelContext.save()
      currentSessionID = session.persistentModelID
    } catch {
      Logger.data.error("[SessionRecorder] Failed to start session: \(error)")
      currentSessionID = nil
    }
  }

  /// Add listening time to the current session
  func addTime(_ delta: Double) {
    // If no active session, start one
    guard let id = currentSessionID else {
      Logger.data.info("[SessionRecorder] No active session, starting new one")
      startNewSession()
      return
    }

    // Try to fetch the session - it may have been invalidated
    guard let session = modelContext.model(for: id) as? ListeningSession else {
      Logger.data.warning(
        "[SessionRecorder] Session invalidated (ID: \(String(describing: id))), starting fresh session"
      )
      currentSessionID = nil
      startNewSession()
      return
    }

    if session.isDeleted {
      Logger.data.warning(
        "[SessionRecorder] Session invalidated (ID: \(String(describing: id))), starting fresh session"
      )
      currentSessionID = nil
      startNewSession()
      return
    }

    // Autosave will handle this eventually, but we save periodically
    // to ensure data isn't lost if app crashes
    do {
      session.duration += delta
      try modelContext.save()
    } catch {
      Logger.data.error("[SessionRecorder] Failed to save time update: \(error)")
      // If save fails, the session may be corrupted - reset for next time
      currentSessionID = nil
    }
  }

  /// End the current session
  func endSession() {
    guard let id = currentSessionID else { return }

    // Try to fetch the session - it may have been invalidated
    guard let session = modelContext.model(for: id) as? ListeningSession else {
      Logger.data.warning("[SessionRecorder] Cannot end session - already invalidated")
      currentSessionID = nil
      return
    }

    if session.isDeleted {
      Logger.data.warning(
        "[SessionRecorder] Session invalidated (ID: \(String(describing: id))), starting fresh session"
      )
      currentSessionID = nil
      startNewSession()
      return
    }

    do {
      session.endedAt = Date()
      try modelContext.save()
    } catch {
      Logger.data.error("[SessionRecorder] Failed to save session end: \(error)")
    }
    currentSessionID = nil
  }
}

/// Tracks listening sessions and persists playback progress.
/// This class is @MainActor to ensure safe UI binding interactions.
@MainActor
@Observable
final class SessionTracker {
  private var recorder: SessionRecorder?

  // Buffered state
  private var bufferedListeningTime: Double = 0
  private var lastCommitTime: Date = Date()
  private let commitInterval: TimeInterval = 5

  // UI State (throttled to 1-second precision for display)
  private var _totalSeconds: Double = 0
  private(set) var displaySeconds: Int = 0
  private var isSessionActive = false

  /// Initialize the recorder with a ModelContainer.
  /// This must be called before using the tracker.
  func setModelContainer(_ container: ModelContainer) {
    self.recorder = SessionRecorder(modelContainer: container)
  }

  /// Start a new listening session if one isn't already active
  func startSessionIfNeeded() {
    guard !isSessionActive else { return }
    isSessionActive = true

    // Reset local state
    _totalSeconds = 0
    displaySeconds = 0
    bufferedListeningTime = 0
    lastCommitTime = Date()

    // Start session in background
    Task {
      await recorder?.startNewSession()
    }
  }

  /// Reset the current session and start a new one immediately
  func resetSession() {
    if isSessionActive {
      commitPendingTime()
      Task {
        await recorder?.endSession()
      }
    }
    
    isSessionActive = true
    _totalSeconds = 0
    displaySeconds = 0
    bufferedListeningTime = 0
    lastCommitTime = Date()
    
    Task {
      await recorder?.startNewSession()
    }
  }

  /// Add listening time (called frequently during playback)
  func addListeningTime(_ delta: Double) {
    guard isSessionActive else { return }
    guard delta > 0 else { return }

    _totalSeconds += delta

    let newDisplaySeconds = Int(_totalSeconds)
    if newDisplaySeconds != displaySeconds {
      displaySeconds = newDisplaySeconds
    }

    bufferedListeningTime += delta

    let now = Date()
    if now.timeIntervalSince(lastCommitTime) >= commitInterval {
      commitPendingTime()
    }
  }

  /// Commit currently buffered time to the background actor
  private func commitPendingTime() {
    guard bufferedListeningTime > 0 else { return }

    let amountToCommit = bufferedListeningTime
    // Reset buffer immediately on main thread to prevent double-commit
    bufferedListeningTime = 0
    lastCommitTime = Date()

    Task {
      await recorder?.addTime(amountToCommit)
    }
  }

  /// Persist current playback progress (called on pause/stop/background)
  func persistProgress() {
    commitPendingTime()
  }

  /// End the current session if one is active
  func endSessionIfIdle() {
    guard isSessionActive else { return }

    // Flush any remaining time
    commitPendingTime()

    isSessionActive = false

    Task {
      await recorder?.endSession()
    }
  }
}
