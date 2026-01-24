import OSLog
import SwiftData
import SwiftUI

@MainActor
@Observable
final class FolderNavigationViewModel {
  private let modelContext: ModelContext
  private let playerManager: PlayerManager
  
  private let navigationService: NavigationService
  private let selectionService: SelectionStateService
  private let deletionService: DeletionService
  private let importService: ImportService

  var sortOrder: SortOrder = .nameAZ
  var hovering: SelectionItem?
  var pressing: SelectionItem?
  
  var importType: MainSplitView.ImportType?
  var presetnImportType: MainSplitView.ImportType?
  
  var currentFolder: Folder? {
    get { navigationService.currentFolder }
    set { navigationService.currentFolder = newValue }
  }
  
  var navigationPath: [Folder] {
    get { navigationService.navigationPath }
    set { navigationService.navigationPath = newValue }
  }
  
  var selectedFile: ABFile? {
    get { selectionService.selectedFile }
    set { selectionService.selectedFile = newValue }
  }
  
  var selection: SelectionItem? {
    get { selectionService.selection }
    set { selectionService.selection = newValue }
  }
  
  var lastSelectedAudioFileID: String? {
    get { selectionService.lastSelectedAudioFileID }
    set { selectionService.lastSelectedAudioFileID = newValue }
  }
  
  var lastFolderID: String? {
    get { selectionService.lastFolderID }
    set { selectionService.lastFolderID = newValue }
  }
  
  var lastSelectionItemID: String? {
    get { selectionService.lastSelectionItemID }
    set { selectionService.lastSelectionItemID = newValue }
  }
  
  var importErrorMessage: String? {
    get { importService.importErrorMessage }
    set { importService.importErrorMessage = newValue }
  }

  init(
    modelContext: ModelContext,
    playerManager: PlayerManager,
    librarySettings: LibrarySettings,
    selectedFile: ABFile? = nil
  ) {
    self.modelContext = modelContext
    self.playerManager = playerManager
    
    self.navigationService = NavigationService()
    self.selectionService = SelectionStateService()
    self.deletionService = DeletionService(
      modelContext: modelContext,
      playerManager: playerManager,
      librarySettings: librarySettings
    )
    self.importService = ImportService(
      modelContext: modelContext,
      librarySettings: librarySettings
    )
    
    self.selectionService.selectedFile = selectedFile
  }
  
  func sortedFolders(_ folders: [Folder]) -> [Folder] {
    SortingUtility.sortFolders(folders, by: sortOrder)
  }
  
  func sortedAudioFiles(_ files: [ABFile]) -> [ABFile] {
    SortingUtility.sortAudioFiles(files, by: sortOrder)
  }
  
  func navigateInto(_ folder: Folder) {
    navigationService.navigateInto(folder)
  }
  
  func navigateBack() {
    navigationService.navigateBack()
  }
  
  func canNavigateBack() -> Bool {
    navigationService.canNavigateBack()
  }
  
  func handleSelectionChange(
    _ newSelection: SelectionItem?,
    onSelectFile: @escaping (ABFile) async -> Void
  ) {
    guard let newSelection else { return }

    selection = newSelection

    switch newSelection {
    case .folder(let folder):
      navigateInto(folder)

    case .audioFile(let file):
      Task {
        await onSelectFile(file)
      }

    case .empty:
      break
    }
  }
  
  func deleteFolder(
    _ folder: Folder,
    deleteFromDisk: Bool = true
  ) {
    var selectedFileRef = selectedFile
    deletionService.deleteFolder(
      folder,
      deleteFromDisk: deleteFromDisk,
      selectedFile: &selectedFileRef
    )
    selectedFile = selectedFileRef

    if deletionService.isSelectedFileInFolder(folder, selectedFile: selectedFile) {
      selectionService.clearSelection()
    }

    if currentFolder?.id == folder.id {
      navigateBack()
    }

    if lastFolderID == folder.id.uuidString {
      lastFolderID = nil
    }
  }
  
  func deleteAudioFile(
    _ file: ABFile,
    deleteFromDisk: Bool = true,
    updateSelection: Bool = true,
    checkPlayback: Bool = true,
    selectedFile: inout ABFile?
  ) {
    deletionService.deleteAudioFile(
      file,
      deleteFromDisk: deleteFromDisk,
      updateSelection: updateSelection,
      checkPlayback: checkPlayback,
      selectedFile: &selectedFile
    )
    
    if updateSelection && selectedFile == nil {
      selectionService.clearSelection()
    }
  }
  
  func handleImportResult(_ result: Result<[URL], Error>) {
    importService.handleImportResult(
      result,
      importType: importType,
      currentFolder: currentFolder
    )
  }
  
  func addAudioFile(from url: URL) {
    importService.addAudioFile(from: url, currentFolder: currentFolder)
  }
  
  func importFolder(from url: URL) {
    importService.importFolder(from: url, currentFolder: currentFolder)
  }
}
