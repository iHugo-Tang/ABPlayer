import Foundation
import Observation
@preconcurrency import WhisperKit

/// Transcription progress and state
enum TranscriptionState: Equatable {
  case idle
  case downloading(progress: Double, modelName: String)
  case loading(modelName: String)
  case transcribing(progress: Double, fileName: String)
  case completed
  case failed(String)
  case cancelled
}

/// Manages audio transcription using WhisperKit
@MainActor
@Observable
final class TranscriptionManager {
  private var whisperKit: WhisperKit?
  private var loadedModelName: String?
  private var downloadTask: Task<Void, Error>?
  var state: TranscriptionState = .idle

  /// Whether the model is loaded and ready
  var isModelLoaded: Bool {
    whisperKit != nil
  }

  /// Download model with progress tracking
  func downloadModel(
    modelName: String,
    downloadBase: URL,
    progressCallback: (@Sendable (Double) -> Void)? = nil
  ) async throws {
    // If already downloading (and correct model), return
    if case .downloading(_, let currentName) = state, currentName == modelName {
      return
    }

    state = .downloading(progress: 0, modelName: modelName)

    let task = Task {
      _ = try await WhisperKit.download(
        variant: modelName,
        downloadBase: downloadBase,
        progressCallback: { @Sendable [weak self] progress in
          Task { @MainActor [weak self] in
            guard let self else { return }
            // Update state
            if case .downloading(_, let currentName) = self.state, currentName == modelName {
              self.state = .downloading(progress: progress.fractionCompleted, modelName: modelName)
            }
            // Process callback
            progressCallback?(progress.fractionCompleted)
          }
        }
      )
    }

    downloadTask = task

    do {
      try await task.value
      downloadTask = nil

      if case .cancelled = state {
        throw CancellationError()
      }
    } catch is CancellationError {
      downloadTask = nil
      state = .cancelled
      throw CancellationError()
    } catch let urlError as URLError where urlError.code == .cancelled {
      // URLSession throws URLError.cancelled instead of CancellationError
      downloadTask = nil
      state = .cancelled
      throw CancellationError()
    } catch {
      downloadTask = nil
      state = .failed("Failed to download model: \(error.localizedDescription)")
      throw error
    }
  }

  /// Cancel current download
  func cancelDownload() {
    downloadTask?.cancel()
    state = .cancelled
  }

  /// Initialize WhisperKit with the specified model and download folder
  func loadModel(
    modelName: String = "distil-large-v3",
    downloadBase: URL
  ) async throws {
    // Reload if model name changed
    if whisperKit != nil && loadedModelName == modelName {
      return
    }

    // Ensure model is downloaded first (with progress)
    try await downloadModel(modelName: modelName, downloadBase: downloadBase)

    if case .cancelled = state {
      throw CancellationError()
    }

    state = .loading(modelName: modelName)
    do {
      let config = WhisperKitConfig(
        model: modelName,
        downloadBase: downloadBase
      )

      whisperKit = try await WhisperKit(config)
      loadedModelName = modelName
      state = .idle
    } catch {
      state = .failed("Failed to load model: \(error.localizedDescription)")
      throw error
    }
  }

  /// Transcribe audio file using settings
  func transcribe(
    audioURL: URL,
    settings: TranscriptionSettings
  ) async throws -> [SubtitleCue] {
    let fileName = audioURL.lastPathComponent

    // Load model if not already loaded or if model changed
    if whisperKit == nil || loadedModelName != settings.modelName {
      try await loadModel(
        modelName: settings.modelName,
        downloadBase: settings.modelDirectoryURL
      )
    }

    guard let kit = whisperKit else {
      throw TranscriptionError.modelNotLoaded
    }

    state = .transcribing(progress: 0, fileName: fileName)

    do {
      // Start accessing security-scoped resource
      guard audioURL.startAccessingSecurityScopedResource() else {
        throw TranscriptionError.accessDenied
      }

      // Configure language if not auto-detect
      let language = settings.language == "auto" ? nil : settings.language
      let audioPath = audioURL.path
      let options = DecodingOptions(language: language)

      // Perform transcription - capture values needed, not the reference
      let results: [TranscriptionResult] = try await kit.transcribe(
        audioPath: audioPath,
        decodeOptions: options
      )

      audioURL.stopAccessingSecurityScopedResource()

      // Flatten all segments from all results and convert to SubtitleCue
      let cues: [SubtitleCue] = results.flatMap { result in
        result.segments.map { segment in
          SubtitleCue(
            startTime: Double(segment.start),
            endTime: Double(segment.end),
            text: cleanTranscriptionText(segment.text)
          )
        }
      }

      state = .completed
      return cues
    } catch is CancellationError {
      audioURL.stopAccessingSecurityScopedResource()
      // Keep cancelled state, don't override with failed
      throw CancellationError()
    } catch {
      audioURL.stopAccessingSecurityScopedResource()
      state = .failed(error.localizedDescription)
      throw error
    }
  }

  /// Transcribe audio file with default settings (for backwards compatibility)
  func transcribe(audioURL: URL) async throws -> [SubtitleCue] {
    try await transcribe(audioURL: audioURL, settings: TranscriptionSettings())
  }

  /// Reset state to idle
  func reset() {
    state = .idle
  }

  // MARK: - Text Cleaning

  /// Remove timestamp patterns like <|16.64|> from transcription text
  private func cleanTranscriptionText(_ text: String) -> String {
    // Pattern matches <|anything|> including timestamps like <|16.64|>
    let pattern = "<\\|[^>]*\\|>"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return text.trimmingCharacters(in: .whitespaces)
    }

    let range = NSRange(text.startIndex..., in: text)
    let cleaned = regex.stringByReplacingMatches(
      in: text,
      options: [],
      range: range,
      withTemplate: ""
    )

    return cleaned.trimmingCharacters(in: .whitespaces)
  }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
  case modelNotLoaded
  case accessDenied
  case transcriptionFailed(String)

  var errorDescription: String? {
    switch self {
    case .modelNotLoaded:
      return "WhisperKit model is not loaded"
    case .accessDenied:
      return "Cannot access the audio file"
    case .transcriptionFailed(let reason):
      return "Transcription failed: \(reason)"
    }
  }
}
