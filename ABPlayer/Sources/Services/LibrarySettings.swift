import Foundation
import SwiftUI
import Observation

/// User configurable library settings
@MainActor
@Observable
public final class LibrarySettings {
  public init() {}
  /// Path to the media library
  @ObservationIgnored
  @AppStorage("library_path") public var libraryPath: String = ""

  /// Returns the library directory URL (user-specified or default)
  public var libraryDirectoryURL: URL {
    if libraryPath.isEmpty {
      return LibrarySettings.defaultLibraryDirectory
    }
    return URL(fileURLWithPath: libraryPath)
  }

  public static var defaultLibraryDirectory: URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    let baseURL = appSupport.first ?? FileManager.default.homeDirectoryForCurrentUser
    let folderName = Bundle.main.bundleIdentifier ?? "ABPlayer"
    return baseURL
      .appendingPathComponent(folderName, isDirectory: true)
      .appendingPathComponent("Library", isDirectory: true)
  }

  public func ensureLibraryDirectoryExists() throws {
    let fileManager = FileManager.default
    let url = libraryDirectoryURL

    if !fileManager.fileExists(atPath: url.path) {
      try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
  }
}
