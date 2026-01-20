import SwiftUI

// MARK: - Folder Navigation Header

struct FolderNavigationHeaderView: View {
  let currentFolder: Folder?
  let canNavigateBack: Bool
  let isRescanningFolder: Bool
  let sortOrder: SortOrder
  
  let onNavigateBack: () -> Void
  let onRescan: () -> Void
  let onSortChange: (SortOrder) -> Void
  
  var body: some View {
    HStack {
      if canNavigateBack {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            onNavigateBack()
          }
        } label: {
          HStack(spacing: 4) {
            Label(" ", systemImage: "chevron.left")
              .font(.title2)
              .labelStyle(.titleAndIcon)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      
      Spacer()

      HStack {
        Image(systemName: "folder.fill")
          .foregroundStyle(.secondary)
        Text(currentFolder?.name ?? "Liberary")
      }

      Spacer()

      if isRescanningFolder {
        ProgressView()
          .controlSize(.small)
      } else if currentFolder != nil {
        Button {
          onRescan()
        } label: {
          Label("Rescan", systemImage: "arrow.2.circlepath")
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .disabled(isRescanningFolder)
      }

      Menu {
        ForEach(SortOrder.allCases, id: \.self) { order in
          Button {
            onSortChange(order)
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
    .frame(height: 44)
    .padding(.horizontal, 16)
    .background(Color.asset.bgTertiary)
  }
}
