import SwiftUI

// MARK: - Audio File Row

struct FileRowView: View {
  let file: ABFile
  let isSelected: Bool
  var isFailed: Bool = false
  let onDelete: () -> Void

  private var isAvailable: Bool {
    file.isBookmarkValid && !isFailed
  }
  private var hasPlayed: Bool {
    file.currentPlaybackPosition > 0
  }

  var body: some View {
    ZStack(alignment: .leading) {
      Color.asset.appAccent
        .frame(width: 3)
        .scaleEffect(y: isSelected ? 1 : 0, anchor: .center)
        .opacity(isSelected ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
      HStack(spacing: 12) {
        if isAvailable {
          Image(systemName: file.fileType.iconName)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        } else {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(file.isBookmarkValid ? .red : .orange)
        }
        
        VStack(alignment: .leading) {
          Text(file.displayName)
            .lineLimit(1)
            .strikethrough(!isAvailable, color: .secondary)
            .bodyStyle()
          
          HStack(spacing: 4) {
            if !file.isBookmarkValid {
              Text("文件不可用")
                .foregroundStyle(.orange)
            } else if isFailed {
               Text("无法播放")
                .foregroundStyle(.red)
            } else if let duration = file.cachedDuration, duration > 0 {
              Text(timeString(from: duration))
              if !hasPlayed {
                Circle().frame(width: 6)
              }
            }
          }
          .captionStyle()
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

  private func timeString(from value: Double) -> String {
    guard value.isFinite, value >= 0 else {
      return "0:00"
    }

    let totalSeconds = Int(value.rounded())
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60

    if minutes >= 60 {
      let hours = minutes / 60
      let remainingMinutes = minutes % 60
      return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
    }

    return String(format: "%d:%02d", minutes, seconds)
  }
}
