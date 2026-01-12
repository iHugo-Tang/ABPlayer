import SwiftUI

// MARK: - Audio File Row

struct FileRowView: View {
  let file: AudioFile
  let isSelected: Bool
  let onDelete: () -> Void
  
  var body: some View {
    let isAvailable = file.isBookmarkValid
    
    return ZStack(alignment: .leading) {
      if isSelected {
        Color.asset.accent.frame(width: 3)
      }
      HStack(spacing: 12) {
        if isAvailable {
          Image(systemName: "movieclapper.fill")
            .foregroundStyle(file.isPlaybackComplete ? Color.secondary : Color.blue)
        } else {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
        }
        
        VStack(alignment: .leading) {
          Text(file.displayName)
            .lineLimit(1)
            .strikethrough(!isAvailable, color: .secondary)
            .foregroundStyle(isSelected ? Color(nsColor: .labelColor) : (isAvailable ? .primary : .secondary))
            .bodyStyle()
          
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
      .padding(.horizontal, 16)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(maxHeight: .infinity, alignment: .center)
    .contentShape(Rectangle())
    .contextMenu {
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("Delete File", systemImage: "trash")
      }
    }
  }
}
