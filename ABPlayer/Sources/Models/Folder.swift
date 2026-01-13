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

  /// 根文件夹的 security-scoped bookmark（仅根文件夹需要存储）
  @Attribute(.externalStorage)
  var bookmarkData: Data?

  @Relationship(inverse: \Folder.parent)
  var subfolders: [Folder]

  var parent: Folder?

  @Relationship(inverse: \ABFile.folder)
  var audioFiles: [ABFile]

  /// 按文件名排序的音频文件（用于播放顺序）
  var sortedAudioFiles: [ABFile] {
    audioFiles.sorted { $0.displayName < $1.displayName }
  }

  init(
    id: UUID = UUID(),
    name: String,
    relativePath: String = "",
    createdAt: Date = Date(),
    parent: Folder? = nil,
    subfolders: [Folder] = [],
    audioFiles: [ABFile] = [],
    bookmarkData: Data? = nil
  ) {
    self.id = id
    self.name = name
    self.relativePath = relativePath
    self.createdAt = createdAt
    self.parent = parent
    self.subfolders = subfolders
    self.audioFiles = audioFiles
    self.bookmarkData = bookmarkData
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

  /// 从 bookmark 恢复 URL（仅根文件夹有 bookmark）
  func resolveURL() throws -> URL? {
    guard let bookmarkData else { return nil }

    var isStale = false
    let url = try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )

    return url
  }

  /// 获取根文件夹
  var rootFolder: Folder {
    var root = self
    while let parent = root.parent {
      root = parent
    }
    return root
  }
}
