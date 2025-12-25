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
}

/// Manages audio transcription using WhisperKit
@MainActor
@Observable
final class TranscriptionManager {
  private var whisperKit: WhisperKit?
  private var loadedModelName: String?
  var state: TranscriptionState = .idle

  /// Whether the model is loaded and ready
  var isModelLoaded: Bool {
    whisperKit != nil
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
