import OSLog
import SwiftData
import SwiftUI

struct SubtitleView: View {
  @Environment(PlayerManager.self) private var playerManager
  @Environment(VocabularyService.self) private var vocabularyService

  let cues: [SubtitleCue]
  @Binding var countdownSeconds: Int?
  let fontSize: Double

  @State private var viewModel = SubtitleViewModel()

  var body: some View {
    ZStack(alignment: .topTrailing) {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(cues) { cue in
              SubtitleCueRow(
                cue: cue,
                isActive: cue.id == viewModel.currentCueID,
                isScrolling: viewModel.scrollState.isUserScrolling,
                fontSize: fontSize,
                selectedWordIndex: viewModel.wordSelection.selectedWord?.cueID == cue.id 
                  ? viewModel.wordSelection.selectedWord?.wordIndex 
                  : nil,
                onWordSelected: { wordIndex in
                  viewModel.handleWordSelection(
                    wordIndex: wordIndex,
                    cueID: cue.id,
                    isPlaying: playerManager.isPlaying,
                    onPause: { playerManager.pause() }
                  )
                },
                onHidePopover: {
                  viewModel.hidePopover()
                },
                onTap: {
                  viewModel.handleCueTap(
                    cueID: cue.id,
                    onSeek: { playerManager.seek(to: $0) },
                    cueStartTime: cue.startTime
                  )
                }
              )
              .id(cue.id)
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
        }
        .transaction { $0.animation = nil }
        .onScrollPhaseChange { _, newPhase in
          handleScrollPhaseChange(newPhase)
        }
        .onChange(of: viewModel.currentCueID) { _, newValue in
          guard !viewModel.scrollState.isUserScrolling, let id = newValue else { return }
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
        .onChange(of: viewModel.tappedCueID) { _, newValue in
          guard let id = newValue else { return }
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
        .onChange(of: cues) { _, _ in
          viewModel.reset()
          countdownSeconds = nil
        }
      }

      VStack(alignment: .trailing, spacing: 8) {
        if let countdown = viewModel.scrollState.countdown {
          CountdownRingView(countdown: countdown, total: 3)
            .transition(.scale.combined(with: .opacity))
        }
      }
      .padding(12)
    }
    .animation(.easeInOut(duration: 0.2), value: viewModel.scrollState.countdown != nil)
    .task {
      await viewModel.trackPlayback(
        timeProvider: { @MainActor in playerManager.currentTime },
        cues: cues
      )
    }
    .onChange(of: viewModel.scrollState.countdown) { _, newValue in
      countdownSeconds = newValue
    }
  }

  private func handleScrollPhaseChange(_ phase: ScrollPhase) {
    guard case .interacting = phase else { return }
    viewModel.handleUserScroll()
  }
}

struct SubtitleEmptyView: View {
  var body: some View {
    ContentUnavailableView(
      "No Subtitles",
      systemImage: "text.bubble",
      description: Text("This audio file has no associated subtitle file")
    )
  }
}
