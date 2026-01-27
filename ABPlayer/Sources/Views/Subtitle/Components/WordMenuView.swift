import SwiftUI
import AppKit

struct WordMenuView: View {
  let word: String
  let onDismiss: () -> Void
  let onLookup: (String) -> Void
  let onForgot: (String) -> Void
  let onRemembered: (String) -> Void
  let onRemove: (String) -> Void
  let forgotCount: Int
  let rememberedCount: Int
  let createdAt: Date?

  private var canRemember: Bool {
    guard forgotCount > 0, let createdAt = createdAt else { return false }
    return Date().timeIntervalSince(createdAt) >= 12 * 3600
  }

  private var cleanedWord: String {
    word.lowercased().trimmingCharacters(in: .punctuationCharacters)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Group {
        MenuButton(label: "Copy", systemImage: "doc.on.doc") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(cleanedWord, forType: .string)
          onDismiss()
        }

        MenuButton(label: "Look Up" + (forgotCount > 0 ? " (\(forgotCount))" : ""), systemImage: "book") {
          onLookup(cleanedWord)
          onForgot(cleanedWord)
          onDismiss()
        }

//        MenuButton(
//          label: "Forgot" + (forgotCount > 0 ? " (\(forgotCount))" : ""),
//          systemImage: "xmark.circle"
//        ) {
//          onForgot(cleanedWord)
//          onDismiss()
//        }

        if canRemember {
          MenuButton(
            label: "Remember" + (rememberedCount > 0 ? " (\(rememberedCount))" : ""),
            systemImage: "checkmark.circle"
          ) {
            onRemembered(cleanedWord)
            onDismiss()
          }
        }

        if forgotCount > 0 || rememberedCount > 0 {
          MenuButton(label: "Remove", systemImage: "trash") {
            onRemove(cleanedWord)
            onDismiss()
          }
        }
      }
      .padding(4)
    }
    .frame(minWidth: 160)
  }
}

struct MenuButton: View {
  let label: String
  let systemImage: String
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Label(label, systemImage: systemImage)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 4)
        .fill(isHovered ? Color.accentColor : Color.clear)
    )
    .foregroundStyle(isHovered ? .white : .primary)
    .onHover { isHovered = $0 }
  }
}
