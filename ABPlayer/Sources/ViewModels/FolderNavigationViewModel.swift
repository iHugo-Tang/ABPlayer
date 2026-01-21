import OSLog
import SwiftData
import SwiftUI

@MainActor
@Observable
final class FolderNavigationViewModel {
  private let modelContext: ModelContext
  private let playerManager: PlayerManager
  
  // MARK: - State Properties
  
  var sortOrder: SortOrder = .nameAZ
  var isRescanningFolder = false
  var selection: SelectionItem?
  var hovering: SelectionItem?
  var pressing: SelectionItem?
  
  // MARK: - Initialization
  
  init(modelContext: ModelContext, playerManager: PlayerManager) {
    self.modelContext = modelContext
    self.playerManager = playerManager
  }
  
  // MARK: - Computed Properties for Sorting
  
  /// Extracts the leading number from a filename for number-based sorting
  /// Returns Int.max if the filename doesn't start with a number
  private func extractLeadingNumber(_ name: String) -> Int {
    let digits = name.prefix(while: { $0.isNumber })
    return Int(digits) ?? Int.max
  }
  
  func sortedFolders(_ folders: [Folder]) -> [Folder] {
    switch sortOrder {
    case .nameAZ:
      return folders.sorted { $0.name < $1.name }
    case .nameZA:
      return folders.sorted { $0.name > $1.name }
    case .numberAsc:
      return folders.sorted { extractLeadingNumber($0.name) < extractLeadingNumber($1.name) }
    case .numberDesc:
      return folders.sorted { extractLeadingNumber($0.name) > extractLeadingNumber($1.name) }
    case .dateCreatedNewestFirst:
      return folders.sorted { $0.createdAt > $1.createdAt }
    case .dateCreatedOldestFirst:
      return folders.sorted { $0.createdAt < $1.createdAt }
    }
  }
  
  func sortedAudioFiles(_ files: [ABFile]) -> [ABFile] {
    switch sortOrder {
    case .nameAZ:
      return files.sorted { $0.displayName < $1.displayName }
    case .nameZA:
      return files.sorted { $0.displayName > $1.displayName }
    case .numberAsc:
      return files.sorted {
        extractLeadingNumber($0.displayName) < extractLeadingNumber($1.displayName)
      }
    case .numberDesc:
      return files.sorted {
        extractLeadingNumber($0.displayName) > extractLeadingNumber($1.displayName)
      }
    case .dateCreatedNewestFirst:
      return files.sorted { $0.createdAt > $1.createdAt }
    case .dateCreatedOldestFirst:
      return files.sorted { $0.createdAt < $1.createdAt }
    }
  }
  
  // MARK: - Navigation Actions
  
  func navigateInto(
    _ folder: Folder,
    navigationPath: inout [Folder],
    currentFolder: inout Folder?
  ) {
    navigationPath.append(folder)
    currentFolder = folder
  }
  
  func navigateBack(
    navigationPath: inout [Folder],
    currentFolder: inout Folder?
  ) {
    guard !navigationPath.isEmpty else { return }
    navigationPath.removeLast()
    currentFolder = navigationPath.last
  }
  
  func canNavigateBack(navigationPath: [Folder]) -> Bool {
    !navigationPath.isEmpty
  }
  
  // MARK: - Selection Handling
  
  func handleSelectionChange(
    _ newSelection: SelectionItem?,
    navigationPath: inout [Folder],
    currentFolder: inout Folder?,
    onSelectFile: @escaping (ABFile) async -> Void
  ) {
    guard let newSelection else { return }
    
    switch newSelection {
    case .folder(let folder):
      navigateInto(folder, navigationPath: &navigationPath, currentFolder: &currentFolder)
      
    case .audioFile(let file):
      Task {
        await onSelectFile(file)
      }

    case .empty:
      break
    }
  }
  
  // MARK: - Rescan Action
  
  func rescanCurrentFolder(_ folder: Folder?) {
    guard let folder else { return }
    
    let rootFolder = folder.rootFolder
    
    guard let url = try? rootFolder.resolveURL() else {
      Logger.data.warning("⚠️ No root folder bookmark found")
      return
    }
    
    isRescanningFolder = true
    
    Task {
      defer {
        Task { @MainActor in
          isRescanningFolder = false
        }
      }
      
      do {
        let importer = FolderImporter(modelContainer: modelContext.container)
        _ = try await importer.syncFolder(at: url)
        Logger.data.info("✅ Successfully rescanned folder: \(rootFolder.name)")
      } catch {
        Logger.data.error("❌ Failed to rescan folder: \(error.localizedDescription)")
      }
    }
  }
  
  // MARK: - Deletion Actions
  
  func deleteFolder(
    _ folder: Folder,
    currentFolder: inout Folder?,
    selectedFile: inout ABFile?,
    navigationPath: inout [Folder]
  ) {
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
    
    if isSelectedFileInFolder(folder, selectedFile: selectedFile) {
      selectedFile = nil
    }
    
    if currentFolder?.id == folder.id {
      navigateBack(navigationPath: &navigationPath, currentFolder: &currentFolder)
    }
    
    for subfolder in folder.subfolders {
      deleteFolder(
        subfolder,
        currentFolder: &currentFolder,
        selectedFile: &selectedFile,
        navigationPath: &navigationPath
      )
    }
    
    for audioFile in folder.audioFiles {
      deleteAudioFile(audioFile, updateSelection: false, checkPlayback: false, selectedFile: &selectedFile)
    }
    
    modelContext.delete(folder)
  }
  
  func deleteAudioFile(
    _ file: ABFile,
    updateSelection: Bool = true,
    checkPlayback: Bool = true,
    selectedFile: inout ABFile?
  ) {
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
  
  // MARK: - Helper Methods
  
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
  
  private func isSelectedFileInFolder(_ folder: Folder, selectedFile: ABFile?) -> Bool {
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
}
