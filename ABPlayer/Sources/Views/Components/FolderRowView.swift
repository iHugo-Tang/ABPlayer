import SwiftUI

// MARK: - Folder Row

struct FolderRowView: View {
  let folder: Folder
  let onDelete: () -> Void
  
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "folder.fill")
        .foregroundStyle(.secondary)

      VStack(alignment: .leading) {
        Text(folder.name)
          .lineLimit(1)
          .bodyStyle()

        let count = folder.audioFiles.count + folder.subfolders.count
        Text("\(count) items")
          .captionStyle()
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundStyle(.tertiary)
        .font(.caption)
    }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(maxHeight: .infinity, alignment: .center)
    .contentShape(Rectangle())
    .contextMenu {
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("Delete Folder", systemImage: "trash")
      }
    }
  }
}
