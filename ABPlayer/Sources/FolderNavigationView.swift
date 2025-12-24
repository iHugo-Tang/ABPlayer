import SwiftData
import SwiftUI

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

  let onSelectFile: (AudioFile) -> Void

  var body: some View {
    VStack(spacing: 0) {
      navigationHeader
      fileList
    }
  }

  // MARK: - Navigation Header

  private var navigationHeader: some View {
    HStack {
      if !navigationPath.isEmpty {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            navigateBack()
          }
        } label: {
          Label("Back", systemImage: "chevron.left")
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
      }

      Text(currentFolder?.name ?? "Library")
        .font(.headline)
        .lineLimit(1)

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.bar)
  }

  // MARK: - File List

  private var fileList: some View {
    List(
      selection: Binding(
        get: { selectedFile?.id },
        set: { _ in }
      )
    ) {
      // Folders section
      if !currentFolders.isEmpty {
        Section("Folders") {
          ForEach(currentFolders) { folder in
            folderRow(for: folder)
          }
        }
      }

      // Audio files section
      if !currentAudioFiles.isEmpty {
        Section("Audio Files") {
          ForEach(currentAudioFiles) { file in
            audioFileRow(for: file)
          }
        }
      }

      // Empty state
      if currentFolders.isEmpty && currentAudioFiles.isEmpty {
        ContentUnavailableView(
          "No Content",
          systemImage: "folder",
          description: Text("Import a folder to get started")
        )
      }
    }
  }

  // MARK: - Folder Row

  private func folderRow(for folder: Folder) -> some View {
    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        navigateInto(folder)
      }
    } label: {
      HStack {
        Image(systemName: "folder.fill")
          .foregroundStyle(.secondary)

        VStack(alignment: .leading) {
          Text(folder.name)
            .lineLimit(1)

          let count = folder.audioFiles.count + folder.subfolders.count
          Text("\(count) items")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundStyle(.tertiary)
          .font(.caption)
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Audio File Row

  private func audioFileRow(for file: AudioFile) -> some View {
    let isSelected = selectedFile?.id == file.id

    return Button {
      onSelectFile(file)
    } label: {
      HStack {
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
          .font(.caption2)
          .foregroundStyle(.secondary)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.tint)
        }
      }
    }
    .buttonStyle(.plain)
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
      return folder.audioFiles.sorted { $0.createdAt < $1.createdAt }
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
