import Combine
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
  import AppKit
#endif

public struct ContentView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(SessionTracker.self) private var sessionTracker
  @Environment(\.modelContext) private var modelContext

  @Query(sort: \AudioFile.createdAt, order: .forward)
  private var allAudioFiles: [AudioFile]

  @Query(sort: \Folder.name)
  private var allFolders: [Folder]

  @State private var selectedFile: AudioFile?
  @State private var currentFolder: Folder?
  @State private var navigationPath: [Folder] = []
  @State private var isImportingFile: Bool = false
  @State private var isImportingFolder: Bool = false
  @State private var importErrorMessage: String?
  @AppStorage("lastSelectedAudioFileID") private var lastSelectedAudioFileID: String?
  @AppStorage("lastFolderID") private var lastFolderID: String?

  public init() {}

  public var body: some View {
    NavigationSplitView {
      sidebar
    } detail: {
      if let selectedFile {
        PlayerView(audioFile: selectedFile)
      } else {
        emptyStateView
      }
    }
    .fileImporter(
      isPresented: $isImportingFile,
      allowedContentTypes: [UTType.mp3, UTType.audio],
      allowsMultipleSelection: false,
      onCompletion: handleFileImportResult
    )
    .fileImporter(
      isPresented: $isImportingFolder,
      allowedContentTypes: [UTType.folder],
      allowsMultipleSelection: false,
      onCompletion: handleFolderImportResult
    )
    .onAppear {
      sessionTracker.attachModelContext(modelContext)
      playerManager.sessionTracker = sessionTracker
      restoreLastSelectionIfNeeded()
      setupPlaybackEndedHandler()
    }
    .task(id: allAudioFiles.map(\.id)) {
      restoreLastSelectionIfNeeded()
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

  // MARK: - Empty State

  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "waveform.circle")
        .font(.system(size: 64))
        .foregroundStyle(.tertiary)

      Text("No file selected")
        .font(.title2)

      Text("Import a folder or MP3 file to start creating A-B loops.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }

  // MARK: - Sidebar

  private var sidebar: some View {
    FolderNavigationView(
      selectedFile: $selectedFile,
      currentFolder: $currentFolder,
      navigationPath: $navigationPath,
      onSelectFile: { file in await selectFile(file) },
      onPlayFile: { file, fromStart in await playFile(file, fromStart: fromStart) }
    )
    .navigationTitle("ABPlayer")
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Menu {
          Button {
            isImportingFile = true
          } label: {
            Label("Import Audio File", systemImage: "music.note")
          }

          Button {
            isImportingFolder = true
          } label: {
            Label("Import Folder", systemImage: "folder.badge.plus")
          }
        } label: {
          Label("Add", systemImage: "plus")
        }

        Menu {
          Button(role: .destructive) {
            clearAllData()
          } label: {
            Label("Clear All Data", systemImage: "trash")
          }
        } label: {
          Label("More", systemImage: "ellipsis.circle")
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      versionFooter
    }
  }

  private var versionFooter: some View {
    Text("Version \(bundleShortVersion) • Build \(bundleVersion)")
      .font(.caption2)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.bottom, 8)
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
      let bookmarkData = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      let displayName = url.lastPathComponent
      let audioFile = AudioFile(
        displayName: displayName,
        bookmarkData: bookmarkData,
        folder: currentFolder
      )

      modelContext.insert(audioFile)
      currentFolder?.audioFiles.append(audioFile)
      Task { await selectFile(audioFile) }
    } catch {
      importErrorMessage = "Failed to import file: \(error.localizedDescription)"
    }
  }

  private func importFolder(from url: URL) {
    let importer = FolderImporter(modelContext: modelContext)

    do {
      if let folder = try importer.importFolder(at: url) {
        // Select first audio file if available
        if let firstFile = folder.audioFiles.first {
          Task { await selectFile(firstFile) }
        }
      }
    } catch {
      importErrorMessage = "Failed to import folder: \(error.localizedDescription)"
    }
  }

  // MARK: - Selection

  private func selectFile(_ file: AudioFile, fromStart: Bool = false) async {
    selectedFile = file
    lastSelectedAudioFileID = file.id.uuidString
    lastFolderID = file.folder?.id.uuidString

    if playerManager.currentFile?.id == file.id,
      playerManager.currentFile != nil
    {
      playerManager.currentFile = file
      return
    }

    await playerManager.load(audioFile: file, fromStart: fromStart)
  }

  private func playFile(_ file: AudioFile, fromStart: Bool = false) async {
    await selectFile(file, fromStart: fromStart)
    playerManager.play()
  }

  private func restoreLastSelectionIfNeeded() {
    // Restore folder navigation
    if currentFolder == nil, navigationPath.isEmpty,
      let lastFolderID,
      let folderUUID = UUID(uuidString: lastFolderID),
      let folder = allFolders.first(where: { $0.id == folderUUID })
    {
      // Build navigation path from root to folder
      var path: [Folder] = []
      var current: Folder? = folder
      while let f = current {
        path.insert(f, at: 0)
        current = f.parent
      }
      navigationPath = path
      currentFolder = folder
    }

    guard selectedFile == nil else {
      if let currentFile = playerManager.currentFile,
        let matchedFile = allAudioFiles.first(where: { $0.id == currentFile.id })
      {
        selectedFile = matchedFile
        playerManager.currentFile = matchedFile
      }
      return
    }

    if let currentFile = playerManager.currentFile,
      let matchedFile = allAudioFiles.first(where: { $0.id == currentFile.id })
    {
      selectedFile = matchedFile
      playerManager.currentFile = matchedFile
      return
    }

    guard let lastSelectedAudioFileID,
      let lastID = UUID(uuidString: lastSelectedAudioFileID),
      let file = allAudioFiles.first(where: { $0.id == lastID })
    else {
      return
    }

    Task { await selectFile(file) }
  }

  // MARK: - Playback Loop Handling

  private func setupPlaybackEndedHandler() {
    playerManager.onPlaybackEnded = { [weak playerManager] currentFile in
      guard let playerManager,
        let currentFile,
        let folder = currentFile.folder
      else { return }

      let files = folder.sortedAudioFiles
      guard !files.isEmpty else { return }

      let nextFile: AudioFile?

      switch playerManager.loopMode {
      case .none, .repeatOne:
        // These cases are handled in AudioPlayerManager
        return

      case .repeatAll:
        // Play next file in sequence, wrap around to first
        if let currentIndex = files.firstIndex(where: { $0.id == currentFile.id }) {
          let nextIndex = (currentIndex + 1) % files.count
          nextFile = files[nextIndex]
        } else {
          nextFile = files.first
        }

      case .shuffle:
        // Play random file (different from current if possible)
        if files.count > 1 {
          var randomFile: AudioFile
          repeat {
            randomFile = files.randomElement()!
          } while randomFile.id == currentFile.id
          nextFile = randomFile
        } else {
          nextFile = files.first
        }
      }

      if let nextFile {
        Task { @MainActor in
          await self.playFile(nextFile, fromStart: true)
        }
      }
    }
  }

  // MARK: - Data Management

  private func clearAllData() {
    // Clear all data from SwiftData
    do {
      try modelContext.delete(model: AudioFile.self)
      try modelContext.delete(model: LoopSegment.self)
      try modelContext.delete(model: Folder.self)
      try modelContext.delete(model: SubtitleFile.self)
      try modelContext.save()

      selectedFile = nil
      currentFolder = nil
      navigationPath = []
      playerManager.currentFile = nil
    } catch {
      importErrorMessage = "Failed to clear data: \(error.localizedDescription)"
    }
  }
}
