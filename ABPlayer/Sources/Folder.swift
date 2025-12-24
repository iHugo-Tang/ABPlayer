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
