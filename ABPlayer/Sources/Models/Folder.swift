import CryptoKit
import Foundation
import SwiftData

@Model
final class Folder {
  var id: UUID
  var name: String
  var createdAt: Date

  /// 相对于根导入目录的路径，用于生成确定性 ID
  var relativePath: String

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
    relativePath: String = "",
    createdAt: Date = Date(),
    parent: Folder? = nil,
    subfolders: [Folder] = [],
    audioFiles: [AudioFile] = []
  ) {
    self.id = id
    self.name = name
    self.relativePath = relativePath
    self.createdAt = createdAt
    self.parent = parent
    self.subfolders = subfolders
    self.audioFiles = audioFiles
  }
}

extension Folder {
  /// 基于相对路径生成确定性 UUID
  static func generateDeterministicID(from relativePath: String) -> UUID {
    let data = Data(relativePath.utf8)
    let hash = SHA256.hash(data: data)
    let hashData = Data(hash)

    let uuidBytes = Array(hashData.prefix(16))
    return UUID(
      uuid: (
        uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
        uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
        uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
        uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
      ))
  }
}
