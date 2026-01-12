import SwiftUI

/// Represents the different content panels available (transcription and PDF)
enum ContentPanelTab: String, CaseIterable, Identifiable {
  case transcription = "Transcription"
  case pdf = "PDF"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .transcription: return "text.bubble"
    case .pdf: return "doc.text"
    }
  }
}

/// Tab-based content panel showing subtitles or PDF (sidebar only)
struct ContentPanelView: View {
  let audioFile: ABFile

  @State private var selectedTab: ContentPanelTab = .transcription

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
    // comment it when show in a vertical window; uncomment it when show in a wide window.
    // .background(.bar)
  }

  private func tabButton(for tab: ContentPanelTab) -> some View {
    Button {
      withAnimation(.easeInOut(duration: 0.15)) {
        selectedTab = tab
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: tab.icon)
        Text(tab.rawValue)
      }
      .font(.title3)
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
    ZStack {
      switch selectedTab {
      case .transcription:
        TranscriptionView(audioFile: audioFile)

      case .pdf:
        pdfContent
      }
    }
    .frame(maxHeight: .infinity)
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
