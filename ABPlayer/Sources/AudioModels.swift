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

  init(
    id: UUID = UUID(),
    displayName: String,
    bookmarkData: Data,
    createdAt: Date = Date(),
    segments: [LoopSegment] = [],
    lastPlaybackTime: Double = 0,
    folder: Folder? = nil,
    subtitleFile: SubtitleFile? = nil,
    pdfBookmarkData: Data? = nil
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
