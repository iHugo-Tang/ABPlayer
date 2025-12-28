import SwiftData
import SwiftUI

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

  let onSelectFile: (AudioFile) async -> Void
  let onPlayFile: (AudioFile, Bool) async -> Void

  var body: some View {
    VStack(spacing: 0) {
      navigationHeader
      fileList
    }
    .onChange(of: selection) { _, newValue in
      handleSelectionChange(newValue)
    }
    .onChange(of: selectedFile) { _, _ in
      syncSelectionWithSelectedFile()
    }
    .onChange(of: currentFolder) { _, _ in
      syncSelectionWithSelectedFile()
    }
    .onAppear {
      syncSelectionWithSelectedFile()
    }
  }

  // MARK: - Navigation Header

  private var navigationHeader: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        navigateBack()
      }
    } label: {
      HStack {
        if !navigationPath.isEmpty {
          Label("Back", systemImage: "chevron.left")
            .labelStyle(.iconOnly)
        }

        Text(currentFolder?.name ?? "Library")
          .lineLimit(1)

        Spacer()
      }
      .font(.title3)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusable(false)
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
  private func syncSelectionWithSelectedFile() {
    guard let selectedFile else {
      selection = nil
      return
    }

    // Check if selectedFile is in current folder
    let isInCurrentFolder = currentAudioFiles.contains { $0.id == selectedFile.id }

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
    let isSelected = selectedFile?.id == file.id

    return HStack {
      Image(systemName: "music.note")
        .foregroundStyle(file.subtitleFile != nil ? .blue : .secondary)

      VStack(alignment: .leading) {
        Text(file.displayName)
          .lineLimit(1)

        HStack(spacing: 4) {
          Text(file.createdAt, style: .date)

          if file.subtitleFile != nil {
            Text("•")
            Image(systemName: "text.bubble")
              .font(.caption2)
          }

          if file.hasTranscription {
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
        .captionStyle()
        .foregroundStyle(.secondary)
      }

      Spacer()

      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.tint)
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
    if let folder = currentFolder {
      return folder.subfolders.sorted { $0.name < $1.name }
    }
    return rootFolders
  }

  private var currentAudioFiles: [AudioFile] {
    if let folder = currentFolder {
      return folder.sortedAudioFiles
    }
    return rootAudioFiles
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
