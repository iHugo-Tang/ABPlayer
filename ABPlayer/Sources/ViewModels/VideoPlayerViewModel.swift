import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class VideoPlayerViewModel {
  // MARK: - Dependencies
  weak var playerManager: AudioPlayerManager?

  // MARK: - UI State
  var isSeeking: Bool = false
  var seekValue: Double = 0
  var wasPlayingBeforeSeek: Bool = false
  
  // MARK: - HUD
  var hudMessage: String?
  var hideHudTask: Task<Void, Never>?
  var showHudMessage: Bool {
    guard let hudMessage else {
      return false
    }
    return !hudMessage.isEmpty
  }
  
  // MARK: - Layout State
  var draggingWidth: Double?
  
  // Persisted Layout State
  var videoPlayerSectionWidth: Double {
    didSet {
      UserDefaults.standard.set(videoPlayerSectionWidth, forKey: "videoPlayerSectionWidth")
    }
  }
  
  var showContentPanel: Bool {
    didSet {
      UserDefaults.standard.set(showContentPanel, forKey: "videoPlayerShowContentPanel")
    }
  }

  // MARK: - Volume State
  var playerVolume: Double {
    didSet {
      UserDefaults.standard.set(playerVolume, forKey: "playerVolume")
      debounceVolumeUpdate()
    }
  }
  private var volumeDebounceTask: Task<Void, Never>?

  // MARK: - Constants
  let minWidthOfPlayerSection: CGFloat = 480
  let minWidthOfContentPanel: CGFloat = 300
  let dividerWidth: CGFloat = 8

  // MARK: - Initialization
  init() {
    // Initialize persisted properties
    let storedWidth = UserDefaults.standard.double(forKey: "videoPlayerSectionWidth")
    self.videoPlayerSectionWidth = storedWidth > 0 ? storedWidth : 480
    
    // For Booleans, we need to check if key exists to distinguish false from "not set" if default is true
    // Here default is true
    if UserDefaults.standard.object(forKey: "videoPlayerShowContentPanel") == nil {
      self.showContentPanel = true
    } else {
      self.showContentPanel = UserDefaults.standard.bool(forKey: "videoPlayerShowContentPanel")
    }
    
    let storedVolume = UserDefaults.standard.double(forKey: "playerVolume")
    // If not set, double returns 0. If volume is actually 0, that's fine.
    // But we probably want default 1.0 if not set.
    if UserDefaults.standard.object(forKey: "playerVolume") == nil {
      self.playerVolume = 1.0
    } else {
      self.playerVolume = storedVolume
    }
  }

  // MARK: - Setup
  @MainActor
  func setup(with manager: AudioPlayerManager) {
    self.playerManager = manager
    
    // Restore persistence
    if let storedLoopMode = UserDefaults.standard.string(forKey: "playerLoopMode"),
       let mode = LoopMode(rawValue: storedLoopMode) {
      manager.loopMode = mode
    }
    
    // Sync volume
    manager.setVolume(Float(playerVolume))
  }

  // MARK: - Logic
  
  func updateLoopMode(_ mode: LoopMode) {
    playerManager?.loopMode = mode
    UserDefaults.standard.set(mode.rawValue, forKey: "playerLoopMode")
  }
  
  func clampWidth(_ width: Double, availableWidth: CGFloat) -> Double {
    let maxWidth = Double(availableWidth) - dividerWidth - minWidthOfContentPanel
    return min(max(width, minWidthOfPlayerSection), max(maxWidth, minWidthOfPlayerSection))
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
    hudMessage = nil
    
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 10_000_000)
      withAnimation(.bouncy) {
        hudMessage = message
      }
      
      hideHudTask = Task {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if Task.isCancelled {
          return
        }
        withAnimation {
          hudMessage = nil
        }
      }
    }
  }
}
