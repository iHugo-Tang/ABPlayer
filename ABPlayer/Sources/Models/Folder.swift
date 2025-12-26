import Foundation
import SwiftData

@Model
final class Folder {
  var id: UUID
  var name: String
  var createdAt: Date

  @Relationship(inverse: \Folder.parent)
  var subfolders: [Folder]

  var parent: Folder?

  @Relationship(inverse: \AudioFile.folder)
  var audioFiles: [AudioFile]

  /// 按文件名排序的音频文件（用于播放顺序）
  var sortedAudioFiles: [AudioFile] {
    audioFiles.sorted { $0.displayName < $1.displayName }
  }

  init(
    id: UUID = UUID(),
    name: String,
    createdAt: Date = Date(),
    parent: Folder? = nil,
    subfolders: [Folder] = [],
    audioFiles: [AudioFile] = []
  ) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.parent = parent
    self.subfolders = subfolders
    self.audioFiles = audioFiles
  }
}
