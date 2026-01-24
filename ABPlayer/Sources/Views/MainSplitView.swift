import Combine
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import Observation

#if os(macOS)
  import AppKit
#endif

import Observation

extension MainSplitView {
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

  private func currentFolderLibraryURL() -> URL? {
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

@MainActor
public struct MainSplitView: View {
  @Environment(PlayerManager.self) private var playerManager: PlayerManager
  @Environment(SessionTracker.self) private var sessionTracker: SessionTracker
  @Environment(LibrarySettings.self) private var librarySettings
  @Environment(\.modelContext) private var modelContext
  @Environment(\.openURL) private var openURL

  @State private var folderNavigationViewModel: FolderNavigationViewModel?

  @Query(sort: \ABFile.createdAt, order: .forward)
  private var allAudioFiles: [ABFile]

  @Query(sort: \Folder.name)
  private var allFolders: [Folder]

  @State private var currentFolder: Folder?
  @State private var navigationPath: [Folder] = []
  @State private var isImportingFile: Bool = false
  @State private var isImportingFolder: Bool = false
  @State private var importErrorMessage: String?
  @State private var isClearingData: Bool = false

  public init() {}

  public var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: 220, ideal: 300, max: 400)
        .background(Color.asset.bgPrimary)
        .fileImporter(
          isPresented: $isImportingFile,
          allowedContentTypes: [UTType.audio, UTType.movie],
          allowsMultipleSelection: false,
          onCompletion: handleFileImportResult
        )
    } detail: {
      if let selectedFile = folderNavigationViewModel?.selectedFile {
        if selectedFile.isVideo {
          VideoPlayerView(audioFile: selectedFile)
        } else {
          AudioPlayerView(audioFile: selectedFile)
        }
      } else {
        EmptyStateView()
      }
    }
    .frame(minWidth: 1000, minHeight: 600)
    .fileImporter(
      isPresented: $isImportingFolder,
      allowedContentTypes: [UTType.folder],
      allowsMultipleSelection: false,
      onCompletion: handleFolderImportResult
    )
    .onAppear {
      sessionTracker.setModelContainer(modelContext.container)
      playerManager.sessionTracker = sessionTracker
      if folderNavigationViewModel == nil {
        folderNavigationViewModel = FolderNavigationViewModel(
          modelContext: modelContext,
          playerManager: playerManager,
          librarySettings: librarySettings
        )
      }
      restoreLastSelectionIfNeeded()
      setupPlaybackEndedHandler()
    }
    .task(id: allAudioFiles.map(\.id)) {
      restoreLastSelectionIfNeeded()
    }
    .onChange(of: currentFolder?.id, initial: true) { _, _ in
      if let folder = currentFolder {
        playerManager.playbackQueue.updateQueue(folder.sortedAudioFiles)
      } else {
        playerManager.playbackQueue.updateQueue([])
      }
    }
    #if os(macOS)
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification))
      { _ in
        sessionTracker.persistProgress()
        sessionTracker.endSessionIfIdle()
      }
    #endif
    .alert(
      "Import Failed",
      isPresented: .constant(importErrorMessage != nil),
      presenting: importErrorMessage
    ) { _ in
      Button("OK", role: .cancel) {
        importErrorMessage = nil
      }
    } message: { message in
      Text(message)
    }
  }

  // MARK: - Sidebar

  private var sidebar: some View {
    return Group {
      if isClearingData {
        ProgressView("Clearing...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let folderNavigationViewModel {
        FolderNavigationView(
          viewModel: folderNavigationViewModel,
          currentFolder: $currentFolder,
          navigationPath: $navigationPath,
          onSelectFile: { file in await selectFile(file) }
        )
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Menu {
          Button {
            isImportingFile = true
          } label: {
            Label("Import Media File", systemImage: "tray.and.arrow.down")
          }

          Button {
            isImportingFolder = true
          } label: {
            Label("Import Folder", systemImage: "folder.badge.plus")
          }

          Divider()

          Button(role: .destructive) {
            Task {
              await clearAllDataAsync()
            }
          } label: {
            Label("Clear All Data", systemImage: "trash")
          }
        } label: {
          Label("Add", systemImage: "plus")
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 0) {
        Divider()
        versionFooter
      }
      .background(Color.asset.bgPrimary)
    }
  }

  private var versionFooter: some View {
    HStack {
      Text("v\(bundleShortVersion)(\(bundleVersion))")

      Spacer()

      Button("Feedback", systemImage: "bubble.left.and.exclamationmark.bubble.right") {
        if let url = URL(string: "https://github.com/sunset-valley/ABPlayer/issues/new") {
          openURL(url)
        }
      }
      .buttonStyle(.plain)
    }
    .captionStyle()
    .padding(.horizontal, 16)
    .padding(.vertical)
  }

  private var bundleShortVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
  }

  private var bundleVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
  }

  // MARK: - Import Handlers

  private func handleFileImportResult(_ result: Result<[URL], Error>) {
    switch result {
    case .failure(let error):
      importErrorMessage = error.localizedDescription
    case .success(let urls):
      guard let url = urls.first else { return }
      addAudioFile(from: url)
    }
  }

  private func handleFolderImportResult(_ result: Result<[URL], Error>) {
    switch result {
    case .failure(let error):
      importErrorMessage = error.localizedDescription
    case .success(let urls):
      guard let url = urls.first else { return }
      importFolder(from: url)
    }
  }

  private func addAudioFile(from url: URL) {
    do {
      try librarySettings.ensureLibraryDirectoryExists()

      let fileURL: URL
      if isInLibrary(url) {
        fileURL = url
      } else {
        let destinationDirectory = currentFolderLibraryURL() ?? librarySettings.libraryDirectoryURL
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

  private func importFolder(from url: URL) {
    Task { @MainActor in
      let importer = FolderImporter(modelContext: modelContext, librarySettings: librarySettings)

      do {
        let parentFolder = currentFolder
        _ = try await importer.syncFolder(at: url, parentFolder: parentFolder)
      } catch {
        await MainActor.run {
          importErrorMessage = "Failed to import folder: \(error.localizedDescription)"
        }
      }
    }
  }

  // MARK: - Selection

  private func selectFile(_ file: ABFile, fromStart: Bool = false, debounce: Bool = true) async {
    await playerManager.selectFile(file, fromStart: fromStart, debounce: debounce)
  }

  private func playFile(_ file: ABFile, fromStart: Bool = false) async {
    await playerManager.playFile(file, fromStart: fromStart)
  }

  private func restoreLastSelectionIfNeeded() {
    guard let folderNavigationViewModel else { return }
    guard !navigationPath.isEmpty else { return }

    if currentFolder == nil, navigationPath.isEmpty,
      let lastFolderID = folderNavigationViewModel.lastFolderID,
      let folderUUID = UUID(uuidString: lastFolderID),
      let folder = allFolders.first(where: { $0.id == folderUUID })
    {
      var path: [Folder] = []
      var current: Folder? = folder
      while let f = current {
        path.insert(f, at: 0)
        current = f.parent
      }
      navigationPath = path
      currentFolder = folder
    }

    guard folderNavigationViewModel.selectedFile == nil else {
      if let currentFile = playerManager.currentFile,
        let matchedFile = allAudioFiles.first(where: { $0.id == currentFile.id })
      {
        folderNavigationViewModel.selectedFile = matchedFile
        playerManager.currentFile = matchedFile
      }
      return
    }

    if let currentFile = playerManager.currentFile,
      let matchedFile = allAudioFiles.first(where: { $0.id == currentFile.id })
    {
      folderNavigationViewModel.selectedFile = matchedFile
      playerManager.currentFile = matchedFile
      return
    }

    if let lastSelectedAudioFileID = folderNavigationViewModel.lastSelectedAudioFileID,
       let lastID = UUID(uuidString: lastSelectedAudioFileID),
       let file = allAudioFiles.first(where: { $0.id == lastID })
    {
      Task { await selectFile(file) }
      return
    }

    if let folder = currentFolder,
       let firstFile = folder.audioFiles.first {
      _ = firstFile
    }
  }

  // MARK: - Playback Loop Handling

  private func setupPlaybackEndedHandler() {
    playerManager.onPlaybackEnded = { @MainActor [playerManager] currentFile in
      guard let currentFile else { return }

      playerManager.playbackQueue.loopMode = playerManager.loopMode
      playerManager.playbackQueue.setCurrentFile(currentFile)

      guard let nextFile = playerManager.playbackQueue.playNext() else { return }

      Task { @MainActor in
        await playerManager.playFile(nextFile, fromStart: true)
      }
    }
  }

  // MARK: - Data Management

  private func clearAllData() {
    // Clear all data from SwiftData
    // IMPORTANT: Clear UI state and player references FIRST to prevent
    // accessing detached/faulted entities during deletion
    do {
      // Step 1: Stop playback if currently playing
      if playerManager.isPlaying {
        playerManager.togglePlayPause()
      }

      // Step 2: Clear UI state and player references immediately
      folderNavigationViewModel?.selectedFile = nil
      currentFolder = nil
      navigationPath = []
      playerManager.currentFile = nil

      // Step 3: Delete entities in correct order to handle relationship constraints
      // For entities with @Attribute(.externalStorage), delete parent entities FIRST
      // to prevent SwiftData from trying to resolve attribute faults during cascade deletion

      // Fetch and delete all AudioFiles FIRST (before child entities)
      // This prevents attempting to resolve faults on pdfBookmarkData during deletion
      let audioFiles = try modelContext.fetch(FetchDescriptor<ABFile>())
      for audioFile in audioFiles {
        modelContext.delete(audioFile)
      }

      // Fetch and delete all Folders
      let folders = try modelContext.fetch(FetchDescriptor<Folder>())
      for folder in folders {
        modelContext.delete(folder)
      }

      // End the current session tracker session before deleting sessions
      sessionTracker.endSessionIfIdle()

      // Fetch and delete all ListeningSessions
      let sessions = try modelContext.fetch(FetchDescriptor<ListeningSession>())
      for session in sessions {
        modelContext.delete(session)
      }

      // Step 4: Save all deletions
      try modelContext.save()
    } catch {
      importErrorMessage = "Failed to clear data: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func clearAllDataAsync() async {
    isClearingData = true
    // Give SwiftUI a moment to unmount views that observe this data
    try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2s
    clearAllData()
    isClearingData = false
  }
}
