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
          .font(.headline)
          .lineLimit(1)

        Spacer()
      }
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
}
