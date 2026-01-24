import OSLog
import SwiftData
import SwiftUI
import Observation

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
  init(
    viewModel: FolderNavigationViewModel,
    onSelectFile: @escaping (ABFile) async -> Void
  ) {
    self.viewModel = viewModel
    self.onSelectFile = onSelectFile
  }
  @Environment(\.modelContext) private var modelContext
  @Environment(PlayerManager.self) private var playerManager
  @Environment(LibrarySettings.self) private var librarySettings

  @Query(filter: #Predicate<Folder> { $0.parent == nil }, sort: \Folder.name)
  private var rootFolders: [Folder]

  @Query(filter: #Predicate<ABFile> { $0.folder == nil }, sort: \ABFile.createdAt)
  private var rootAudioFiles: [ABFile]

  @Bindable var viewModel: FolderNavigationViewModel

  @State private var isDeselecting = false
  @State private var selectionBeforePress: SelectionItem?

  @State private var deleteTarget: SelectionItem?
  @State private var showDeleteConfirmation = false

  let onSelectFile: (ABFile) async -> Void

  var body: some View {
    VStack(spacing: 0) {
      navigationHeader
      fileList
    }
    .onAppear {
      if let savedSortOrder = UserDefaults.standard.string(forKey: "folderNavigationSortOrder"),
         let sortOrder = SortOrder(rawValue: savedSortOrder) {
        viewModel.sortOrder = sortOrder
      }

      if let selectedFile = viewModel.selectedFile {
        viewModel.selection = .audioFile(selectedFile)
      } else if let lastSelectionItemID = viewModel.lastSelectionItemID {
        if let folderID = UUID(uuidString: lastSelectionItemID),
           let folder = rootFolders.first(where: { $0.id == folderID }) {
          viewModel.selection = .folder(folder)
        } else if let fileID = UUID(uuidString: lastSelectionItemID),
                  let file = (rootAudioFiles + rootFolders.flatMap { $0.audioFiles }).first(where: { $0.id == fileID }) {
          viewModel.selection = .audioFile(file)
        }
      }
    }
    .confirmationDialog(
        deleteConfirmationTitle,
        isPresented: $showDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Move to Trash", role: .destructive) {
          performDeleteConfirmation(deleteFromDisk: true)
        }
        Button("Remove from Library") {
          performDeleteConfirmation(deleteFromDisk: false)
        }
        Button("Cancel", role: .cancel) {
          deleteTarget = nil
          showDeleteConfirmation = false
        }
      } message: {
        Text(deleteConfirmationMessage)
      }
      .onChange(of: viewModel.sortOrder) { _, newValue in
        UserDefaults.standard.set(newValue.rawValue, forKey: "folderNavigationSortOrder")
      }
      .onChange(of: viewModel.selectedFile) { _, newValue in
        if let newValue {
          viewModel.selection = .audioFile(newValue)
        } else if case .audioFile? = viewModel.selection {
          viewModel.selection = nil
        }
      }

  }

  // MARK: - Navigation Header

  private var navigationHeader: some View {
    FolderNavigationHeaderView(
      currentFolder: viewModel.currentFolder,
      canNavigateBack: viewModel.canNavigateBack(),
      sortOrder: viewModel.sortOrder,
      onNavigateBack: {
        viewModel.navigateBack()
      },
      onSortChange: { viewModel.sortOrder = $0 }
    )
  }

  // MARK: - File List

  private var fileList: some View {
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
              ? Color.asset.listHighlight
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
    .onDeleteCommand {
      handleDeleteCommand()
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

  private var listSelection: Binding<SelectionItem?> {
    Binding(
      get: {
        viewModel.selection
      },
      set: { newSelection in
        guard let newSelection, !isDeselecting else { return }
        viewModel.selection = newSelection
        viewModel.handleSelectionChange(
          newSelection,
          onSelectFile: onSelectFile
        )
      }
    )
  }

  private func audioFileRowBackground(for file: ABFile) -> Color {
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
    let folders = viewModel.currentFolder.map { Array($0.subfolders) } ?? rootFolders
    return viewModel.sortedFolders(folders)
  }

  private var currentAudioFiles: [ABFile] {
    let files = viewModel.currentFolder.map { Array($0.audioFiles) } ?? rootAudioFiles
    return viewModel.sortedAudioFiles(files)
  }

  private func pressGesture(for selection: SelectionItem, rowSize: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
      .onChanged { _ in
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
      onSelectFile: onSelectFile
    )
  }

  // MARK: - Folder Row

  private func folderRow(for folder: Folder) -> some View {
    FolderRowView(
      folder: folder,
      onDelete: {
        deleteTarget = .folder(folder)
        showDeleteConfirmation = true
      }
    )
  }

  // MARK: - Audio File Row

  private func fileRow(for file: ABFile) -> some View {
    FileRowView(
      file: file,
      isSelected: viewModel.selection == .audioFile(file),
      isFailed: file.loadError != nil,
      onDelete: {
        deleteTarget = .audioFile(file)
        showDeleteConfirmation = true
      }
    )
  }

  private var deleteConfirmationTitle: String {
    switch deleteTarget {
    case .folder:
      return "Delete Folder?"
    case .audioFile:
      return "Delete File?"
    case .empty, .none:
      return "Delete?"
    }
  }

  private var deleteConfirmationMessage: String {
    switch deleteTarget {
    case .folder:
      return "Do you want to move the folder and its contents to the Trash or just remove them from the library?"
    case .audioFile:
      return "Do you want to move the file to the Trash or just remove it from the library?"
    default:
      return "This action cannot be undone."
    }
  }

  private func performDeleteConfirmation(deleteFromDisk: Bool) {
    switch deleteTarget {
    case .folder(let folder):
      viewModel.deleteFolder(
        folder,
        deleteFromDisk: deleteFromDisk
      )
    case .audioFile(let file):
      var selectedFile = viewModel.selectedFile
      viewModel.deleteAudioFile(
        file,
        deleteFromDisk: deleteFromDisk,
        updateSelection: true,
        checkPlayback: true,
        selectedFile: &selectedFile
      )
      viewModel.selectedFile = selectedFile
    case .empty, .none:
      break
    }

    deleteTarget = nil
    showDeleteConfirmation = false
  }

  private func handleDeleteCommand() {
    guard let selection = viewModel.selection else { return }

    switch selection {
    case .folder(let folder):
      viewModel.deleteFolder(
        folder,
        deleteFromDisk: false
      )
    case .audioFile(let file):
      var selectedFile = viewModel.selectedFile
      viewModel.deleteAudioFile(
        file,
        deleteFromDisk: false,
        updateSelection: true,
        checkPlayback: true,
        selectedFile: &selectedFile
      )
      viewModel.selectedFile = selectedFile
    case .empty:
      break
    }
  }
}
