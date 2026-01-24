import OSLog
import SwiftData
import SwiftUI

@MainActor
@Observable
final class FolderNavigationViewModel {
  private let modelContext: ModelContext
  private let playerManager: PlayerManager
  private let librarySettings: LibrarySettings

  var selectedFile: ABFile?

  var lastSelectedAudioFileID: String? {
    get { UserDefaults.standard.string(forKey: "lastSelectedAudioFileID") }
    set { UserDefaults.standard.set(newValue, forKey: "lastSelectedAudioFileID") }
  }

  var lastFolderID: String? {
    get { UserDefaults.standard.string(forKey: "lastFolderID") }
    set { UserDefaults.standard.set(newValue, forKey: "lastFolderID") }
  }

  var lastSelectionItemID: String? {
    get { UserDefaults.standard.string(forKey: "lastSelectionItemID") }
    set { UserDefaults.standard.set(newValue, forKey: "lastSelectionItemID") }
  }

  var selection: SelectionItem? {
    didSet {
      guard let selection else {
        lastSelectionItemID = nil
        return
      }

      switch selection {
      case .folder(let folder):
        lastSelectionItemID = folder.id.uuidString
      case .audioFile(let file):
        selectedFile = file
        lastSelectedAudioFileID = file.id.uuidString
        lastFolderID = file.folder?.id.uuidString
        lastSelectionItemID = file.id.uuidString
      case .empty:
        lastSelectionItemID = nil
      }
    }
  }

  var sortOrder: SortOrder = .nameAZ
  var hovering: SelectionItem?
  var pressing: SelectionItem?

  init(
    modelContext: ModelContext,
    playerManager: PlayerManager,
    librarySettings: LibrarySettings,
    selectedFile: ABFile? = nil
  ) {
    self.modelContext = modelContext
    self.playerManager = playerManager
    self.librarySettings = librarySettings
    self.selectedFile = selectedFile
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

    selection = newSelection

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
  
  // MARK: - Deletion Actions
  
  func deleteFolder(
    _ folder: Folder,
    deleteFromDisk: Bool = true,
    currentFolder: inout Folder?,
    selectedFile: inout ABFile?,
    navigationPath: inout [Folder]
  ) {
    deleteFolderContents(
      folder,
      deleteFromDisk: deleteFromDisk,
      currentFolder: &currentFolder,
      selectedFile: &selectedFile,
      navigationPath: &navigationPath
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

    if isSelectedFileInFolder(folder, selectedFile: selectedFile) {
      selectedFile = nil
      lastSelectedAudioFileID = nil
      lastFolderID = nil
      lastSelectionItemID = nil
      selection = nil
    }

    if currentFolder?.id == folder.id {
      navigateBack(navigationPath: &navigationPath, currentFolder: &currentFolder)
    }

    if lastFolderID == folder.id.uuidString {
      lastFolderID = nil
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
      lastSelectedAudioFileID = nil
      lastFolderID = nil
      lastSelectionItemID = nil
      selection = nil
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

  private func deleteFolderContents(
    _ folder: Folder,
    deleteFromDisk: Bool,
    currentFolder: inout Folder?,
    selectedFile: inout ABFile?,
    navigationPath: inout [Folder]
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
        currentFolder: &currentFolder,
        selectedFile: &selectedFile,
        navigationPath: &navigationPath
      )
      modelContext.delete(subfolder)
    }

    if deleteFromDisk,
       let url = (try? folder.resolveURL()) ?? folderLibraryURL(for: folder) {
      try? FileManager.default.removeItem(at: url)
    }
  }

  private func folderLibraryURL(for folder: Folder) -> URL? {
    let relativePath = folder.relativePath
    guard !relativePath.isEmpty else { return nil }
    return librarySettings.libraryDirectoryURL.appendingPathComponent(relativePath)
  }
}
