import Foundation
import SwiftData

@Model
final class PlaybackRecord {
  var id: UUID

  /// 上次播放时间戳
  var lastPlayedAt: Date?

  /// 播放完成次数
  var completionCount: Int

  /// 当前播放位置（秒）
  var currentPosition: Double

  /// 关联的音频文件
  var audioFile: ABFile?

  init(
    id: UUID = UUID(),
    lastPlayedAt: Date? = nil,
    completionCount: Int = 0,
    currentPosition: Double = 0,
    audioFile: ABFile? = nil
  ) {
    self.id = id
    self.lastPlayedAt = lastPlayedAt
    self.completionCount = completionCount
    self.currentPosition = currentPosition
    self.audioFile = audioFile
  }
}
