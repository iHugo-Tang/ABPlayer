import Foundation
import SwiftData
import SwiftUI

@MainActor
final class ImportService {
  private let modelContext: ModelContext
  private let librarySettings: LibrarySettings
  
  var importErrorMessage: String?
  
  init(
    modelContext: ModelContext,
    librarySettings: LibrarySettings
  ) {
    self.modelContext = modelContext
    self.librarySettings = librarySettings
  }
  
  func handleImportResult(
    _ result: Result<[URL], Error>,
    importType: MainSplitView.ImportType?,
    currentFolder: Folder?
  ) {
    switch importType {
    case .file:
      handleFileImportResult(result, currentFolder: currentFolder)
    case .folder:
      handleFolderImportResult(result, currentFolder: currentFolder)
    case .none:
      break
    }
  }
  
  func addAudioFile(from url: URL, currentFolder: Folder?) {
    do {
      try librarySettings.ensureLibraryDirectoryExists()
      
      let fileURL: URL
      if isInLibrary(url) {
        fileURL = url
      } else {
        let destinationDirectory = currentFolderLibraryURL(currentFolder) ?? librarySettings.libraryDirectoryURL
        fileURL = try copyItemToLibrary(from: url, destinationDirectory: destinationDirectory)
      }
      
      let bookmarkData = try fileURL.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      
      let displayName = fileURL.lastPathComponent
      let deterministicID = ABFile.generateDeterministicID(from: bookmarkData)
      
      let audioFile = ABFile(
        id: deterministicID,
        displayName: displayName,
        bookmarkData: bookmarkData,
        folder: currentFolder
      )
      
      modelContext.insert(audioFile)
      currentFolder?.audioFiles.append(audioFile)
    } catch {
      importErrorMessage = "Failed to import file: \(error.localizedDescription)"
    }
  }
  
  func importFolder(from url: URL, currentFolder: Folder?) {
    Task { @MainActor in
      let importer = FolderImporter(modelContext: modelContext, librarySettings: librarySettings)
      
      do {
        _ = try await importer.syncFolder(at: url, parentFolder: currentFolder)
      } catch {
        await MainActor.run {
          importErrorMessage = "Failed to import folder: \(error.localizedDescription)"
        }
      }
    }
  }
  
  private func handleFileImportResult(_ result: Result<[URL], Error>, currentFolder: Folder?) {
    switch result {
    case .failure(let error):
      importErrorMessage = error.localizedDescription
    case .success(let urls):
      guard let url = urls.first else { return }
      addAudioFile(from: url, currentFolder: currentFolder)
    }
  }
  
  private func handleFolderImportResult(_ result: Result<[URL], Error>, currentFolder: Folder?) {
    switch result {
    case .failure(let error):
      importErrorMessage = error.localizedDescription
    case .success(let urls):
      guard let url = urls.first else { return }
      importFolder(from: url, currentFolder: currentFolder)
    }
  }
  
  private func copyItemToLibrary(from url: URL, destinationDirectory: URL) throws -> URL {
    let fileManager = FileManager.default
    
    var destinationURL = destinationDirectory.appendingPathComponent(url.lastPathComponent)
    if fileManager.fileExists(atPath: destinationURL.path) {
      destinationURL = uniqueURL(for: destinationURL)
    }
    
    try fileManager.copyItem(at: url, to: destinationURL)
    return destinationURL
  }
  
  private func isInLibrary(_ url: URL) -> Bool {
    let libraryURL = librarySettings.libraryDirectoryURL.standardizedFileURL
    let candidateURL = url.standardizedFileURL
    return candidateURL.path.hasPrefix(libraryURL.path)
  }
  
  private func currentFolderLibraryURL(_ currentFolder: Folder?) -> URL? {
    guard let currentFolder else { return nil }
    let relativePath = currentFolder.relativePath
    guard !relativePath.isEmpty else { return nil }
    return librarySettings.libraryDirectoryURL.appendingPathComponent(relativePath)
  }
  
  private func uniqueURL(for url: URL) -> URL {
    let fileManager = FileManager.default
    let directory = url.deletingLastPathComponent()
    let baseName = url.deletingPathExtension().lastPathComponent
    let fileExtension = url.pathExtension
    
    var counter = 1
    var candidate = url
    
    while fileManager.fileExists(atPath: candidate.path) {
      let newName = "\(baseName) \(counter)"
      if fileExtension.isEmpty {
        candidate = directory.appendingPathComponent(newName)
      } else {
        candidate = directory.appendingPathComponent(newName).appendingPathExtension(fileExtension)
      }
      counter += 1
    }
    
    return candidate
  }
}
