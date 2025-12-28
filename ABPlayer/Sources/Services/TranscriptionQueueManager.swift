import Foundation
import Observation
import SwiftData

/// Status of a transcription task
enum TranscriptionTaskStatus: Equatable {
  case queued
  case downloading(progress: Double)
  case loading
  case transcribing(progress: Double)
  case completed
  case failed(String)
  case cancelled
}

/// A transcription task in the queue
struct TranscriptionTask: Identifiable, Equatable {
  let id: UUID
  let audioFileId: UUID
  let audioFileName: String
  let bookmarkData: Data
  var status: TranscriptionTaskStatus

  init(
    id: UUID = UUID(),
    audioFileId: UUID,
    audioFileName: String,
    bookmarkData: Data,
    status: TranscriptionTaskStatus = .queued
  ) {
    self.id = id
    self.audioFileId = audioFileId
    self.audioFileName = audioFileName
    self.bookmarkData = bookmarkData
    self.status = status
  }
}

/// Manages transcription queue - processes one audio file at a time
@MainActor
@Observable
final class TranscriptionQueueManager {
  private let transcriptionManager: TranscriptionManager
  private let settings: TranscriptionSettings

  /// All tasks (pending + completed)
  private(set) var tasks: [TranscriptionTask] = []

  /// Current processing task
  private var processingTask: Task<Void, Never>?

  /// ModelContext for saving results
  var modelContext: ModelContext?

  init(
    transcriptionManager: TranscriptionManager,
    settings: TranscriptionSettings
  ) {
    self.transcriptionManager = transcriptionManager
    self.settings = settings
  }

  /// Get task for a specific audio file
  func getTask(for audioFileId: UUID) -> TranscriptionTask? {
    tasks.first { $0.audioFileId == audioFileId }
  }

  /// Check if a file has a pending or active task
  func hasPendingTask(for audioFileId: UUID) -> Bool {
    guard let task = getTask(for: audioFileId) else { return false }
    switch task.status {
    case .queued, .downloading, .loading, .transcribing:
      return true
    case .completed, .failed, .cancelled:
      return false
    }
  }

  /// Enqueue a new transcription task
  func enqueue(audioFile: AudioFile) {
    // Don't add if already in queue
    if getTask(for: audioFile.id) != nil {
      return
    }

    let task = TranscriptionTask(
      audioFileId: audioFile.id,
      audioFileName: audioFile.displayName,
      bookmarkData: audioFile.bookmarkData
    )

    tasks.append(task)

    // Start processing if not already running
    if processingTask == nil {
      processingTask = Task {
        await processQueue()
      }
    }
  }

  /// Cancel a task
  func cancelTask(id: UUID) {
    guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

    let task = tasks[index]
    switch task.status {
    case .queued:
      // Just mark as cancelled
      tasks[index].status = .cancelled
    case .downloading, .loading, .transcribing:
      // Cancel current transcription
      transcriptionManager.cancelDownload()
      tasks[index].status = .cancelled
    default:
      break
    }
  }

  /// Remove a task from the list
  func removeTask(id: UUID) {
    tasks.removeAll { $0.id == id }
  }

  /// Clear completed/failed/cancelled tasks
  func clearFinishedTasks() {
    tasks.removeAll { task in
      switch task.status {
      case .completed, .failed, .cancelled:
        return true
      default:
        return false
      }
    }
  }

  // MARK: - Private

  private func processQueue() async {
    while let nextTask = nextPendingTask() {
      await processTask(nextTask)
    }
    processingTask = nil
  }

  private func nextPendingTask() -> TranscriptionTask? {
    tasks.first { $0.status == .queued }
  }

  private func processTask(_ task: TranscriptionTask) async {
    guard tasks.contains(where: { $0.id == task.id }) else { return }

    do {
      // Resolve URL
      let url = try resolveURL(from: task.bookmarkData)

      // Track transcription manager state changes
      let stateObservation = Task { @MainActor in
        while !Task.isCancelled {
          await updateTaskFromManagerState(taskId: task.id)
          try? await Task.sleep(for: .milliseconds(100))
        }
      }

      defer { stateObservation.cancel() }

      // Perform transcription
      let cues = try await transcriptionManager.transcribe(
        audioURL: url,
        settings: settings
      )

      // Mark as completed
      if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
        tasks[idx].status = .completed
      }

      // Save results
      await saveTranscriptionResult(
        audioFileId: task.audioFileId,
        audioFileName: task.audioFileName,
        cues: cues,
        bookmarkData: task.bookmarkData
      )

      transcriptionManager.reset()

    } catch is CancellationError {
      if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
        tasks[idx].status = .cancelled
      }
      transcriptionManager.reset()
    } catch {
      if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
        tasks[idx].status = .failed(error.localizedDescription)
      }
      transcriptionManager.reset()
    }
  }

  private func updateTaskFromManagerState(taskId: UUID) async {
    guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

    switch transcriptionManager.state {
    case .downloading(let progress, _):
      if tasks[index].status != .downloading(progress: progress) {
        tasks[index].status = .downloading(progress: progress)
      }
    case .loading:
      if tasks[index].status != .loading {
        tasks[index].status = .loading
      }
    case .transcribing(let progress, _):
      if tasks[index].status != .transcribing(progress: progress) {
        tasks[index].status = .transcribing(progress: progress)
      }
    default:
      break
    }
  }

  private func resolveURL(from bookmarkData: Data) throws -> URL {
    var isStale = false
    return try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
  }

  private func saveTranscriptionResult(
    audioFileId: UUID,
    audioFileName: String,
    cues: [SubtitleCue],
    bookmarkData: Data
  ) async {
    // Save SRT file
    guard let audioURL = try? resolveURL(from: bookmarkData) else { return }

    let gotAccess = audioURL.startAccessingSecurityScopedResource()
    defer { if gotAccess { audioURL.stopAccessingSecurityScopedResource() } }

    let srtURL = audioURL.deletingPathExtension().appendingPathExtension("srt")
    do {
      try SubtitleParser.writeSRT(cues: cues, to: srtURL)
    } catch {
      print("Failed to save SRT: \(error)")
    }

    // Save to database if modelContext available
    guard let context = modelContext else { return }

    let audioFileIdString = audioFileId.uuidString
    let descriptor = FetchDescriptor<Transcription>(
      predicate: #Predicate { $0.audioFileId == audioFileIdString }
    )

    if let existing = try? context.fetch(descriptor).first {
      existing.cues = cues
      existing.createdAt = Date()
      existing.modelUsed = settings.modelName
      existing.language = settings.language
    } else {
      let cache = Transcription(
        audioFileId: audioFileIdString,
        audioFileName: audioFileName,
        cues: cues,
        modelUsed: settings.modelName,
        language: settings.language == "auto" ? nil : settings.language
      )
      context.insert(cache)
    }

    try? context.save()

    // Update hasTranscription flag
    let audioDescriptor = FetchDescriptor<AudioFile>(
      predicate: #Predicate { $0.id == audioFileId }
    )
    if let audioFile = try? context.fetch(audioDescriptor).first {
      audioFile.hasTranscription = true
      try? context.save()
    }
  }
}
