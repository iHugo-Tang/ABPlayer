import Foundation

enum SortingUtility {
  static func extractLeadingNumber(_ name: String) -> Int {
    let digits = name.prefix(while: { $0.isNumber })
    return Int(digits) ?? Int.max
  }
  
  static func sortFolders(_ folders: [Folder], by sortOrder: SortOrder) -> [Folder] {
    switch sortOrder {
    case .nameAZ:
      return folders.sorted { $0.name < $1.name }
    case .nameZA:
      return folders.sorted { $0.name > $1.name }
    case .numberAsc:
      return folders.sorted { extractLeadingNumber($0.name) < extractLeadingNumber($1.name) }
    case .numberDesc:
      return folders.sorted { extractLeadingNumber($0.name) > extractLeadingNumber($1.name) }
    case .dateCreatedNewestFirst:
      return folders.sorted { $0.createdAt > $1.createdAt }
    case .dateCreatedOldestFirst:
      return folders.sorted { $0.createdAt < $1.createdAt }
    }
  }
  
  static func sortAudioFiles(_ files: [ABFile], by sortOrder: SortOrder) -> [ABFile] {
    switch sortOrder {
    case .nameAZ:
      return files.sorted { $0.displayName < $1.displayName }
    case .nameZA:
      return files.sorted { $0.displayName > $1.displayName }
    case .numberAsc:
      return files.sorted {
        extractLeadingNumber($0.displayName) < extractLeadingNumber($1.displayName)
      }
    case .numberDesc:
      return files.sorted {
        extractLeadingNumber($0.displayName) > extractLeadingNumber($1.displayName)
      }
    case .dateCreatedNewestFirst:
      return files.sorted { $0.createdAt > $1.createdAt }
    case .dateCreatedOldestFirst:
      return files.sorted { $0.createdAt < $1.createdAt }
    }
  }
}
