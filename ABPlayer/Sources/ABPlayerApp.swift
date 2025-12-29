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
  private let queueManager: TranscriptionQueueManager

  init() {
    do {
      SentrySDK.start { (options: Sentry.Options) in
        options.dsn =
          "https://0e00826ef2b3fbc195fb428a468fd995@o4504292283580416.ingest.us.sentry.io/4510502660341760"
        options.debug = true  // Enabling debug when first installing is always helpful
        options.sendDefaultPii = true
      }

      let schema = Schema([
        AudioFile.self,
        LoopSegment.self,
        ListeningSession.self,
        PlaybackRecord.self,
        Folder.self,
        SubtitleFile.self,
        Transcription.self,
        Vocabulary.self,
      ])

      let appSupportDir = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first!
      #if DEBUG
        let folderName = "cc.ihugo.app.ABPlayer-dev"
      #else
        let folderName = "cc.ihugo.app.ABPlayer"
      #endif

      let storeURL = appSupportDir.appendingPathComponent(
        folderName, isDirectory: true
      )
      .appendingPathComponent("ABPlayer.sqlite")

      let modelConfiguration = ModelConfiguration(url: storeURL)
      modelContainer = try ModelContainer(for: schema, configurations: modelConfiguration)
      modelContainer.mainContext.autosaveEnabled = true

      // Initialize queue manager with dependencies
      queueManager = TranscriptionQueueManager(
        transcriptionManager: transcriptionManager,
        settings: transcriptionSettings
      )
      queueManager.modelContext = modelContainer.mainContext

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
        .focusEffectDisabled()
        .environment(playerManager)
        .environment(sessionTracker)
        .environment(transcriptionManager)
        .environment(transcriptionSettings)
        .environment(queueManager)
    }
    .defaultSize(width: 1600, height: 900)
    .modelContainer(modelContainer)
    .commands {
      SettingsCommands()
    }

    #if os(macOS)
      WindowGroup(id: "settings-window") {
        SettingsView()
          .environment(transcriptionSettings)
          .environment(transcriptionManager)
      }
      .defaultPosition(.center)
      .commandsRemoved()
    #endif
  }
}

// MARK: - Settings Commands
struct SettingsCommands: Commands {
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandGroup(replacing: .appSettings) {
      Button("Settings...") {
        openWindow(id: "settings-window")
      }
      .keyboardShortcut(",", modifiers: .command)
    }
  }
}
