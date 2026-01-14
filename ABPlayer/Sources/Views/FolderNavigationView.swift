import OSLog
import SwiftData
import SwiftUI

// MARK: - Sort Order

enum SortOrder: String, CaseIterable {
  case nameAZ = "Name (A-Z)"
  case nameZA = "Name (Z-A)"
  case numberAsc = "Number (Smallest First)"
  case numberDesc = "Number (Biggest First)"
  case dateCreatedNewestFirst = "Date Created (Newest First)"
  case dateCreatedOldestFirst = "Date Created (Oldest First)"
}

// MARK: - Selection Item

enum SelectionItem: Hashable {
  case folder(Folder)
  case audioFile(ABFile)
  case empty
}

/// Hierarchical folder navigation view for the sidebar
struct FolderNavigationView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AudioPlayerManager.self) private var playerManager

  @Query(filter: #Predicate<Folder> { $0.parent == nil }, sort: \Folder.name)
  private var rootFolders: [Folder]

  @Query(filter: #Predicate<ABFile> { $0.folder == nil }, sort: \ABFile.createdAt)
  private var rootAudioFiles: [ABFile]

  @Binding var selectedFile: ABFile?
  @Binding var currentFolder: Folder?
  @Binding var navigationPath: [Folder]

  @State private var viewModel: FolderNavigationViewModel?
  @State private var isDeselecting = false
  @State private var selectionBeforePress: SelectionItem?

  let onSelectFile: (ABFile) async -> Void

  var body: some View {
    VStack(spacing: 0) {
      navigationHeader
      fileList
    }
    .onAppear {
      if viewModel == nil {
        viewModel = FolderNavigationViewModel(
          modelContext: modelContext,
          playerManager: playerManager
        )
        
        if let savedSortOrder = UserDefaults.standard.string(forKey: "folderNavigationSortOrder"),
           let sortOrder = SortOrder(rawValue: savedSortOrder) {
          viewModel?.sortOrder = sortOrder
        }
      }

      if let selectedFile {
        viewModel?.selection = .audioFile(selectedFile)
      }
    }
    .onChange(of: viewModel?.sortOrder) { _, newValue in
      if let newValue {
        UserDefaults.standard.set(newValue.rawValue, forKey: "folderNavigationSortOrder")
      }
    }
    .onChange(of: selectedFile) { _, newValue in
      guard let viewModel else { return }
      if let newValue {
        viewModel.selection = .audioFile(newValue)
      } else if case .audioFile? = viewModel.selection {
        viewModel.selection = nil
      }
    }
  }

  // MARK: - Navigation Header

  private var navigationHeader: some View {
    Group {
      if let viewModel {
        FolderNavigationHeaderView(
          currentFolder: currentFolder,
          canNavigateBack: viewModel.canNavigateBack(navigationPath: navigationPath),
          isRescanningFolder: viewModel.isRescanningFolder,
          sortOrder: viewModel.sortOrder,
          onNavigateBack: {
            viewModel.navigateBack(navigationPath: &navigationPath, currentFolder: &currentFolder)
          },
          onRescan: {
            viewModel.rescanCurrentFolder(currentFolder)
          },
          onSortChange: { viewModel.sortOrder = $0 }
        )
      }
    }
  }

  // MARK: - File List

  private var fileList: some View {
    Group {
      if let viewModel {
        List(selection: listSelection) {
          if !currentFolders.isEmpty {
            Section {
              ForEach(currentFolders) { folder in
                GeometryReader { geometry in
                  folderRow(for: folder)
                    .contentShape(Rectangle())
                    .gesture(
                      pressGesture(
                        for: .folder(folder),
                        rowSize: geometry.size
                      )
                    )
                }
                .frame(height: 60)
                .listRowSeparator(.hidden)
                .listRowInsets(.init())
                .listRowBackground(
                  viewModel.pressing == SelectionItem.folder(folder)
                    ? Color.red.opacity(0.7)
                    : .clear
                )
                .tag(SelectionItem.folder(folder))
              }
            }
          }

          if !currentAudioFiles.isEmpty {
            Section {
              ForEach(currentAudioFiles) { file in
                GeometryReader { geometry in
                  fileRow(for: file)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                      pressGesture(
                        for: .audioFile(file),
                        rowSize: geometry.size
                      )
                    )
                }
                .frame(height: 60)
                .listRowSeparator(.hidden)
                .listRowInsets(.init())
                .onHover {
                  if $0 {
                    viewModel.hovering = SelectionItem.audioFile(file)
                  } else {
                    viewModel.hovering = nil
                  }
                }
                .listRowBackground(audioFileRowBackground(for: file))
                .tag(SelectionItem.audioFile(file))
              }
            }
          }
        }
        .padding(.horizontal, -8)
        .listStyle(.plain)
        .listSectionSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .overlay {
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
    }
  }

  private var listSelection: Binding<SelectionItem?> {
    Binding(
      get: {
        viewModel?.selection
      },
      set: { newSelection in
        guard let newSelection, let viewModel, !isDeselecting else { return }
        viewModel.selection = newSelection
        viewModel.handleSelectionChange(
          newSelection,
          navigationPath: &navigationPath,
          currentFolder: &currentFolder,
          onSelectFile: onSelectFile
        )
      }
    )
  }

  private func audioFileRowBackground(for file: ABFile) -> Color {
    guard let viewModel else { return .clear }

    if viewModel.pressing == .audioFile(file) {
      return Color.asset.listHighlight
    }

    if viewModel.selection == .audioFile(file) {
      return Color.asset.listHighlight
    }

    if viewModel.hovering == .audioFile(file) {
      return Color.asset.listHighlight.opacity(0.6)
    }

    return .clear
  }

  // MARK: - Selection Handling

  private var currentFolders: [Folder] {
    guard let viewModel else { return [] }
    let folders = currentFolder.map { Array($0.subfolders) } ?? rootFolders
    return viewModel.sortedFolders(folders)
  }

  private var currentAudioFiles: [ABFile] {
    guard let viewModel else { return [] }
    let files = currentFolder.map { Array($0.audioFiles) } ?? rootAudioFiles
    return viewModel.sortedAudioFiles(files)
  }

  private func pressGesture(for selection: SelectionItem, rowSize: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
      .onChanged { _ in
        guard let viewModel else { return }
        if selectionBeforePress == nil {
          selectionBeforePress = viewModel.selection
        }
        viewModel.pressing = selection
      }
      .onEnded { value in
        let isInsideRow = CGRect(origin: .zero, size: rowSize).contains(value.location)
        handlePressEnd(for: selection, isInsideRow: isInsideRow)
      }
  }

  private func handlePressEnd(for selection: SelectionItem, isInsideRow: Bool) {
    guard let viewModel else { return }

    viewModel.pressing = nil
    let previousSelection = selectionBeforePress
    selectionBeforePress = nil

    guard isInsideRow else {
      isDeselecting = true
      viewModel.selection = previousSelection
      isDeselecting = false
      return
    }

    viewModel.selection = selection
    viewModel.handleSelectionChange(
      selection,
      navigationPath: &navigationPath,
      currentFolder: &currentFolder,
      onSelectFile: onSelectFile
    )
  }

  // MARK: - Folder Row

  private func folderRow(for folder: Folder) -> some View {
    FolderRowView(
      folder: folder,
      onDelete: {
        guard let viewModel else { return }
        viewModel.deleteFolder(
          folder,
          currentFolder: &currentFolder,
          selectedFile: &selectedFile,
          navigationPath: &navigationPath
        )
      }
    )
  }

  // MARK: - Audio File Row

  private func fileRow(for file: ABFile) -> some View {
    FileRowView(
      file: file,
      isSelected: viewModel?.selection == .audioFile(file),
      onDelete: {
        guard let viewModel else { return }
        viewModel.deleteAudioFile(
          file,
          updateSelection: true,
          checkPlayback: true,
          selectedFile: &selectedFile
        )
      }
    )
  }
}
