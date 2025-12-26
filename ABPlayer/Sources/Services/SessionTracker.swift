import Foundation
import SwiftData
import Observation

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

        session.durationSeconds += delta
        totalSeconds = session.durationSeconds

        if session.durationSeconds - lastSavedSeconds >= 5 {
            try? modelContext?.save()
            lastSavedSeconds = session.durationSeconds
        }
    }

    func persistProgress() {
        try? modelContext?.save()
        if let session = currentSession {
            lastSavedSeconds = session.durationSeconds
        }
    }

    func endSessionIfIdle() {
        guard let session = currentSession else {
            return
        }

        if session.endedAt == nil {
            session.endedAt = Date()
        }

        totalSeconds = session.durationSeconds
        try? modelContext?.save()

        currentSession = nil
        lastSavedSeconds = 0
    }
}

