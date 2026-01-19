import Combine
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
  import AppKit
#endif

public struct MainSplitView: View {
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(SessionTracker.self) private var sessionTracker
  @Environment(\.modelContext) private var modelContext
  @Environment(\.openURL) private var openURL

  @Query(sort: \ABFile.createdAt, order: .forward)
  private var allAudioFiles: [ABFile]

  @Query(sort: \Folder.name)
  private var allFolders: [Folder]

  @State private var selectedFile: ABFile?
  @State private var currentFolder: Folder?
  @State private var navigationPath: [Folder] = []
  @State private var isImportingFile: Bool = false
  @State private var isImportingFolder: Bool = false
  @State private var importErrorMessage: String?
  @State private var isClearingData: Bool = false
  @AppStorage("lastSelectedAudioFileID") private var lastSelectedAudioFileID: String?
  @AppStorage("lastFolderID") private var lastFolderID: String?
  @State private var loadAudioTask: Task<Void, Never>?

  public init() {}

  public var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 400)
        .background(Color.asset.bgPrimary)
    } detail: {
      if let selectedFile {
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
      sessionTracker.setModelContainer(modelContext.container)
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

  // MARK: - Sidebar

  private var sidebar: some View {
    Group {
      if isClearingData {
        ProgressView("Clearing...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        FolderNavigationView(
          selectedFile: $selectedFile,
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
            Label("Import Media File", systemImage: "music.note")
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
      let bookmarkData = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      let displayName = url.lastPathComponent
      let deterministicID = ABFile.generateDeterministicID(from: bookmarkData)

      let audioFile = ABFile(
        id: deterministicID,
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
    Task {
      let importer = FolderImporter(modelContainer: modelContext.container)

      do {
        if let folderID = try await importer.syncFolder(at: url) {
          // Select first audio file if available
          await MainActor.run {
            if let folder = modelContext.model(for: folderID) as? Folder,
               let firstFile = folder.audioFiles.first {
              Task {
                await selectFile(firstFile)
              }
            }
          }
        }
      } catch {
        await MainActor.run {
          importErrorMessage = "Failed to import folder: \(error.localizedDescription)"
        }
      }
    }
  }

  // MARK: - Selection

  private func selectFile(_ file: ABFile, fromStart: Bool = false, debounce: Bool = true) async {
    lastSelectedAudioFileID = file.id.uuidString
    lastFolderID = file.folder?.id.uuidString

    if playerManager.currentFile?.id == file.id,
      playerManager.currentFile != nil
    {
      playerManager.currentFile = file
      return
    }

    // Update selectedFile first so the view switches immediately
    // (e.g., video -> audio won't show loading in video view first)
    selectedFile = file

    loadAudioTask?.cancel()
    if debounce {
      loadAudioTask = Task {
        await playerManager.clearPlayer()
        if !Task.isCancelled {
          await playerManager.load(audioFile: file, fromStart: fromStart)
        }
      }
    } else {
      await playerManager.load(audioFile: file, fromStart: fromStart)
    }
  }

  private func playFile(_ file: ABFile, fromStart: Bool = false) async {
    await selectFile(file, fromStart: fromStart, debounce: false)
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

      let nextFile: ABFile?

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
          var randomFile: ABFile
          repeat {
            randomFile = files.randomElement()!
          } while randomFile.id == currentFile.id
          nextFile = randomFile
        } else {
          nextFile = files.first
        }

      case .autoPlayNext:
        // Play next file in sequence, stop if at end
        if let currentIndex = files.firstIndex(where: { $0.id == currentFile.id }),
          currentIndex + 1 < files.count
        {
          nextFile = files[currentIndex + 1]
        } else {
          nextFile = nil
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
    // IMPORTANT: Clear UI state and player references FIRST to prevent
    // accessing detached/faulted entities during deletion
    do {
      // Step 1: Stop playback if currently playing
      if playerManager.isPlaying {
        playerManager.togglePlayPause()
      }

      // Step 2: Clear UI state and player references immediately
      selectedFile = nil
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
