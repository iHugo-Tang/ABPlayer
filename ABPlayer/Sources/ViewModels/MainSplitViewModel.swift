import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class MainSplitViewModel {
  // MARK: - Media Type
  enum MediaType: String {
    case audio
    case video
  }
  
  // MARK: - Layout State
  var draggingWidth: Double?
  var draggingHeight: Double?
  
  private var currentMediaType: MediaType = .audio
  
  // Persisted Layout State - Horizontal Split
  var playerSectionWidth: Double {
    didSet {
      UserDefaults.standard.set(playerSectionWidth, forKey: userDefaultsKey(for: "PlayerSectionWidth"))
    }
  }
  
  var showContentPanel: Bool {
    didSet {
      UserDefaults.standard.set(showContentPanel, forKey: userDefaultsKey(for: "ShowContentPanel"))
    }
  }
  
  // Persisted Layout State - Vertical Split
  var topPanelHeight: Double {
    didSet {
      UserDefaults.standard.set(topPanelHeight, forKey: userDefaultsKey(for: "TopPanelHeight"))
    }
  }
  
  var showBottomPanel: Bool {
    didSet {
      UserDefaults.standard.set(showBottomPanel, forKey: userDefaultsKey(for: "ShowBottomPanel"))
    }
  }

  // MARK: - Constants
  let minWidthOfPlayerSection: CGFloat = 480
  let minWidthOfContentPanel: CGFloat = 300
  let minHeightOfTopPanel: CGFloat = 200
  let minHeightOfBottomPanel: CGFloat = 150
  let dividerWidth: CGFloat = 8

  // MARK: - Initialization
  init() {
    self.playerSectionWidth = Self.loadWidth(for: .audio)
    self.showContentPanel = Self.loadShowContentPanel(for: .audio)
    self.topPanelHeight = Self.loadHeight(for: .audio)
    self.showBottomPanel = Self.loadShowBottomPanel(for: .audio)
  }

  // MARK: - UserDefaults Key Generation
  private func userDefaultsKey(for suffix: String) -> String {
    "mainSplit\(currentMediaType.rawValue.capitalized)\(suffix)"
  }
  
  private static func userDefaultsKey(for suffix: String, mediaType: MediaType) -> String {
    "mainSplit\(mediaType.rawValue.capitalized)\(suffix)"
  }
  
  // MARK: - Static Loaders
  private static func loadWidth(for mediaType: MediaType) -> Double {
    let key = userDefaultsKey(for: "PlayerSectionWidth", mediaType: mediaType)
    let storedWidth = UserDefaults.standard.double(forKey: key)
    return storedWidth > 0 ? storedWidth : 480
  }
  
  private static func loadShowContentPanel(for mediaType: MediaType) -> Bool {
    let key = userDefaultsKey(for: "ShowContentPanel", mediaType: mediaType)
    if UserDefaults.standard.object(forKey: key) == nil {
      return true
    }
    return UserDefaults.standard.bool(forKey: key)
  }
  
  private static func loadHeight(for mediaType: MediaType) -> Double {
    let key = userDefaultsKey(for: "TopPanelHeight", mediaType: mediaType)
    let storedHeight = UserDefaults.standard.double(forKey: key)
    return storedHeight > 0 ? storedHeight : 400
  }
  
  private static func loadShowBottomPanel(for mediaType: MediaType) -> Bool {
    let key = userDefaultsKey(for: "ShowBottomPanel", mediaType: mediaType)
    if UserDefaults.standard.object(forKey: key) == nil {
      return true
    }
    return UserDefaults.standard.bool(forKey: key)
  }
  
  // MARK: - Media Type Switching
  func switchMediaType(to mediaType: MediaType) {
    guard currentMediaType != mediaType else { return }
    
    currentMediaType = mediaType
    
    playerSectionWidth = Self.loadWidth(for: mediaType)
    showContentPanel = Self.loadShowContentPanel(for: mediaType)
    topPanelHeight = Self.loadHeight(for: mediaType)
    showBottomPanel = Self.loadShowBottomPanel(for: mediaType)
  }

  // MARK: - Logic
  
  func clampWidth(_ width: Double, availableWidth: CGFloat) -> Double {
    let maxWidth = Double(availableWidth) - dividerWidth - minWidthOfContentPanel
    return min(max(width, minWidthOfPlayerSection), max(maxWidth, minWidthOfPlayerSection))
  }
  
  func clampHeight(_ height: Double, availableHeight: CGFloat) -> Double {
    let maxHeight = Double(availableHeight) - dividerWidth - minHeightOfBottomPanel
    return min(max(height, minHeightOfTopPanel), max(maxHeight, minHeightOfTopPanel))
  }
}
