import KeyboardShortcuts
import Sentry
import SwiftData
import SwiftUI

@main
struct ABPlayerApp: App {
  private let modelContainer: ModelContainer
  private let playerManager = AudioPlayerManager()
  private let sessionTracker = SessionTracker()
  private let transcriptionManager = TranscriptionManager()
  private let transcriptionSettings = TranscriptionSettings()

  init() {
    do {
      SentrySDK.start { (options: Sentry.Options) in
        options.dsn =
          "https://0e00826ef2b3fbc195fb428a468fd995@o4504292283580416.ingest.us.sentry.io/4510502660341760"
        options.debug = true  // Enabling debug when first installing is always helpful
        options.sendDefaultPii = true
      }

      modelContainer = try ModelContainer(
        for: AudioFile.self,
        LoopSegment.self,
        ListeningSession.self,
        Folder.self,
        SubtitleFile.self,
        Transcription.self
      )
      modelContainer.mainContext.autosaveEnabled = true

      // Register Shortcut Listeners
      KeyboardShortcuts.onKeyUp(for: .playPause) { [playerManager] in
        Task { @MainActor in
          playerManager.togglePlayPause()
        }
      }

      KeyboardShortcuts.onKeyUp(for: .rewind5s) { [playerManager] in
        Task { @MainActor in
          playerManager.seek(to: -5)
        }
      }

      KeyboardShortcuts.onKeyUp(for: .forward10s) { [playerManager] in
        Task { @MainActor in
          playerManager.seek(to: 10)
        }
      }

      KeyboardShortcuts.onKeyUp(for: .setPointA) { [playerManager] in
        Task { @MainActor in
          playerManager.setPointA()
        }
      }

      KeyboardShortcuts.onKeyUp(for: .setPointB) { [playerManager] in
        Task { @MainActor in
          playerManager.setPointB()
        }
      }

      KeyboardShortcuts.onKeyUp(for: .clearLoop) { [playerManager] in
        Task { @MainActor in
          playerManager.clearLoop()
        }
      }

      KeyboardShortcuts.onKeyUp(for: .saveSegment) { [playerManager] in
        Task { @MainActor in
          _ = playerManager.saveCurrentSegment()
        }
      }

      KeyboardShortcuts.onKeyUp(for: .previousSegment) { [playerManager] in
        Task { @MainActor in
          playerManager.selectPreviousSegment()
        }
      }

      KeyboardShortcuts.onKeyUp(for: .nextSegment) { [playerManager] in
        Task { @MainActor in
          playerManager.selectNextSegment()
        }
      }

    } catch {
      fatalError("Failed to create model container: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      MainSplitView()
        .environment(playerManager)
        .environment(sessionTracker)
        .environment(transcriptionManager)
        .environment(transcriptionSettings)
    }
    .modelContainer(modelContainer)

    #if os(macOS)
      Settings {
        SettingsView()
          .environment(transcriptionSettings)
          .environment(transcriptionManager)
      }
      .windowToolbarStyle(.unified(showsTitle: false))
    #endif
  }
}
