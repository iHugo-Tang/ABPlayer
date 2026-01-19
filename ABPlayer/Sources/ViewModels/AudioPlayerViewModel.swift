import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AudioPlayerViewModel {
  // MARK: - Dependencies
  weak var playerManager: AudioPlayerManager?

  // MARK: - UI State
  var isSeeking: Bool = false
  var seekValue: Double = 0
  var wasPlayingBeforeSeek: Bool = false
  var showVolumePopover: Bool = false
  
  // MARK: - Layout State
  var draggingWidth: Double?
  
  // Persisted Layout State
  var playerSectionWidth: Double {
    didSet {
      UserDefaults.standard.set(playerSectionWidth, forKey: "playerSectionWidth")
    }
  }
  
  var showContentPanel: Bool {
    didSet {
      UserDefaults.standard.set(showContentPanel, forKey: "audioPlayerShowContentPanel")
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
  let minWidthOfPlayerSection: CGFloat = 380
  let minWidthOfContentPanel: CGFloat = 300
  let dividerWidth: CGFloat = 8

  // MARK: - Initialization
  init() {
    // Initialize persisted properties
    let storedWidth = UserDefaults.standard.double(forKey: "playerSectionWidth")
    self.playerSectionWidth = storedWidth > 0 ? storedWidth : 380
    
    // For Booleans, check for existence
    if UserDefaults.standard.object(forKey: "audioPlayerShowContentPanel") == nil {
      self.showContentPanel = true
    } else {
      self.showContentPanel = UserDefaults.standard.bool(forKey: "audioPlayerShowContentPanel")
    }
    
    let storedVolume = UserDefaults.standard.double(forKey: "playerVolume")
    if UserDefaults.standard.object(forKey: "playerVolume") == nil {
      self.playerVolume = 1.0
    } else {
      self.playerVolume = storedVolume
    }
  }

  // MARK: - Setup
  func setup(with manager: AudioPlayerManager) {
    self.playerManager = manager
    
    // Restore loop mode
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
  
  func resetVolume() {
    playerVolume = 1.0
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
  }
  
  func seekForward() {
    guard let manager = playerManager else { return }
    let targetTime = manager.currentTime + 10
    manager.seek(to: targetTime)
  }
  
  func timeString(from value: Double) -> String {
    guard value.isFinite, value >= 0 else {
      return "0:00"
    }

    let totalSeconds = Int(value.rounded())
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    
    return String(format: "%d:%02d", minutes, seconds)
  }
}
