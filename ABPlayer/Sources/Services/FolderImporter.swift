import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Handles recursive folder import with automatic file pairing
/// Supports idempotent sync operations (safe to call multiple times)
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

  // MARK: - Public API

  /// 同步文件夹（支持首次导入和重新扫描）
  /// - Parameter url: 根文件夹 URL
  /// - Returns: 同步后的根 Folder
  func syncFolder(at url: URL) throws -> Folder? {
    guard url.startAccessingSecurityScopedResource() else {
      throw ImportError.accessDenied
    }

    defer {
      url.stopAccessingSecurityScopedResource()
    }

    // 创建 bookmark 用于后续 rescan
    let bookmarkData = try url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )

    let rootPath = url.lastPathComponent
    let folder = try processDirectory(at: url, relativePath: rootPath, parent: nil)

    // 仅根文件夹存储 bookmark
    folder.bookmarkData = bookmarkData

    return folder
  }

  // MARK: - Directory Processing

  /// 处理目录及其内容（递归）
  private func processDirectory(at url: URL, relativePath: String, parent: Folder?) throws
    -> Folder
  {
    let folder = findOrCreateFolder(at: url, relativePath: relativePath)

    // 设置父子关系（如果需要）
    if let parent = parent, folder.parent?.id != parent.id {
      folder.parent = parent
      if !parent.subfolders.contains(where: { $0.id == folder.id }) {
        parent.subfolders.append(folder)
      }
    }

    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    // 分类文件
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

    // 处理音频文件（Insert-or-Update）
    for audioURL in audioFiles {
      try processAudioFile(
        at: audioURL,
        folder: folder,
        subtitleFiles: subtitleFiles,
        pdfFiles: pdfFiles
      )
    }

    // 递归处理子目录
    for dirURL in directories {
      let subPath = "\(relativePath)/\(dirURL.lastPathComponent)"
      _ = try processDirectory(at: dirURL, relativePath: subPath, parent: folder)
    }

    return folder
  }

  /// 查找或创建文件夹
  private func findOrCreateFolder(at url: URL, relativePath: String) -> Folder {
    let name = url.lastPathComponent
    let folderId = Folder.generateDeterministicID(from: relativePath)

    // 尝试查找已有记录
    let descriptor = FetchDescriptor<Folder>(
      predicate: #Predicate<Folder> { $0.id == folderId }
    )

    if let existing = try? modelContext.fetch(descriptor).first {
      return existing
    }

    // 创建新记录
    let folder = Folder(
      id: folderId,
      name: name,
      relativePath: relativePath,
      createdAt: getFileCreationDate(from: url)
    )
    modelContext.insert(folder)
    return folder
  }

  // MARK: - Audio File Handling

  /// 处理音频文件（Insert-or-Update）
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

    let deterministicID = AudioFile.generateDeterministicID(from: bookmarkData)

    // 尝试查找已有记录
    let descriptor = FetchDescriptor<AudioFile>(
      predicate: #Predicate<AudioFile> { $0.id == deterministicID }
    )

    let audioFile: AudioFile
    if let existing = try? modelContext.fetch(descriptor).first {
      audioFile = existing
      // 更新文件夹关联（如果需要）
      if audioFile.folder?.id != folder.id {
        audioFile.folder = folder
        if !folder.audioFiles.contains(where: { $0.id == audioFile.id }) {
          folder.audioFiles.append(audioFile)
        }
      }
    } else {
      // 创建新记录
      audioFile = AudioFile(
        id: deterministicID,
        displayName: url.lastPathComponent,
        bookmarkData: bookmarkData,
        createdAt: getFileCreationDate(from: url),
        folder: folder
      )
      modelContext.insert(audioFile)
      folder.audioFiles.append(audioFile)
    }

    let baseName = url.deletingPathExtension().lastPathComponent

    // 1. Sync Subtitle File
    if let subtitleURL = findMatchingFile(baseName: baseName, in: subtitleFiles) {
      if audioFile.subtitleFile == nil {
        try pairSubtitle(at: subtitleURL, with: audioFile)
      }
      // If needed we could update existing subtitle file content here
    } else {
      // If subtitle file no longer exists, remove relation
      if let existing = audioFile.subtitleFile {
        modelContext.delete(existing)
        audioFile.subtitleFile = nil
      }
    }

    // 2. Sync PDF File
    if let pdfURL = findMatchingFile(baseName: baseName, in: pdfFiles) {
      // Update bookmark even if exists to ensure valid access
      let pdfBookmark = try pdfURL.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      audioFile.pdfBookmarkData = pdfBookmark
    } else {
      // If PDF no longer exists, clear bookmark
      audioFile.pdfBookmarkData = nil
    }

    // 3. Sync Transcription Record
    let audioFileIdString = audioFile.id.uuidString
    let transcriptionDescriptor = FetchDescriptor<Transcription>(
      predicate: #Predicate { $0.audioFileId == audioFileIdString }
    )

    // Check if transcription record exists
    if (try? modelContext.fetch(transcriptionDescriptor).first) != nil {
      if !audioFile.hasTranscriptionRecord {
        audioFile.hasTranscriptionRecord = true
      }
    } else {
      // Only clear if true (avoid unnecessary writes)
      if audioFile.hasTranscriptionRecord {
        audioFile.hasTranscriptionRecord = false
      }
    }

    // Auto-save happens at end of batch usually, but we can save here if precise state needed immediately
    // modelContext.save() will be called by caller or auto-save
  }

  // MARK: - File Matching

  /// 查找匹配的文件
  private func findMatchingFile(baseName: String, in files: [URL]) -> URL? {
    return files.first { url in
      url.deletingPathExtension().lastPathComponent.lowercased() == baseName.lowercased()
    }
  }

  // MARK: - Pairing

  /// 关联字幕文件
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

    // 解析并缓存字幕内容
    if url.startAccessingSecurityScopedResource() {
      defer { url.stopAccessingSecurityScopedResource() }
      subtitleFile.cues = (try? SubtitleParser.parse(from: url)) ?? []
    }

    modelContext.insert(subtitleFile)
    audioFile.subtitleFile = subtitleFile
  }

  /// 关联 PDF 文件
  private func pairPDF(at url: URL, with audioFile: AudioFile) throws {
    let bookmarkData = try url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )

    audioFile.pdfBookmarkData = bookmarkData
  }

  // MARK: - Helpers

  private func getFileCreationDate(from url: URL) -> Date {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return attributes?[.creationDate] as? Date ?? Date()
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
