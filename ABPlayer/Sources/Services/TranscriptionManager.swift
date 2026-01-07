import Foundation
import Observation
@preconcurrency import WhisperKit

/// Transcription progress and state
enum TranscriptionState: Equatable {
  case idle
  case downloading(progress: Double, modelName: String)
  case loading(modelName: String)
  case extractingAudio(progress: Double, fileName: String)
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
    if whisperKit != nil && loadedModelName == modelName {
      return
    }

    if isModelDownloaded(modelName: modelName, downloadBase: downloadBase) {
      state = .loading(modelName: modelName)
    } else {
      do {
        try await downloadModel(modelName: modelName, downloadBase: downloadBase)
      } catch is CancellationError {
        state = .cancelled
        throw CancellationError()
      }
    }

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

    if whisperKit == nil || loadedModelName != settings.modelName {
      do {
        try await loadModel(
          modelName: settings.modelName,
          downloadBase: settings.modelDirectoryURL
        )
      } catch is CancellationError {
        state = .cancelled
        throw CancellationError()
      }
    }

    guard let kit = whisperKit else {
      throw TranscriptionError.modelNotLoaded
    }

    state = .transcribing(progress: 0, fileName: fileName)
    
    var extractedWavURL: URL?
    var workingURL = audioURL
    
    do {
      guard audioURL.startAccessingSecurityScopedResource() else {
        throw TranscriptionError.accessDenied
      }

      if isVideoFile(audioURL) {
        extractedWavURL = try await extractAudio(from: audioURL, settings: settings)
        workingURL = extractedWavURL!
      }

      let language = settings.language == "auto" ? nil : settings.language
      let audioPath = workingURL.path
      let options = DecodingOptions(language: language)

      let results: [TranscriptionResult] = try await kit.transcribe(
        audioPath: audioPath,
        decodeOptions: options
      )

      audioURL.stopAccessingSecurityScopedResource()
      
      if let wavURL = extractedWavURL {
        try? FileManager.default.removeItem(at: wavURL)
      }

      let cues: [SubtitleCue] = results.flatMap { result in
        result.segments.compactMap { segment in
          let cleanedText = cleanTranscriptionText(segment.text)
          
          guard !cleanedText.isEmpty,
                segment.end > segment.start else {
            return nil
          }
          
          return SubtitleCue(
            startTime: Double(segment.start),
            endTime: Double(segment.end),
            text: cleanedText
          )
        }
      }

      state = .completed
      return cues
    } catch is CancellationError {
      audioURL.stopAccessingSecurityScopedResource()
      if let wavURL = extractedWavURL {
        try? FileManager.default.removeItem(at: wavURL)
      }
      throw CancellationError()
    } catch {
      audioURL.stopAccessingSecurityScopedResource()
      if let wavURL = extractedWavURL {
        try? FileManager.default.removeItem(at: wavURL)
      }
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

  // MARK: - Model Checking

  private func isModelDownloaded(modelName: String, downloadBase: URL) -> Bool {
    let whisperKitModelPath = downloadBase
      .appendingPathComponent("models")
      .appendingPathComponent("argmaxinc")
      .appendingPathComponent("whisperkit-coreml")
      .appendingPathComponent("distil-whisper_" + modelName)
    
    guard FileManager.default.fileExists(atPath: whisperKitModelPath.path) else {
      return false
    }
    
    let requiredModelFiles = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
    
    for requiredModel in requiredModelFiles {
      let compiledModelPath = whisperKitModelPath.appendingPathComponent("\(requiredModel).mlmodelc")
      let packageModelPath = whisperKitModelPath.appendingPathComponent("\(requiredModel).mlpackage")
      
      let hasCompiledModel = FileManager.default.fileExists(atPath: compiledModelPath.path)
      let hasPackageModel = FileManager.default.fileExists(atPath: packageModelPath.path)
      
      if !hasCompiledModel && !hasPackageModel {
        return false
      }
    }
    
    return true
  }

  // MARK: - Audio Extraction

  private func extractAudio(from videoURL: URL, settings: TranscriptionSettings) async throws -> URL {
    let fileName = videoURL.lastPathComponent
    state = .extractingAudio(progress: 0, fileName: fileName)

    let tempDir = FileManager.default.temporaryDirectory
    let wavFileName = videoURL.deletingPathExtension().lastPathComponent + "_extracted.wav"
    let wavURL = tempDir.appendingPathComponent(wavFileName)

    try? FileManager.default.removeItem(at: wavURL)

    guard let ffmpegPath = settings.effectiveFFmpegPath() else {
      throw TranscriptionError.audioExtractionFailed(
        "FFmpeg not found. Please install FFmpeg or configure the path in Settings."
      )
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: ffmpegPath)
    process.arguments = [
      "-i", videoURL.path,
      "-vn",
      "-ar", "16000",
      "-ac", "1",
      "-c:a", "pcm_s16le",
      "-y",
      wavURL.path
    ]

    let errorPipe = Pipe()
    process.standardError = errorPipe
    process.standardOutput = Pipe()

    return try await withCheckedThrowingContinuation { continuation in
      Task.detached {
        do {
          try process.run()
          process.waitUntilExit()

          let exitCode = process.terminationStatus
          if exitCode == 0 {
            await MainActor.run {
              self.state = .extractingAudio(progress: 1.0, fileName: fileName)
            }
            continuation.resume(returning: wavURL)
          } else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            continuation.resume(
              throwing: TranscriptionError.audioExtractionFailed(
                "ffmpeg failed with code \(exitCode): \(errorMessage)"
              )
            )
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func isVideoFile(_ url: URL) -> Bool {
    let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
    return videoExtensions.contains(url.pathExtension.lowercased())
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
  case audioExtractionFailed(String)
  case transcriptionFailed(String)

  var errorDescription: String? {
    switch self {
    case .modelNotLoaded:
      return "WhisperKit model is not loaded"
    case .accessDenied:
      return "Cannot access the audio file"
    case .audioExtractionFailed(let reason):
      return "Audio extraction failed: \(reason)"
    case .transcriptionFailed(let reason):
      return "Transcription failed: \(reason)"
    }
  }
}
