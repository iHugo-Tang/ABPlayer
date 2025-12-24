import Foundation
import SwiftUI

/// User configurable transcription settings
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

  // MARK: - Computed Properties

  /// Returns the model directory URL, or nil for default location
  var modelDirectoryURL: URL? {
    guard !modelDirectory.isEmpty else { return nil }
    return URL(fileURLWithPath: modelDirectory)
  }

  /// Default model directory in Application Support
  static var defaultModelDirectory: URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    return appSupport.appendingPathComponent("ABPlayer/WhisperKitModels", isDirectory: true)
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
  func listDownloadedModels() -> [(name: String, size: Int64)] {
    let dir = modelDirectoryURL ?? TranscriptionSettings.defaultModelDirectory
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: dir.path) else { return [] }

    do {
      let contents = try fileManager.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey],
        options: [.skipsHiddenFiles]
      )

      return contents.compactMap { url -> (String, Int64)? in
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir),
          isDir.boolValue
        else { return nil }

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
    let dir = modelDirectoryURL ?? TranscriptionSettings.defaultModelDirectory
    let modelDir = dir.appendingPathComponent(name)
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

  /// Calculate total size of a directory
  private static func directorySize(at url: URL) -> Int64 {
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
}
