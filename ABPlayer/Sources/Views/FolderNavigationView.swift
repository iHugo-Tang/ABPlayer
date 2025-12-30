import SwiftData
import SwiftUI

// MARK: - Sort Order

enum SortOrder: String, CaseIterable {
  case nameAZ = "Name (A-Z)"
  case nameZA = "Name (Z-A)"
  case dateCreatedNewestFirst = "Date Created (Newest First)"
  case dateCreatedOldestFirst = "Date Created (Oldest First)"
}

// MARK: - Selection Item

enum SelectionItem: Hashable {
  case folder(Folder)
  case audioFile(AudioFile)
  case empty
}

/// Hierarchical folder navigation view for the sidebar
struct FolderNavigationView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AudioPlayerManager.self) private var playerManager

  @Query(filter: #Predicate<Folder> { $0.parent == nil }, sort: \Folder.name)
  private var rootFolders: [Folder]

  @Query(filter: #Predicate<AudioFile> { $0.folder == nil }, sort: \AudioFile.createdAt)
  private var rootAudioFiles: [AudioFile]

  @Binding var selectedFile: AudioFile?
  @Binding var currentFolder: Folder?
  @Binding var navigationPath: [Folder]

  @State private var selection: SelectionItem?
  @State private var isSyncing = false
  @State private var syncTask: Task<Void, Never>?
  @State private var sortOrder: SortOrder = .nameAZ
  @State private var isRescanningFolder = false

  let onSelectFile: (AudioFile) async -> Void

  var body: some View {
    VStack(spacing: 0) {
      navigationHeader
      fileList
    }
    .onChange(of: selection) { _, newValue in
      handleSelectionChange(newValue)
    }
    .onChange(of: currentFolder) { _, _ in
      syncAsync()
    }
    .onChange(of: selectedFile) { _, _ in
      syncAsync()
    }
    .task {
      await syncSelectionWithSelectedFile()
    }
  }

  private func syncAsync() {
    syncTask?.cancel()
    syncTask = Task {
      await syncSelectionWithSelectedFile()
    }
  }

  // MARK: - Navigation Header

  private var navigationHeader: some View {
    HStack {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          navigateBack()
        }
      } label: {
        HStack(spacing: 4) {
          if !navigationPath.isEmpty {
            Label("Back", systemImage: "chevron.left")
              .labelStyle(.iconOnly)
          }

          Text(currentFolder?.name ?? "Library")
            .lineLimit(1)
        }
      }
      .buttonStyle(.plain)

      Spacer()

      if isRescanningFolder {
        ProgressView()
          .controlSize(.small)
      } else if currentFolder != nil {
        // Rescan button
        Button {
          rescanCurrentFolder()
        } label: {
          Label("Rescan", systemImage: "arrow.clockwise")
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .disabled(isRescanningFolder)
      }

      // Sort menu
      Menu {
        ForEach(SortOrder.allCases, id: \.self) { order in
          Button {
            sortOrder = order
          } label: {
            HStack {
              Text(order.rawValue)
              if sortOrder == order {
                Image(systemName: "checkmark")
              }
            }
          }
        }
      } label: {
        Label("Sort", systemImage: "arrow.up.arrow.down")
          .labelStyle(.iconOnly)
      }
      .buttonStyle(.plain)
    }
    .font(.title3)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.bar)
  }

  // MARK: - File List

  private var fileList: some View {
    List(selection: $selection) {
      // Folders section
      if !currentFolders.isEmpty {
        Section("Folders") {
          ForEach(currentFolders) { folder in
            folderRow(for: folder)
              .tag(SelectionItem.folder(folder))
          }
        }
      }

      // Audio files section
      if !currentAudioFiles.isEmpty {
        Section("Audio Files") {
          ForEach(currentAudioFiles) { file in
            audioFileRow(for: file)
              .tag(SelectionItem.audioFile(file))
          }
        }
      }
    }
    // 将 Empty State 放在这里
    .overlay {
      // Empty state
      if currentFolders.isEmpty && currentAudioFiles.isEmpty {
        ContentUnavailableView(
          "No Content",
          systemImage: "folder",
          description: Text("Import a folder to get started")
        )
        .tag(SelectionItem.empty)
      }
    }
  }

  // MARK: - Selection Handling

  private func handleSelectionChange(_ newSelection: SelectionItem?) {
    guard let newSelection else { return }

    switch newSelection {
    case .folder(let folder):
      withAnimation(.easeInOut(duration: 0.2)) {
        navigateInto(folder)
      }
    // selection will be synced by onChange(of: currentFolder)

    case .audioFile(let file):
      Task { await onSelectFile(file) }

    case .empty:
      break
    }
  }

  /// Syncs the List selection state with selectedFile
  /// - If selectedFile is in current folder, select corresponding row
  /// - Otherwise clear List selection (but keep selectedFile for player)
  @MainActor
  private func syncSelectionWithSelectedFile() async {
    guard let selectedFile else {
      selection = nil
      return
    }

    isSyncing = true
    defer { isSyncing = false }

    // Give a small delay to avoid flickering if it's very fast,
    // and to ensure UI responsiveness if called frequently
    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

    if Task.isCancelled { return }

    // Check if selectedFile is in current folder
    let isInCurrentFolder = currentAudioFiles.contains { $0.id == selectedFile.id }

    if Task.isCancelled { return }

    if isInCurrentFolder {
      // Only update if needed to avoid unnecessary state changes
      if case .audioFile(let current) = selection, current.id == selectedFile.id {
        return
      }
      selection = .audioFile(selectedFile)
    } else {
      // File not in current folder - clear List selection
      selection = nil
    }
  }

  // MARK: - Folder Row

  private func folderRow(for folder: Folder) -> some View {
    HStack {
      Image(systemName: "folder.fill")
        .foregroundStyle(.secondary)

      VStack(alignment: .leading) {
        Text(folder.name)
          .lineLimit(1)
          .font(.appHeadline)

        let count = folder.audioFiles.count + folder.subfolders.count
        Text("\(count) items")
          .captionStyle()
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundStyle(.tertiary)
        .font(.caption)
    }
    .contentShape(Rectangle())
    .contextMenu {
      Button(role: .destructive) {
        deleteFolder(folder)
      } label: {
        Label("Delete Folder", systemImage: "trash")
      }
    }
  }

  // MARK: - Audio File Row

  private func audioFileRow(for file: AudioFile) -> some View {
    let isAvailable = file.isBookmarkValid

    return HStack {
      // 文件图标
      if isAvailable {
        Image(systemName: "music.note")
          .foregroundStyle(file.isPlaybackComplete ? Color.secondary : Color.blue)
      } else {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
      }

      VStack(alignment: .leading) {
        Text(file.displayName)
          .lineLimit(1)
          .strikethrough(!isAvailable, color: .secondary)
          .foregroundStyle(isAvailable ? .primary : .secondary)

        HStack(spacing: 4) {
          if !isAvailable {
            Text("文件不可用")
              .foregroundStyle(.orange)
          } else {
            Text(file.createdAt, style: .date)

            if file.subtitleFile != nil {
              Text("•")
              Image(systemName: "text.bubble")
                .font(.caption2)
            }

            if file.hasTranscriptionRecord {
              Text("•")
              Image(systemName: "waveform")
                .font(.caption2)
            }

            if file.pdfBookmarkData != nil {
              Text("•")
              Image(systemName: "doc.text")
                .font(.caption2)
            }
          }
        }
        .captionStyle()
        .foregroundStyle(.secondary)
      }
    }
    .contentShape(Rectangle())
    .contextMenu {
      Button(role: .destructive) {
        deleteAudioFile(file)
      } label: {
        Label("Delete File", systemImage: "trash")
      }
    }
  }

  // MARK: - Computed Properties

  private var currentFolders: [Folder] {
    let folders: [Folder]
    if let folder = currentFolder {
      folders = Array(folder.subfolders)
    } else {
      folders = rootFolders
    }

    switch sortOrder {
    case .nameAZ:
      return folders.sorted { $0.name < $1.name }
    case .nameZA:
      return folders.sorted { $0.name > $1.name }
    case .dateCreatedNewestFirst:
      return folders.sorted { $0.createdAt > $1.createdAt }
    case .dateCreatedOldestFirst:
      return folders.sorted { $0.createdAt < $1.createdAt }
    }
  }

  private var currentAudioFiles: [AudioFile] {
    let files: [AudioFile]
    if let folder = currentFolder {
      files = Array(folder.audioFiles)
    } else {
      files = rootAudioFiles
    }

    switch sortOrder {
    case .nameAZ:
      return files.sorted { $0.displayName < $1.displayName }
    case .nameZA:
      return files.sorted { $0.displayName > $1.displayName }
    case .dateCreatedNewestFirst:
      return files.sorted { $0.createdAt > $1.createdAt }
    case .dateCreatedOldestFirst:
      return files.sorted { $0.createdAt < $1.createdAt }
    }
  }

  // MARK: - Navigation Actions

  private func navigateInto(_ folder: Folder) {
    navigationPath.append(folder)
    currentFolder = folder
  }

  private func navigateBack() {
    guard !navigationPath.isEmpty else { return }
    navigationPath.removeLast()
    currentFolder = navigationPath.last
  }

  /// 重新扫描当前文件夹（用于同步磁盘变更）
  private func rescanCurrentFolder() {
    guard let folder = currentFolder else { return }

    // 找到根文件夹
    let rootFolder = folder.rootFolder

    // 检查根文件夹是否有 bookmark
    guard let url = try? rootFolder.resolveURL() else {
      print("⚠️ No root folder bookmark found")
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
        let importer = FolderImporter(modelContext: modelContext)
        _ = try importer.syncFolder(at: url)
        print("✅ Successfully rescanned folder: \(rootFolder.name)")
      } catch {
        print("❌ Failed to rescan folder: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Deletion Actions

  /// Deletes a folder and all its contents (subfolders and audio files) recursively
  private func deleteFolder(_ folder: Folder) {
    // Save any pending changes before deletion to prevent conflicts
    do {
      try modelContext.save()
    } catch {
      print("⚠️ Failed to save context before folder deletion: \(error.localizedDescription)")
    }

    // Check if current file is in this folder (playing or not)
    if isCurrentFileInFolder(folder) {
      if playerManager.isPlaying {
        playerManager.togglePlayPause()
      }
      playerManager.currentFile = nil
    }

    // Check if any file in this folder (or subfolders) is currently selected
    if isSelectedFileInFolder(folder) {
      selectedFile = nil
    }

    // If the folder being deleted is currently selected, navigate back
    if currentFolder?.id == folder.id {
      navigateBack()
    }

    // Recursively delete all subfolders
    for subfolder in folder.subfolders {
      deleteFolder(subfolder)
    }

    // Delete all audio files in this folder (without updating selection since we already handled it)
    for audioFile in folder.audioFiles {
      deleteAudioFile(audioFile, updateSelection: false, checkPlayback: false)
    }

    // Delete the folder itself
    modelContext.delete(folder)
  }

  /// Deletes an audio file and all its related data (segments, subtitle, transcription)
  private func deleteAudioFile(
    _ file: AudioFile, updateSelection: Bool = true, checkPlayback: Bool = true
  ) {
    // Save any pending changes before deletion to prevent conflicts
    // Only save if this is a user-initiated delete (not recursive)
    if checkPlayback {
      do {
        try modelContext.save()
      } catch {
        print("⚠️ Failed to save context before file deletion: \(error.localizedDescription)")
      }
    }

    // If the file being deleted is currently playing, stop playback
    if checkPlayback && playerManager.isPlaying && playerManager.currentFile?.id == file.id {
      playerManager.togglePlayPause()
    }

    // If the file being deleted is currently selected, clear selection and player
    if updateSelection && selectedFile?.id == file.id {
      selectedFile = nil
      playerManager.currentFile = nil
    }

    // Delete all related loop segments
    for segment in file.segments {
      modelContext.delete(segment)
    }

    // Delete related subtitle file if exists
    if let subtitleFile = file.subtitleFile {
      modelContext.delete(subtitleFile)
    }

    // Delete related transcription if exists
    let fileIdString = file.id.uuidString
    let descriptor = FetchDescriptor<Transcription>(
      predicate: #Predicate<Transcription> { $0.audioFileId == fileIdString }
    )
    if let transcriptions = try? modelContext.fetch(descriptor) {
      for transcription in transcriptions {
        modelContext.delete(transcription)
      }
    }

    // Delete the audio file itself
    modelContext.delete(file)
  }

  /// Checks if the folder (or any subfolder) contains the current file (playing or paused)
  private func isCurrentFileInFolder(_ folder: Folder) -> Bool {
    guard let currentFile = playerManager.currentFile else {
      return false
    }

    // Check if current file is in this folder
    if folder.audioFiles.contains(where: { $0.id == currentFile.id }) {
      return true
    }

    // Recursively check subfolders
    for subfolder in folder.subfolders {
      if isCurrentFileInFolder(subfolder) {
        return true
      }
    }

    return false
  }

  /// Checks if the selected file is within the folder (or any subfolder)
  private func isSelectedFileInFolder(_ folder: Folder) -> Bool {
    guard let selectedFile else { return false }

    // Check if selected file is in this folder
    if folder.audioFiles.contains(where: { $0.id == selectedFile.id }) {
      return true
    }

    // Recursively check subfolders
    for subfolder in folder.subfolders {
      if isSelectedFileInFolder(subfolder) {
        return true
      }
    }

    return false
  }
}
