import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Handles recursive folder import with automatic file pairing
@MainActor
final class FolderImporter {
  private let modelContext: ModelContext

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  /// Supported file extensions
  static let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "aac"]
  static let subtitleExtensions: Set<String> = ["srt", "vtt"]
  static let pdfExtension = "pdf"

  /// Import a folder recursively
  /// - Parameter url: Root folder URL
  /// - Returns: The created root Folder, or nil if import failed
  func importFolder(at url: URL) throws -> Folder? {
    guard url.startAccessingSecurityScopedResource() else {
      throw ImportError.accessDenied
    }

    defer {
      url.stopAccessingSecurityScopedResource()
    }

    return try processDirectory(at: url, parent: nil)
  }

  /// Process a directory and its contents recursively
  private func processDirectory(at url: URL, parent: Folder?) throws -> Folder {
    let folder = Folder(name: url.lastPathComponent, parent: parent)
    modelContext.insert(folder)

    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    // Separate files from directories
    var directories: [URL] = []
    var audioFiles: [URL] = []
    var subtitleFiles: [URL] = []
    var pdfFiles: [URL] = []

    for item in contents {
      let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])

      if resourceValues.isDirectory == true {
        directories.append(item)
      } else {
        let ext = item.pathExtension.lowercased()

        if Self.audioExtensions.contains(ext) {
          audioFiles.append(item)
        } else if Self.subtitleExtensions.contains(ext) {
          subtitleFiles.append(item)
        } else if ext == Self.pdfExtension {
          pdfFiles.append(item)
        }
      }
    }

    // Process audio files with auto-pairing
    for audioURL in audioFiles {
      try processAudioFile(
        at: audioURL,
        folder: folder,
        subtitleFiles: subtitleFiles,
        pdfFiles: pdfFiles
      )
    }

    // Process subdirectories recursively
    for dirURL in directories {
      let subfolder = try processDirectory(at: dirURL, parent: folder)
      folder.subfolders.append(subfolder)
    }

    return folder
  }

  /// Process an audio file and pair it with matching subtitle/PDF
  private func processAudioFile(
    at url: URL,
    folder: Folder,
    subtitleFiles: [URL],
    pdfFiles: [URL]
  ) throws {
    let bookmarkData = try url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )

    let audioFile = AudioFile(
      displayName: url.lastPathComponent,
      bookmarkData: bookmarkData,
      folder: folder
    )
    modelContext.insert(audioFile)
    folder.audioFiles.append(audioFile)

    let baseName = url.deletingPathExtension().lastPathComponent

    // Auto-pair subtitle
    if let subtitleURL = findMatchingFile(baseName: baseName, in: subtitleFiles) {
      try pairSubtitle(at: subtitleURL, with: audioFile)
    }

    // Auto-pair PDF
    if let pdfURL = findMatchingFile(baseName: baseName, in: pdfFiles) {
      try pairPDF(at: pdfURL, with: audioFile)
    }
  }

  /// Find a file with matching base name
  private func findMatchingFile(baseName: String, in files: [URL]) -> URL? {
    return files.first { url in
      url.deletingPathExtension().lastPathComponent.lowercased() == baseName.lowercased()
    }
  }

  /// Pair a subtitle file with an audio file
  private func pairSubtitle(at url: URL, with audioFile: AudioFile) throws {
    let bookmarkData = try url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )

    let subtitleFile = SubtitleFile(
      displayName: url.lastPathComponent,
      bookmarkData: bookmarkData,
      audioFile: audioFile
    )

    // Parse and cache subtitle cues
    if url.startAccessingSecurityScopedResource() {
      defer { url.stopAccessingSecurityScopedResource() }
      subtitleFile.cues = (try? SubtitleParser.parse(from: url)) ?? []
    }

    modelContext.insert(subtitleFile)
    audioFile.subtitleFile = subtitleFile
  }

  /// Pair a PDF file with an audio file
  private func pairPDF(at url: URL, with audioFile: AudioFile) throws {
    let bookmarkData = try url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )

    audioFile.pdfBookmarkData = bookmarkData
  }
}

// MARK: - Errors

enum ImportError: LocalizedError {
  case accessDenied
  case invalidDirectory

  var errorDescription: String? {
    switch self {
    case .accessDenied:
      return "Unable to access the selected folder"
    case .invalidDirectory:
      return "The selected path is not a valid directory"
    }
  }
}
