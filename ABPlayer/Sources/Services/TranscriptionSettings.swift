import Foundation
import SwiftUI

/// User configurable transcription settings
@MainActor
@Observable
final class TranscriptionSettings {
  /// Whether transcription feature is enabled
  @ObservationIgnored
  @AppStorage("transcription_enabled") var isEnabled: Bool = true

  /// WhisperKit model to use
  @ObservationIgnored
  @AppStorage("transcription_model") var modelName: String = "distil-large-v3"

  /// Language for transcription (auto = auto-detect)
  @ObservationIgnored
  @AppStorage("transcription_language") var language: String = "auto"

  /// Whether to automatically transcribe new audio files
  @ObservationIgnored
  @AppStorage("transcription_auto_transcribe") var autoTranscribe: Bool = false

  /// Custom model download directory (empty = default location)
  @ObservationIgnored
  @AppStorage("transcription_model_directory") var modelDirectory: String = ""

  /// Custom ffmpeg path (empty = auto-detect)
  @ObservationIgnored
  @AppStorage("transcription_ffmpeg_path") var ffmpegPath: String = ""

  // MARK: - Computed Properties

  /// Returns the model directory URL (user-specified or default)
  var modelDirectoryURL: URL {
    if modelDirectory.isEmpty {
      return TranscriptionSettings.defaultModelDirectory
    }
    return URL(fileURLWithPath: modelDirectory)
  }

  /// Default model directory in user home
  static var defaultModelDirectory: URL {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    return homeDir.appendingPathComponent(".abplayer", isDirectory: true)
  }

  // MARK: - Available Options

  /// Available WhisperKit models (from smallest to largest)
  static let availableModels: [(id: String, name: String)] = [
    ("tiny", "Tiny (~40MB, fastest)"),
    ("base", "Base (~80MB)"),
    ("small", "Small (~240MB)"),
    ("distil-large-v3", "Distil Large v3 (~700MB, recommended)"),
    ("large-v3", "Large v3 (~3GB, most accurate)"),
  ]

  /// Available languages for transcription
  static let availableLanguages: [(id: String, name: String)] = [
    ("auto", "Auto-detect"),
    ("en", "English"),
    ("zh", "Chinese"),
    ("ja", "Japanese"),
    ("ko", "Korean"),
    ("es", "Spanish"),
    ("fr", "French"),
    ("de", "German"),
  ]

  // MARK: - Model Management

  /// Returns list of downloaded models in the current model directory
  /// WhisperKit stores models at: models/argmaxinc/whisperkit-coreml/<model-name>/
  func listDownloadedModels() -> [(name: String, size: Int64)] {
    Self.listModelsSync(in: modelDirectoryURL)
  }

  /// Returns list of downloaded models asynchronously (non-blocking)
  func listDownloadedModelsAsync() async -> [(name: String, size: Int64)] {
    let url = modelDirectoryURL
    return await Task.detached(priority: .utility) {
      Self.listModelsSync(in: url)
    }.value
  }

  /// Synchronous helper for listing models (can run on background thread)
  nonisolated private static func listModelsSync(in baseDir: URL) -> [(name: String, size: Int64)] {
    let fileManager = FileManager.default

    // WhisperKit stores models in a nested structure
    let whisperKitDir =
      baseDir
      .appendingPathComponent("models", isDirectory: true)
      .appendingPathComponent("argmaxinc", isDirectory: true)
      .appendingPathComponent("whisperkit-coreml", isDirectory: true)

    guard fileManager.fileExists(atPath: whisperKitDir.path) else { return [] }

    do {
      let contents = try fileManager.contentsOfDirectory(
        at: whisperKitDir,
        includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey],
        options: [.skipsHiddenFiles]
      )

      return contents.compactMap { url -> (String, Int64)? in
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir),
          isDir.boolValue
        else { return nil }

        // Skip cache directories
        if url.lastPathComponent.hasPrefix(".") { return nil }

        // Check if it looks like a model directory (contains .mlmodelc or similar)
        let modelIndicators = ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "config.json"]
        let hasModelFiles = modelIndicators.contains { indicator in
          fileManager.fileExists(atPath: url.appendingPathComponent(indicator).path)
        }

        guard hasModelFiles else { return nil }

