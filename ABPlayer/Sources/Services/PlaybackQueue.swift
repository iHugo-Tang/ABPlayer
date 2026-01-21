import AVFoundation

@MainActor
@Observable
public final class PlaybackQueue {
  enum PlaybackDirection {
    case next
    case previous
  }
  
  enum LoopMode: String, CaseIterable {
    case none
    case repeatOne
    case repeatAll
    case shuffle
    case autoPlayNext
    
    var displayName: String {
      switch self {
        case .none: "Off"
        case .repeatOne: "Repeat One"
        case .repeatAll: "Repeat All"
        case .shuffle: "Shuffle"
        case .autoPlayNext: "Auto Play Next"
      }
    }
    
    var iconName: String {
      switch self {
        case .none: "repeat"
        case .repeatOne: "repeat.1"
        case .repeatAll: "repeat"
        case .shuffle: "shuffle"
        case .autoPlayNext: "arrow.forward.to.line"
      }
    }
  }
  
  var loopMode: LoopMode = .none
  
  private var files: [ABFile] = []
  private var currentFileID: UUID?
  
  init() {}
  
  func updateQueue(_ files: [ABFile]) {
    self.files = files
    
    if let currentFileID,
       !files.contains(where: { $0.id == currentFileID }) {
      self.currentFileID = nil
    }
  }
  
  func setCurrentFile(_ file: ABFile?) {
    currentFileID = file?.id
  }
  
  @discardableResult
  func playNext() -> ABFile? {
    let nextFile = nextFile()
    if let nextFile {
      currentFileID = nextFile.id
    }
    return nextFile
  }
  
  @discardableResult
  func playPrev() -> ABFile? {
    let previousFile = previousFile()
    if let previousFile {
      currentFileID = previousFile.id
    }
    return previousFile
  }
  
  private func nextFile() -> ABFile? {
    nextFile(direction: .next)
  }
  
  private func previousFile() -> ABFile? {
    nextFile(direction: .previous)
  }
  
  private func nextFile(direction: PlaybackDirection) -> ABFile? {
    guard !files.isEmpty else { return nil }
    
    switch loopMode {
      case .none, .repeatOne:
        return nil
        
      case .repeatAll:
        if let index = currentIndex() {
          let nextIndex = direction == .next
          ? (index + 1) % files.count
          : (index - 1 + files.count) % files.count
          return files[nextIndex]
        }
        return files.first
        
      case .shuffle:
        if files.count == 1 {
          return files.first
        }
        
        if let currentFileID {
          var randomFile: ABFile
          repeat {
            randomFile = files.randomElement()!
          } while randomFile.id == currentFileID
          return randomFile
        }
        
        return files.randomElement()
        
      case .autoPlayNext:
        guard let index = currentIndex() else { return nil }
        let nextIndex = direction == .next
        ? (index + 1) % files.count
        : (index - 1 + files.count) % files.count
        return files[nextIndex]
    }
  }
  
  private func currentIndex() -> Int? {
    guard let currentFileID else { return nil }
    return files.firstIndex(where: { $0.id == currentFileID })
  }
}
