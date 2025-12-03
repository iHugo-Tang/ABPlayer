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

    init(
        id: UUID = UUID(),
        displayName: String,
        bookmarkData: Data,
        createdAt: Date = Date(),
        segments: [LoopSegment] = [],
        lastPlaybackTime: Double = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.createdAt = createdAt
        self.segments = segments
        self.lastPlaybackTime = lastPlaybackTime
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


