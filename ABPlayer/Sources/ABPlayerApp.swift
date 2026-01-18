import KeyboardShortcuts
import OSLog
import Sentry
import Sparkle
import SwiftData
import SwiftUI
import TelemetryDeck

extension Logger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "cc.ihugo.ABPlayer"

  static let audio = Logger(subsystem: subsystem, category: "audio")
  static let ui = Logger(subsystem: subsystem, category: "ui")
  static let data = Logger(subsystem: subsystem, category: "data")
  static let general = Logger(subsystem: subsystem, category: "general")
}

@MainActor
final class SparkleUpdater: ObservableObject {
  private let controller: SPUStandardUpdaterController

  init() {
    controller = SPUStandardUpdaterController(
      startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
  }

  func checkForUpdates() {
    controller.checkForUpdates(nil)
  }
}

@main
struct ABPlayerApp: App {
  @Environment(\.scenePhase) private var scenePhase

  private let modelContainer: ModelContainer
  private let playerManager = AudioPlayerManager()
  private let sessionTracker = SessionTracker()
  private let transcriptionManager = TranscriptionManager()
  private let transcriptionSettings = TranscriptionSettings()
  private let vocabularyService: VocabularyService

  private let queueManager: TranscriptionQueueManager
  private let updater = SparkleUpdater()

  init() {
    let config = TelemetryDeck.Config(appID: "A4A99FD4-3F84-49FA-AF97-0806D61D0539")
    TelemetryDeck.initialize(config: config)

    do {
      SentrySDK.start { (options: Sentry.Options) in
        options.dsn =
          "https://0e00826ef2b3fbc195fb428a468fd995@o4504292283580416.ingest.us.sentry.io/4510502660341760"
        options.debug = false
        options.sendDefaultPii = true
      }

      let schema = Schema([
        ABFile.self,
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
      let folderName = Bundle.main.bundleIdentifier ?? "cc.ihugo.app.ABPlayer"

      let storeURL = appSupportDir.appendingPathComponent(
        folderName, isDirectory: true
      )
      .appendingPathComponent("ABPlayer.sqlite")

      let modelConfiguration = ModelConfiguration(url: storeURL)
      modelContainer = try ModelContainer(for: schema, configurations: modelConfiguration)
      modelContainer.mainContext.autosaveEnabled = true

      vocabularyService = VocabularyService(modelContext: modelContainer.mainContext)
      
      queueManager = TranscriptionQueueManager(
        transcriptionManager: transcriptionManager,
        settings: transcriptionSettings
      )
      queueManager.modelContext = modelContainer.mainContext

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
        .containerBackground(Color.asset.bgSecondary, for: .window)
        .toolbarBackground(Color.asset.bgTertiary, for: .automatic)
        .focusEffectDisabled()
        .environment(playerManager)
        .environment(sessionTracker)
        .environment(transcriptionManager)
        .environment(transcriptionSettings)
        .environment(queueManager)
        .environment(vocabularyService)
    }
    .defaultSize(width: 1600, height: 900)
    .windowResizability(.contentSize)
    .modelContainer(modelContainer)
    .onChange(of: scenePhase) { _, newPhase in
      switch newPhase {
      case .active:
        SentrySDK.resumeAppHangTracking()
      default:
        SentrySDK.pauseAppHangTracking()
      }
    }
    .commands {
      SettingsCommands()
      CommandGroup(replacing: .appInfo) {
        Button("About ABPlayer") {
          NSApp.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
              string: "Developed by Sunset Valley",
              attributes: [
                NSAttributedString.Key.font: NSFont.systemFont(
                  ofSize: 11)
              ]
            )
          ])
        }

        Button("Check for Updates...") {
          updater.checkForUpdates()
        }
      }
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
