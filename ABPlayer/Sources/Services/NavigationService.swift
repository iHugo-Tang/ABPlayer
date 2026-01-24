import Foundation
import SwiftUI

@MainActor
@Observable
final class NavigationService {
  var currentFolder: Folder?
  var navigationPath: [Folder] = []
  
  func navigateInto(_ folder: Folder) {
    navigationPath.append(folder)
    currentFolder = folder
  }
  
  func navigateBack() {
    guard !navigationPath.isEmpty else { return }
    navigationPath.removeLast()
    currentFolder = navigationPath.last
  }
  
  func canNavigateBack() -> Bool {
    !navigationPath.isEmpty
  }
}
