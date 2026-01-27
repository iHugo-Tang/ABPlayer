import Combine
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import Observation

#if os(macOS)
import AppKit
#endif

@MainActor
public struct MainSplitView: View {
  public enum ImportType {
    case file
    case folder
    
    var allowedContentTypes: [UTType] {
      switch self {
        case .file:
          return [.audio, .movie]
        case .folder:
          return [.folder]
      }
    }
  }
  
  @Environment(PlayerManager.self) private var playerManager: PlayerManager
  @Environment(SessionTracker.self) private var sessionTracker: SessionTracker
  @Environment(LibrarySettings.self) private var librarySettings
  @Environment(\.modelContext) private var modelContext
  @Environment(\.openURL) private var openURL
  
  @State private var folderNavigationViewModel: FolderNavigationViewModel?
  @State private var mainSplitViewModel = MainSplitViewModel()
  @State private var didAttemptRestoreNavigationPath = false
  
  @Query(sort: \ABFile.createdAt, order: .forward)
  private var allAudioFiles: [ABFile]
  
  @Query(sort: \Folder.name)
  private var allFolders: [Folder]
  
  @State private var isClearingData: Bool = false
  
  public init() {}
  
  public var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: 220, ideal: 300, max: 400)
        .background(Color.asset.bgPrimary)
    } detail: {
      if let selectedFile = folderNavigationViewModel?.selectedFile {
        threePanelLayout(for: selectedFile)
      } else {
        EmptyStateView()
      }
    }
    .frame(minWidth: 1000, minHeight: 600)
    .fileImporter(
      isPresented: Binding(
        get: { folderNavigationViewModel?.presetnImportType != nil },
        set: { if !$0 { folderNavigationViewModel?.presetnImportType = nil } }
      ),
      allowedContentTypes: folderNavigationViewModel?.importType?.allowedContentTypes ?? [],
      allowsMultipleSelection: false,
      onCompletion: { result in
        folderNavigationViewModel?.handleImportResult(result)
      }
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
      setupPlaybackEndedHandler()
    }
    .task(id: allAudioFiles.map(\.id)) {
      restoreLastSelectionIfNeeded()
    }
    .onChange(of: folderNavigationViewModel?.currentFolder?.id, initial: true) { _, _ in
      if let folder = folderNavigationViewModel?.currentFolder {
        playerManager.playbackQueue.updateQueue(folder.sortedAudioFiles)
      } else {
        playerManager.playbackQueue.updateQueue([])
      }
    }
    .onChange(of: folderNavigationViewModel?.selectedFile?.isVideo) { _, isVideo in
      if let isVideo {
        mainSplitViewModel.switchMediaType(to: isVideo ? .video : .audio)
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
      isPresented: .constant(folderNavigationViewModel?.importErrorMessage != nil),
      presenting: folderNavigationViewModel?.importErrorMessage
    ) { _ in
      Button("OK", role: .cancel) {
        folderNavigationViewModel?.importErrorMessage = nil
      }
    } message: { message in
      Text(message)
    }
  }
  
  @ViewBuilder
  private func threePanelLayout(for selectedFile: ABFile) -> some View {
    ThreePanelLayout(
      isRightVisible: $mainSplitViewModel.showContentPanel,
      leftColumnWidth: $mainSplitViewModel.playerSectionWidth,
      draggingLeftColumnWidth: $mainSplitViewModel.draggingWidth,
      minLeftColumnWidth: mainSplitViewModel.minWidthOfPlayerSection,
      minRightWidth: mainSplitViewModel.minWidthOfContentPanel,
      clampLeftColumnWidth: mainSplitViewModel.clampWidth,
      isBottomLeftVisible: $mainSplitViewModel.showBottomPanel,
      topLeftHeight: $mainSplitViewModel.topPanelHeight,
      draggingTopLeftHeight: $mainSplitViewModel.draggingHeight,
      minTopLeftHeight: mainSplitViewModel.minHeightOfTopPanel,
      minBottomLeftHeight: mainSplitViewModel.minHeightOfBottomPanel,
      clampTopLeftHeight: mainSplitViewModel.clampHeight,
      dividerThickness: mainSplitViewModel.dividerWidth
    ) {
      if selectedFile.isVideo {
        VideoPlayerView(audioFile: selectedFile)
      } else {
        AudioPlayerView(audioFile: selectedFile)
      }
    } bottomLeft: {
      bottomLeftPane(for: selectedFile)
    } right: {
      rightPane(for: selectedFile)
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        sessionTimeDisplay
      }
      ToolbarItem(placement: .primaryAction) {
        Button {
          mainSplitViewModel.showContentPanel.toggle()
        } label: {
          Label(
            mainSplitViewModel.showContentPanel ? "Hide Panel" : "Show Panel",
            systemImage: mainSplitViewModel.showContentPanel ? "sidebar.trailing" : "sidebar.trailing"
          )
        }
        .help(mainSplitViewModel.showContentPanel ? "Hide content panel" : "Show content panel")
      }
    }
  }

  private func bottomLeftPane(for selectedFile: ABFile) -> some View {
    DynamicPaneView(
      title: "Bottom Pane",
      tabs: mainSplitViewModel.leftTabs,
      selection: $mainSplitViewModel.leftSelection,
      addOptions: mainSplitViewModel.availableContents(for: .bottomLeft),
      onAdd: { content in
        mainSplitViewModel.move(content: content, to: .bottomLeft)
      },
      onRemove: { content in
        mainSplitViewModel.remove(content: content, from: .bottomLeft)
      },
      bodyContent: { content in
        paneContentView(for: content, audioFile: selectedFile)
      }
    )
  }

  private func rightPane(for selectedFile: ABFile) -> some View {
    DynamicPaneView(
      title: "Right Pane",
      tabs: mainSplitViewModel.rightTabs,
      selection: $mainSplitViewModel.rightSelection,
      addOptions: mainSplitViewModel.availableContents(for: .right),
      onAdd: { content in
        mainSplitViewModel.move(content: content, to: .right)
      },
      onRemove: { content in
        mainSplitViewModel.remove(content: content, from: .right)
      },
      bodyContent: { content in
        paneContentView(for: content, audioFile: selectedFile)
      }
    )
  }

  @ViewBuilder
  private func paneContentView(for content: PaneContent, audioFile: ABFile) -> some View {
    switch content {
      case .none:
        ContentUnavailableView(
          "Nothing Selected",
          systemImage: "rectangle.2.swap",
          description: Text("Use + to add Transcription, PDF, or Segments.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
      case .transcription:
        TranscriptionView(audioFile: audioFile)
        
      case .pdf:
#if os(macOS)
        if let pdfData = audioFile.pdfBookmarkData {
          PDFContentView(pdfBookmarkData: pdfData)
        } else {
          PDFEmptyView()
        }
#else
        ContentUnavailableView(
          "PDF Not Available",
          systemImage: "doc.text",
          description: Text("PDF viewing is only available on macOS")
        )
#endif
        
      case .segments:
        SegmentsSection(audioFile: audioFile)
    }
  }
  
  // MARK: - Components
  
  private var sessionTimeDisplay: some View {
    HStack(spacing: 6) {
      Image(systemName: "timer")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
      Text(timeString(from: Double(sessionTracker.displaySeconds)))
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .foregroundStyle(.primary)
      
      Button {
        sessionTracker.resetSession()
      } label: {
        Image(systemName: "arrow.counterclockwise")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help("Reset session")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(.ultraThinMaterial, in: Capsule())
    .help("Session practice time")
  }
  
  private func timeString(from value: Double) -> String {
    guard value.isFinite, value >= 0 else {
      return "0:00"
    }
    
    let totalSeconds = Int(value.rounded())
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    
    return String(format: "%d:%02d", minutes, seconds)
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
          onSelectFile: { file in await selectFile(file) }
        )
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Menu {
          Button {
            folderNavigationViewModel?.importType = .file
            folderNavigationViewModel?.presetnImportType = .file
          } label: {
            Label("Import Media File", systemImage: "tray.and.arrow.down")
          }
          
          Button {
            folderNavigationViewModel?.importType = .folder
            folderNavigationViewModel?.presetnImportType = .folder
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
  
  // MARK: - Selection
  
  private func selectFile(_ file: ABFile, fromStart: Bool = false, debounce: Bool = true) async {
    await playerManager.selectFile(file, fromStart: fromStart, debounce: debounce)
  }
  
  private func playFile(_ file: ABFile, fromStart: Bool = false) async {
    await playerManager.playFile(file, fromStart: fromStart)
  }
  
  private func restoreLastSelectionIfNeeded() {
    guard let folderNavigationViewModel else { return }

    if !didAttemptRestoreNavigationPath {
      defer { didAttemptRestoreNavigationPath = true }

      if folderNavigationViewModel.currentFolder == nil, folderNavigationViewModel.navigationPath.isEmpty,
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
        folderNavigationViewModel.navigationPath = path
        folderNavigationViewModel.currentFolder = folder
      }
    }
    
    guard folderNavigationViewModel.selectedFile == nil else {
      if let currentFile = playerManager.currentFile,
         let matchedFile = allAudioFiles.first(where: { $0.id == currentFile.id })
      {
       folderNavigationViewModel.selectedFile = matchedFile
       playerManager.currentFile = matchedFile
       return
      }
      
      if let selectedFile = folderNavigationViewModel.selectedFile,
         playerManager.currentFile?.id != selectedFile.id
      {
       Task { await selectFile(selectedFile) }
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
    
    if let folder = folderNavigationViewModel.currentFolder,
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
      folderNavigationViewModel?.currentFolder = nil
      folderNavigationViewModel?.navigationPath = []
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
      folderNavigationViewModel?.importErrorMessage = "Failed to clear data: \(error.localizedDescription)"
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