        let size = Self.directorySize(at: url)
        return (url.lastPathComponent, size)
      }.sorted { $0.name < $1.name }
    } catch {
      return []
    }
  }

  /// Delete a specific model from disk
  func deleteModel(named name: String) throws {
    let whisperKitDir =
      modelDirectoryURL
      .appendingPathComponent("models", isDirectory: true)
      .appendingPathComponent("argmaxinc", isDirectory: true)
      .appendingPathComponent("whisperkit-coreml", isDirectory: true)
    let modelDir = whisperKitDir.appendingPathComponent(name)
    try FileManager.default.removeItem(at: modelDir)
  }

  /// Move all models from old directory to new directory
  func migrateModels(from oldDir: URL, to newDir: URL) throws {
    let fileManager = FileManager.default

    // Create new directory if needed
    if !fileManager.fileExists(atPath: newDir.path) {
      try fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
    }

    guard fileManager.fileExists(atPath: oldDir.path) else { return }

    let contents = try fileManager.contentsOfDirectory(
      at: oldDir,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    for url in contents {
      var isDir: ObjCBool = false
      guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir),
        isDir.boolValue
      else { continue }

      let destURL = newDir.appendingPathComponent(url.lastPathComponent)
      if !fileManager.fileExists(atPath: destURL.path) {
        try fileManager.moveItem(at: url, to: destURL)
      }
    }
  }

  /// Delete download cache for a model
  func deleteDownloadCache(modelName: String) {
    let fileManager = FileManager.default

    // WhisperKit downloads to models/argmaxinc/whisperkit-coreml/<model-name>
    // Model names are prefixed like "openai_whisper-tiny" or "distil-whisper_distil-large-v3"
    let whisperKitDir =
      modelDirectoryURL
      .appendingPathComponent("models", isDirectory: true)
      .appendingPathComponent("argmaxinc", isDirectory: true)
      .appendingPathComponent("whisperkit-coreml", isDirectory: true)

    guard fileManager.fileExists(atPath: whisperKitDir.path) else { return }

    do {
      let contents = try fileManager.contentsOfDirectory(
        at: whisperKitDir,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )

      // Find and delete any folder containing the model name
      for url in contents {
        if url.lastPathComponent.contains(modelName) {
          try? fileManager.removeItem(at: url)
        }
      }

      // Also delete any temporary/incomplete download files
      let tempPatterns = [".tmp", ".download", ".partial"]
      for url in contents {
        let name = url.lastPathComponent
        if tempPatterns.contains(where: { name.contains($0) }) && name.contains(modelName) {
          try? fileManager.removeItem(at: url)
        }
      }
    } catch {
      // Ignore errors during cleanup
    }
  }

  /// Calculate total size of a directory
  nonisolated private static func directorySize(at url: URL) -> Int64 {
    let fileManager = FileManager.default
    var totalSize: Int64 = 0

    guard
      let enumerator = fileManager.enumerator(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles]
      )
    else { return 0 }

    for case let fileURL as URL in enumerator {
      if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
        totalSize += Int64(fileSize)
      }
    }

    return totalSize
  }

  /// Format byte size for display
  static func formatSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }

  // MARK: - FFmpeg Path Management

  /// Get the effective ffmpeg path (custom or auto-detected)
  func effectiveFFmpegPath() -> String? {
    if !ffmpegPath.isEmpty {
      if Self.isFFmpegValid(at: ffmpegPath) {
        return ffmpegPath
      }
    }
    return Self.autoDetectFFmpegPath()
  }

  /// Check if ffmpeg is valid and executable at the given path
  static func isFFmpegValid(at path: String) -> Bool {
    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
      !isDirectory.boolValue
    else {
      return false
    }

    guard fileManager.isExecutableFile(atPath: path) else {
      return false
    }

    return true
  }

  /// Auto-detect ffmpeg installation path
  static func autoDetectFFmpegPath() -> String? {
    let possiblePaths = [
      "/opt/homebrew/bin/ffmpeg",
      "/usr/local/bin/ffmpeg",
      "/opt/local/bin/ffmpeg",
      "/sw/bin/ffmpeg",
    ]

    for path in possiblePaths {
      if isFFmpegValid(at: path) {
        return path
      }
    }

    return nil
  }
}
