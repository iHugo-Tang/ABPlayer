import Foundation
import OSLog
import SwiftData

@MainActor
final class DeletionService {
  private let modelContext: ModelContext
  private let playerManager: PlayerManager
  private let librarySettings: LibrarySettings
  
  init(
    modelContext: ModelContext,
    playerManager: PlayerManager,
    librarySettings: LibrarySettings
  ) {
    self.modelContext = modelContext
    self.playerManager = playerManager
    self.librarySettings = librarySettings
  }
  
  func deleteFolder(
    _ folder: Folder,
    deleteFromDisk: Bool = true,
    selectedFile: inout ABFile?
  ) {
    deleteFolderContents(
      folder,
      deleteFromDisk: deleteFromDisk,
      selectedFile: &selectedFile
    )
    
    do {
      try modelContext.save()
    } catch {
      Logger.data.error(
        "⚠️ Failed to save context before folder deletion: \(error.localizedDescription)")
    }
    
    if isCurrentFileInFolder(folder) {
      if playerManager.isPlaying {
        playerManager.togglePlayPause()
      }
      playerManager.currentFile = nil
    }
    
    if deleteFromDisk,
       let url = (try? folder.resolveURL()) ?? folderLibraryURL(for: folder) {
      try? FileManager.default.removeItem(at: url)
    }
    
    modelContext.delete(folder)
  }
  
  func deleteAudioFile(
    _ file: ABFile,
    deleteFromDisk: Bool = true,
    updateSelection: Bool = true,
    checkPlayback: Bool = true,
    selectedFile: inout ABFile?
  ) {
    if deleteFromDisk {
      if let url = file.resolvedURL() {
        try? FileManager.default.removeItem(at: url)
      }
      
      if let pdfURL = file.resolvedPDFURL() {
        try? FileManager.default.removeItem(at: pdfURL)
      }
    }
    
    if checkPlayback {
      do {
        try modelContext.save()
      } catch {
        Logger.data.error(
          "⚠️ Failed to save context before file deletion: \(error.localizedDescription)")
      }
    }
    
    if checkPlayback && playerManager.isPlaying && playerManager.currentFile?.id == file.id {
      playerManager.togglePlayPause()
    }
    
    if updateSelection && selectedFile?.id == file.id {
      selectedFile = nil
      playerManager.currentFile = nil
    }
    
    var subtitleIsStale = false
    if deleteFromDisk,
       let subtitleFile = file.subtitleFile,
       let subtitleURL = (try? URL(
         resolvingBookmarkData: subtitleFile.bookmarkData,
         options: [.withSecurityScope],
         relativeTo: nil,
         bookmarkDataIsStale: &subtitleIsStale
       )) {
      try? FileManager.default.removeItem(at: subtitleURL)
    }
    
    for segment in file.segments {
      modelContext.delete(segment)
    }
    
    if let subtitleFile = file.subtitleFile {
      modelContext.delete(subtitleFile)
    }
    
    let fileIdString = file.id.uuidString
    let descriptor = FetchDescriptor<Transcription>(
      predicate: #Predicate<Transcription> { $0.audioFileId == fileIdString }
    )
    if let transcriptions = try? modelContext.fetch(descriptor) {
      for transcription in transcriptions {
        modelContext.delete(transcription)
      }
    }
    
    modelContext.delete(file)
  }
  
  func isSelectedFileInFolder(_ folder: Folder, selectedFile: ABFile?) -> Bool {
    guard let selectedFile else { return false }
    
    if folder.audioFiles.contains(where: { $0.id == selectedFile.id }) {
      return true
    }
    
    for subfolder in folder.subfolders {
      if isSelectedFileInFolder(subfolder, selectedFile: selectedFile) {
        return true
      }
    }
    
    return false
  }
  
  private func isCurrentFileInFolder(_ folder: Folder) -> Bool {
    guard let currentFile = playerManager.currentFile else {
      return false
    }
    
    if folder.audioFiles.contains(where: { $0.id == currentFile.id }) {
      return true
    }
    
    for subfolder in folder.subfolders {
      if isCurrentFileInFolder(subfolder) {
        return true
      }
    }
    
    return false
  }
  
  private func deleteFolderContents(
    _ folder: Folder,
    deleteFromDisk: Bool,
    selectedFile: inout ABFile?
  ) {
    for audioFile in folder.audioFiles {
      deleteAudioFile(
        audioFile,
        deleteFromDisk: deleteFromDisk,
        updateSelection: false,
        checkPlayback: false,
        selectedFile: &selectedFile
      )
    }
    
    for subfolder in folder.subfolders {
      deleteFolderContents(
        subfolder,
        deleteFromDisk: deleteFromDisk,
        selectedFile: &selectedFile
      )
      modelContext.delete(subfolder)
    }
  }
  
  private func folderLibraryURL(for folder: Folder) -> URL? {
    let relativePath = folder.relativePath
    guard !relativePath.isEmpty else { return nil }
    return librarySettings.libraryDirectoryURL.appendingPathComponent(relativePath)
  }
}
