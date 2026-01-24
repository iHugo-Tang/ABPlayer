import Foundation
import SwiftUI

@MainActor
@Observable
final class SelectionStateService {
  private enum UserDefaultsKey {
    static let lastSelectedAudioFileID = "lastSelectedAudioFileID"
    static let lastFolderID = "lastFolderID"
    static let lastSelectionItemID = "lastSelectionItemID"
  }
  
  var selectedFile: ABFile?
  var selection: SelectionItem? {
    didSet {
      handleSelectionChange(from: oldValue, to: selection)
    }
  }
  
  var lastSelectedAudioFileID: String? {
    get { UserDefaults.standard.string(forKey: UserDefaultsKey.lastSelectedAudioFileID) }
    set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.lastSelectedAudioFileID) }
  }
  
  var lastFolderID: String? {
    get { UserDefaults.standard.string(forKey: UserDefaultsKey.lastFolderID) }
    set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.lastFolderID) }
  }
  
  var lastSelectionItemID: String? {
    get { UserDefaults.standard.string(forKey: UserDefaultsKey.lastSelectionItemID) }
    set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.lastSelectionItemID) }
  }
  
  private func handleSelectionChange(from oldValue: SelectionItem?, to newValue: SelectionItem?) {
    guard let newValue else {
      lastSelectionItemID = nil
      return
    }
    
    switch newValue {
    case .folder(let folder):
      lastSelectionItemID = folder.id.uuidString
    case .audioFile(let file):
      selectedFile = file
      lastSelectedAudioFileID = file.id.uuidString
      lastFolderID = file.folder?.id.uuidString
      lastSelectionItemID = file.id.uuidString
    case .empty:
      lastSelectionItemID = nil
    }
  }
  
  func clearSelection() {
    selectedFile = nil
    lastSelectedAudioFileID = nil
    lastFolderID = nil
    lastSelectionItemID = nil
    selection = nil
  }
}
