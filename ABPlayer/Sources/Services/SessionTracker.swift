import Foundation
import Observation
import SwiftData

@Model
final class ListeningSession {
  var id: UUID
  var startedAt: Date
  var durationSeconds: Double
  var endedAt: Date?

  init(
    id: UUID = UUID(),
    startedAt: Date = Date(),
    durationSeconds: Double = 0,
    endedAt: Date? = nil
  ) {
    self.id = id
    self.startedAt = startedAt
    self.durationSeconds = durationSeconds
    self.endedAt = endedAt
  }
}

@MainActor
@Observable
final class SessionTracker {
  private weak var modelContext: ModelContext?
  private(set) var currentSession: ListeningSession?
  private(set) var totalSeconds: Double = 0

  private var lastSavedSeconds: Double = 0

  func attachModelContext(_ context: ModelContext) {
    modelContext = context
  }

  func startSessionIfNeeded() {
    guard currentSession == nil else {
      return
    }

    let session = ListeningSession()
    modelContext?.insert(session)
    currentSession = session
  }

  func addListeningTime(_ delta: Double) {
    guard delta > 0 else {
      return
    }

    startSessionIfNeeded()

    guard let session = currentSession else {
      return
    }

    // Verify the session is still valid (not deleted)
    if session.modelContext == nil {
      currentSession = nil
      lastSavedSeconds = 0
      return
    }

    session.durationSeconds += delta
    totalSeconds = session.durationSeconds

    if session.durationSeconds - lastSavedSeconds >= 5 {
      saveContext()
      lastSavedSeconds = session.durationSeconds
    }
  }

  private func saveContext() {
    guard let context = modelContext else { return }

    // Verify the current session is still valid before saving
    // This prevents crashes when the session is deleted while playback is active
    guard let session = currentSession else { return }

    // Check if the session is still in this context
    // If it's been deleted, we shouldn't try to save
    if session.modelContext == nil {
      // Session was deleted, clear our reference
      currentSession = nil
      lastSavedSeconds = 0
      return
    }

    // Only save if there are pending changes
    guard context.hasChanges else { return }

    do {
      try context.save()
    } catch {
      // Log the error but don't crash - the data will be saved on next attempt
      print("⚠️ SessionTracker save failed: \(error.localizedDescription)")
      if let nsError = error as NSError? {
        print("   Error domain: \(nsError.domain), code: \(nsError.code)")
        print("   User info: \(nsError.userInfo)")
      }
    }
  }

  func persistProgress() {
    saveContext()
    if let session = currentSession {
      lastSavedSeconds = session.durationSeconds
    }
  }

  func endSessionIfIdle() {
    guard let session = currentSession else {
      return
    }

    // Verify the session is still valid (not deleted)
    guard session.modelContext != nil else {
      currentSession = nil
      lastSavedSeconds = 0
      return
    }

    if session.endedAt == nil {
      session.endedAt = Date()
    }

    totalSeconds = session.durationSeconds
    saveContext()

    currentSession = nil
    lastSavedSeconds = 0
  }
}
