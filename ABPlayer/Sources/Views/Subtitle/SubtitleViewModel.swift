import Foundation
import OSLog
import SwiftUI

@Observable
class SubtitleViewModel {
  private static let logger = Logger(subsystem: "com.abplayer", category: "SubtitleViewModel")
  enum ScrollState: Equatable {
    case autoScrolling
    case userScrolling(countdown: Int)
    
    var isUserScrolling: Bool {
      if case .userScrolling = self { return true }
      return false
    }
    
    var countdown: Int? {
      if case .userScrolling(let value) = self { return value }
      return nil
    }
  }
  
  enum WordSelectionState: Equatable {
    case none
    case selected(cueID: UUID, wordIndex: Int)
    
    var selectedWord: (cueID: UUID, wordIndex: Int)? {
      if case .selected(let cueID, let wordIndex) = self {
        return (cueID, wordIndex)
      }
      return nil
    }
  }
  
  private(set) var currentCueID: UUID?
  private(set) var scrollState: ScrollState = .autoScrolling
  private(set) var wordSelection: WordSelectionState = .none
  private(set) var tappedCueID: UUID?
  
  private var wasPlayingBeforeSelection = false
  private var scrollResumeTask: Task<Void, Never>?
  private static let pauseDuration = 3
  
  @MainActor
  func handleUserScroll() {
    scrollResumeTask?.cancel()
    scrollState = .userScrolling(countdown: Self.pauseDuration)
    
    scrollResumeTask = Task { @MainActor in
      do {
        for await remaining in countdown(from: Self.pauseDuration) {
          guard !Task.isCancelled else {
            Self.logger.debug("Countdown task cancelled")
            return
          }
          scrollState = remaining > 0 ? .userScrolling(countdown: remaining) : .autoScrolling
        }
        scrollState = .autoScrolling
        Self.logger.debug("Countdown completed, resumed auto-scrolling")
      } catch {
        Self.logger.error("Countdown error: \(error.localizedDescription)")
        scrollState = .autoScrolling
      }
    }
  }
  
  private func countdown(from seconds: Int) -> AsyncStream<Int> {
    AsyncStream { continuation in
      Task {
        for i in (0..<seconds).reversed() {
          continuation.yield(i)
          do {
            try await Task.sleep(for: .seconds(1))
          } catch {
            Self.logger.debug("Countdown sleep interrupted: \(error.localizedDescription)")
            continuation.finish()
            return
          }
        }
        continuation.finish()
      }
    }
  }
  
  func cancelScrollResume() {
    scrollResumeTask?.cancel()
    scrollResumeTask = nil
    scrollState = .autoScrolling
  }
  
  func handleWordSelection(wordIndex: Int?, cueID: UUID, isPlaying: Bool, onPause: () -> Void) {
    if let wordIndex {
      assert(wordIndex >= 0, "Word index must be non-negative")
      
      if wordSelection == .none {
        wasPlayingBeforeSelection = isPlaying
        if isPlaying {
          onPause()
        }
      }
      wordSelection = .selected(cueID: cueID, wordIndex: wordIndex)
      Self.logger.debug("Selected word at index \(wordIndex) in cue \(cueID)")
    } else {
      dismissWord(onPlay: onPause)
    }
  }
  
  func hidePopover() {
    wordSelection = .none
  }
  
  func dismissWord(onPlay: () -> Void) {
    guard wordSelection != .none else { return }
    wordSelection = .none
    if wasPlayingBeforeSelection {
      onPlay()
      wasPlayingBeforeSelection = false
    }
  }
  
  func handleCueTap(cueID: UUID, onSeek: (Double) -> Void, cueStartTime: Double) {
    assert(cueStartTime >= 0, "Cue start time must be non-negative")
    assert(cueStartTime.isFinite, "Cue start time must be finite")
    
    tappedCueID = cueID
    onSeek(cueStartTime)
    cancelScrollResume()
    Self.logger.debug("Tapped cue at time \(cueStartTime)")
  }
  
  func updateCurrentCue(time: Double, cues: [SubtitleCue]) {
    assert(time >= 0, "Time must be non-negative")
    assert(time.isFinite, "Time must be finite")
    
    guard !scrollState.isUserScrolling else { return }
    let activeCue = findActiveCue(at: time, in: cues)
    if activeCue?.id != currentCueID {
      currentCueID = activeCue?.id
    }
  }
  
  func reset() {
    scrollResumeTask?.cancel()
    scrollResumeTask = nil
    scrollState = .autoScrolling
    currentCueID = nil
    wordSelection = .none
  }
  
  @MainActor
  func trackPlayback(timeProvider: @escaping @MainActor () -> Double, cues: [SubtitleCue]) async {
    let epsilon: Double = 0.001
    
    guard !cues.isEmpty else {
      Self.logger.warning("trackPlayback called with empty cues array")
      return
    }
    
    Self.logger.debug("Started tracking playback for \(cues.count) cues")
    
    while !Task.isCancelled {
      if !scrollState.isUserScrolling {
        let currentTime = timeProvider()
        
        guard currentTime.isFinite && currentTime >= 0 else {
          Self.logger.error("Invalid time from provider: \(currentTime)")
          continue
        }
        
        let activeCue = findActiveCue(at: currentTime, in: cues, epsilon: epsilon)
        
        if activeCue?.id != currentCueID {
          currentCueID = activeCue?.id
          if let cue = activeCue {
            Self.logger.debug("Active cue changed: \(cue.text.prefix(30))...")
          }
        }
      }
      
      do {
        try await Task.sleep(for: .milliseconds(100))
      } catch {
        Self.logger.debug("Playback tracking cancelled: \(error.localizedDescription)")
        break
      }
    }
    
    Self.logger.debug("Stopped tracking playback")
  }
  
  private func findActiveCue(at time: Double, in cues: [SubtitleCue], epsilon: Double = 0.001) -> SubtitleCue? {
    assert(epsilon > 0, "Epsilon must be positive")
    assert(time.isFinite, "Time must be finite")
    
    guard !cues.isEmpty else { return nil }
    
    var low = 0
    var high = cues.count - 1
    var result: Int? = nil
    
    while low <= high {
      let mid = (low + high) / 2
      if cues[mid].startTime <= time + epsilon {
        result = mid
        low = mid + 1
      } else {
        high = mid - 1
      }
    }
    
    if let index = result {
      assert(index >= 0 && index < cues.count, "Binary search produced invalid index")
      let cue = cues[index]
      if time >= cue.startTime - epsilon && time < cue.endTime {
        return cue
      }
    }
    
    return nil
  }
}
