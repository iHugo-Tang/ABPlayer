import Foundation
import SwiftData
import SwiftUI
import Observation

@Observable
@MainActor
final class TranscriptionViewModel {
  // MARK: - Dependencies
  var transcriptionManager: TranscriptionManager?
  var queueManager: TranscriptionQueueManager?
  var settings: TranscriptionSettings?
  var modelContext: ModelContext?
  
  // MARK: - Data Source
  var audioFile: ABFile?
  
  // MARK: - State
  var cachedCues: [SubtitleCue] = []
  var hasCheckedCache: Bool = false
  var isLoadingCache: Bool = false
  var pauseCountdown: Int?
  
  private var loadCachedTask: Task<Void, Never>?
  
  // MARK: - Persistence
  var subtitleFontSize: Double {
    didSet {
      UserDefaults.standard.set(subtitleFontSize, forKey: "subtitleFontSize")
    }
  }
  
  // MARK: - Initialization
  init() {
    let storedSize = UserDefaults.standard.double(forKey: "subtitleFontSize")
    self.subtitleFontSize = storedSize > 0 ? storedSize : 16.0
  }
  
  // MARK: - Setup
  func setup(
    audioFile: ABFile,
    transcriptionManager: TranscriptionManager,
    queueManager: TranscriptionQueueManager,
    settings: TranscriptionSettings,
    modelContext: ModelContext
  ) {
    self.audioFile = audioFile
    self.transcriptionManager = transcriptionManager
    self.queueManager = queueManager
    self.settings = settings
    self.modelContext = modelContext
    
    // Reset state if file changed or not loaded
    if cachedCues.isEmpty && !hasCheckedCache && !isLoadingCache {
      Task { await loadCachedTranscription() }
    }
  }
  
  func resetState() {
    cachedCues = []
    hasCheckedCache = false
    isLoadingCache = false
    transcriptionManager?.reset()
  }
  
  // MARK: - Logic
  
  var currentTask: TranscriptionTask? {
    guard let fileId = audioFile?.id, let queueManager = queueManager else { return nil }
    return queueManager.getTask(for: fileId)
  }
  
  func loadCachedTranscription() async {
    guard let audioFile = audioFile, let modelContext = modelContext else { return }
    
    loadCachedTask?.cancel()
    loadCachedTask = Task {
      isLoadingCache = true
      defer { isLoadingCache = false }

      // Artificial delay for smooth UI if needed, or remove
      try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
      guard !Task.isCancelled else { return }

      // 1. Check SRT file
      if audioFile.hasTranscriptionRecord
        || FileManager.default.fileExists(atPath: audioFile.srtFileURL?.path ?? "")
      {
        guard !Task.isCancelled else { return }
        if let srtCues = await loadSRTFile(audioFile: audioFile) {
          cachedCues = srtCues
          hasCheckedCache = true
          return
        }
      }

      // 2. Check Database
      let audioFileId = audioFile.id.uuidString
      let descriptor = FetchDescriptor<Transcription>(
        predicate: #Predicate { $0.audioFileId == audioFileId }
      )

      guard !Task.isCancelled else { return }
      if let cached = try? modelContext.fetch(descriptor).first {
        cachedCues = cached.cues
      }
      hasCheckedCache = true
    }
  }
  
  private func loadSRTFile(audioFile: ABFile) async -> [SubtitleCue]? {
    guard let srtURL = audioFile.srtFileURL else { return nil }

    // Security-scoped access
    guard let audioURL = try? resolveURL(from: audioFile.bookmarkData) else { return nil }

    let gotAccess = audioURL.startAccessingSecurityScopedResource()
    defer { if gotAccess { audioURL.stopAccessingSecurityScopedResource() } }

    return try? await Task.detached {
      try SubtitleParser.parse(from: srtURL)
    }.value
  }
  
  func startTranscription() {
    guard let audioFile = audioFile, let queueManager = queueManager, let modelContext = modelContext else { return }
    
    // Set modelContext on queue manager if needed
    if queueManager.modelContext == nil {
      queueManager.modelContext = modelContext
    }
    // Enqueue the transcription task
    queueManager.enqueue(audioFile: audioFile)
  }
  
  func clearAndRetranscribe() async {
    guard let audioFile = audioFile, let modelContext = modelContext else { return }
    
    let audioFileId = audioFile.id.uuidString
    let descriptor = FetchDescriptor<Transcription>(
      predicate: #Predicate { $0.audioFileId == audioFileId }
    )

    if let existing = try? modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
      try? modelContext.save()
    }

    if let srtURL = audioFile.srtFileURL {
      if let audioURL = try? resolveURL(from: audioFile.bookmarkData),
        audioURL.startAccessingSecurityScopedResource()
      {
        try? FileManager.default.removeItem(at: srtURL)
        audioURL.stopAccessingSecurityScopedResource()
      }
    }
    audioFile.hasTranscriptionRecord = false

    // Reset state and start fresh transcription
    resetState()
    startTranscription()
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
  
  func cancelDownload(modelName: String) {
    transcriptionManager?.cancelDownload()
    settings?.deleteDownloadCache(modelName: modelName)
  }
  
  func removeTask(id: UUID) {
    queueManager?.removeTask(id: id)
  }
  
  func cancelTask(id: UUID) {
    queueManager?.cancelTask(id: id)
  }
}
