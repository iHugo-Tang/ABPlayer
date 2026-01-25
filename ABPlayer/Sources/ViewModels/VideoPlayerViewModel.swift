import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class VideoPlayerViewModel {
  // MARK: - Dependencies
  weak var playerManager: PlayerManager?

  // MARK: - UI State
  var isSeeking: Bool = false
  var seekValue: Double = 0
  var wasPlayingBeforeSeek: Bool = false
  
  // MARK: - HUD
  var hudMessage: String?
  var isHudVisible: Bool = false
  var hideHudTask: Task<Void, Never>?

  // MARK: - Volume State
  var playerVolume: Double {
    didSet {
      UserDefaults.standard.set(playerVolume, forKey: "playerVolume")
      debounceVolumeUpdate()
    }
  }
  private var volumeDebounceTask: Task<Void, Never>?

  // MARK: - Initialization
  init() {
    let storedVolume = UserDefaults.standard.double(forKey: "playerVolume")
    if UserDefaults.standard.object(forKey: "playerVolume") == nil {
      self.playerVolume = 1.0
    } else {
      self.playerVolume = storedVolume
    }
  }

  // MARK: - Setup
  @MainActor
  func setup(with manager: PlayerManager) {
    self.playerManager = manager
    
    // Restore persistence
    if let storedLoopMode = UserDefaults.standard.string(forKey: "playerLoopMode"),
       let mode = PlaybackQueue.LoopMode(rawValue: storedLoopMode) {
      manager.loopMode = mode
    }
    
    // Sync volume
    manager.setVolume(Float(playerVolume))
  }

  // MARK: - Logic
  
  func updateLoopMode(_ mode: PlaybackQueue.LoopMode) {
    playerManager?.loopMode = mode
    UserDefaults.standard.set(mode.rawValue, forKey: "playerLoopMode")
  }
  
  private func debounceVolumeUpdate() {
    volumeDebounceTask?.cancel()
    volumeDebounceTask = Task {
      try? await Task.sleep(for: .milliseconds(100))
      guard !Task.isCancelled else { return }
      await MainActor.run {
        playerManager?.setVolume(Float(playerVolume))
      }
    }
  }
  
  func togglePlayPause() {
    playerManager?.togglePlayPause()
  }
  
  func seekBack() {
    guard let manager = playerManager else { return }
    let targetTime = manager.currentTime - 5
    manager.seek(to: targetTime)
    showHUDMessage("- 5")
  }
  
  func seekForward() {
    guard let manager = playerManager else { return }
    let targetTime = manager.currentTime + 10
    manager.seek(to: targetTime)
    showHUDMessage("+ 10s")
  }
  
  func timeString(from value: Double) -> String {
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

  func showHUDMessage(_ message: String) {
    hideHudTask?.cancel()
    
    hudMessage = message
    isHudVisible = false
    
    hideHudTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 10_000_000)
      guard !Task.isCancelled else { return }

      withAnimation(.bouncy(duration: 0.25)) {
        isHudVisible = true
      }
      
      try? await Task.sleep(nanoseconds: 2_500_000_000)
      guard !Task.isCancelled else { return }
      
      withAnimation(.bouncy(duration: 0.25)) {
        isHudVisible = false
      }
      
      try? await Task.sleep(nanoseconds: 250_000_000)
      guard !Task.isCancelled else { return }
      
      hudMessage = nil
    }
  }
}
