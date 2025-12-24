import SwiftUI

/// Represents the different content panels available (subtitles and PDF only)
enum ContentPanelTab: String, CaseIterable, Identifiable {
  case subtitles = "Subtitles"
  case pdf = "PDF"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .subtitles: return "text.bubble"
    case .pdf: return "doc.text"
    }
  }
}

/// Tab-based content panel showing subtitles or PDF (sidebar only)
struct ContentPanelView: View {
  let audioFile: AudioFile

  @State private var selectedTab: ContentPanelTab = .subtitles

  var body: some View {
    VStack(spacing: 0) {
      tabBar
      Divider()
      tabContent
    }
  }

  // MARK: - Tab Bar

  private var tabBar: some View {
    HStack(spacing: 0) {
      ForEach(ContentPanelTab.allCases) { tab in
        tabButton(for: tab)
      }
      Spacer()
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(.bar)
  }

  private func tabButton(for tab: ContentPanelTab) -> some View {
    Button {
      withAnimation(.easeInOut(duration: 0.15)) {
        selectedTab = tab
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: tab.icon)
          .font(.caption)
        Text(tab.rawValue)
          .font(.caption)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
      )
      .foregroundStyle(selectedTab == tab ? .primary : .secondary)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Tab Content

  @ViewBuilder
  private var tabContent: some View {
    switch selectedTab {
    case .subtitles:
      subtitlesContent

    case .pdf:
      pdfContent
    }
  }

  @ViewBuilder
  private var subtitlesContent: some View {
    if let subtitleFile = audioFile.subtitleFile {
      SubtitleView(cues: subtitleFile.cues)
    } else {
      SubtitleEmptyView()
    }
  }

  @ViewBuilder
  private var pdfContent: some View {
    #if os(macOS)
      if let pdfData = audioFile.pdfBookmarkData {
        PDFContentView(pdfBookmarkData: pdfData)
      } else {
        PDFEmptyView()
      }
    #else
      ContentUnavailableView(
        "PDF Not Available",
        systemImage: "doc.text",
        description: Text("PDF viewing is only available on macOS")
      )
    #endif
  }
}
