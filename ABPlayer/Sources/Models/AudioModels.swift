import CryptoKit
import Foundation
import SwiftData

enum FileType: String, Codable {
  case audio
  case video
  
  var iconName: String {
    switch self {
    case .audio:
      return "music.note"
    case .video:
      return "movieclapper"
    }
  }
}

@Model
final class ABFile {
  var id: UUID
  var displayName: String
  var fileType: FileType

  @Attribute(.externalStorage)
  var bookmarkData: Data

  var createdAt: Date

  @Relationship(inverse: \LoopSegment.audioFile)
  var segments: [LoopSegment]

  /// 播放记录（级联删除）
  @Relationship(deleteRule: .cascade, inverse: \PlaybackRecord.audioFile)
  var playbackRecord: PlaybackRecord?

  /// 便捷访问：当前播放位置
  var currentPlaybackPosition: Double {
    get { playbackRecord?.currentPosition ?? 0 }
    set {
      if playbackRecord == nil {
        playbackRecord = PlaybackRecord()
      }
      playbackRecord?.currentPosition = newValue
    }
  }

  /// 所属文件夹
  var folder: Folder?

  /// 关联的字幕文件
  @Relationship(inverse: \SubtitleFile.audioFile)
  var subtitleFile: SubtitleFile?

  /// 关联的 PDF 文件 bookmark
  @Attribute(.externalStorage)
  var pdfBookmarkData: Data?

  /// 缓存的音频时长（秒），避免每次加载时读取
  var cachedDuration: Double?

  /// 是否有转录记录 (DB Record)
  var hasTranscriptionRecord: Bool = false

  /// 加载错误信息
  var loadError: String?

  init(
    id: UUID = UUID(),
    displayName: String,
    fileType: FileType? = nil,
    bookmarkData: Data,
    createdAt: Date = Date(),
    segments: [LoopSegment] = [],
    folder: Folder? = nil,
    subtitleFile: SubtitleFile? = nil,
    pdfBookmarkData: Data? = nil,
    cachedDuration: Double? = nil,
    hasTranscriptionRecord: Bool = false,
    loadError: String? = nil
  ) {
    self.id = id
    self.displayName = displayName
    self.fileType = fileType ?? Self.inferFileType(from: displayName)
    self.bookmarkData = bookmarkData
    self.createdAt = createdAt
    self.segments = segments
    self.folder = folder
    self.subtitleFile = subtitleFile
    self.pdfBookmarkData = pdfBookmarkData
    self.cachedDuration = cachedDuration
    self.hasTranscriptionRecord = hasTranscriptionRecord
    self.loadError = loadError
  }
}

@Model
final class LoopSegment {
  var id: UUID
  var label: String
  var startTime: Double
  var endTime: Double
  var index: Int
  var createdAt: Date
  var audioFile: ABFile?

  init(
    id: UUID = UUID(),
    label: String,
    startTime: Double,
    endTime: Double,
    index: Int,
    createdAt: Date = Date(),
    audioFile: ABFile? = nil
  ) {
    self.id = id
    self.label = label
    self.startTime = startTime
    self.endTime = endTime
    self.index = index
    self.createdAt = createdAt
    self.audioFile = audioFile
  }
}

extension ABFile {
  /// Generate a deterministic UUID from bookmark data
  /// Uses SHA256 hash to ensure the same data always produces the same UUID
  /// This enables transcription data reuse when the same file is re-imported
  static func generateDeterministicID(from bookmarkData: Data) -> UUID {
    // Use SHA256 hash of bookmark data to create deterministic UUID
    let hash = SHA256.hash(data: bookmarkData)
    let hashData = Data(hash)

    // Take first 16 bytes for UUID
    let uuidBytes = Array(hashData.prefix(16))
    return UUID(
      uuid: (
        uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
        uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
        uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
        uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
      ))
  }

  /// 获取对应的SRT字幕文件URL（与音频文件同目录）
  var srtFileURL: URL? {
    guard let audioURL = try? resolveURL() else { return nil }
    return audioURL.deletingPathExtension().appendingPathExtension("srt")
  }

  private func resolveURL() throws -> URL {
    var isStale = false
    return try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
  }

  /// 是否曾经播放完成过（completionCount >= 1）
  var isPlaybackComplete: Bool {
    playbackRecord?.completionCount ?? 0 >= 1
  }

  /// 检查 Bookmark 是否有效（文件是否存在）
  var isBookmarkValid: Bool {
    guard let url = try? resolveURL() else { return false }
    return FileManager.default.fileExists(atPath: url.path)
  }

  static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

  static func inferFileType(from displayName: String) -> FileType {
    let ext = (displayName as NSString).pathExtension.lowercased()
    return videoExtensions.contains(ext) ? .video : .audio
  }

  var isVideo: Bool {
    fileType == .video
  }
}
