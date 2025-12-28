import Foundation
import SwiftData

@Model
final class AudioFile {
  var id: UUID
  var displayName: String

  @Attribute(.externalStorage)
  var bookmarkData: Data

  var createdAt: Date

  @Relationship(inverse: \LoopSegment.audioFile)
  var segments: [LoopSegment]

  /// 上次播放进度（秒）
  var lastPlaybackTime: Double

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

  /// 是否有转录的SRT文件
  var hasTranscription: Bool = false

  init(
    id: UUID = UUID(),
    displayName: String,
    bookmarkData: Data,
    createdAt: Date = Date(),
    segments: [LoopSegment] = [],
    lastPlaybackTime: Double = 0,
    folder: Folder? = nil,
    subtitleFile: SubtitleFile? = nil,
    pdfBookmarkData: Data? = nil,
    cachedDuration: Double? = nil,
    hasTranscription: Bool = false
  ) {
    self.id = id
    self.displayName = displayName
    self.bookmarkData = bookmarkData
    self.createdAt = createdAt
    self.segments = segments
    self.lastPlaybackTime = lastPlaybackTime
    self.folder = folder
    self.subtitleFile = subtitleFile
    self.pdfBookmarkData = pdfBookmarkData
    self.cachedDuration = cachedDuration
    self.hasTranscription = hasTranscription
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
  var audioFile: AudioFile?

  init(
    id: UUID = UUID(),
    label: String,
    startTime: Double,
    endTime: Double,
    index: Int,
    createdAt: Date = Date(),
    audioFile: AudioFile? = nil
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

extension AudioFile {
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

  /// 是否播放完成（进度100%）
  /// 使用1秒容差来处理播放器停止位置与总时长的微小差异
  var isPlaybackComplete: Bool {
    guard let duration = cachedDuration, duration > 0 else { return false }
    return lastPlaybackTime >= duration - 2.0
  }
}
