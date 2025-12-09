import Sentry
import SwiftUI
import SwiftData

@main
struct ABPlayerApp: App {
    private let modelContainer: ModelContainer
    private let playerManager = AudioPlayerManager()
    private let sessionTracker = SessionTracker()

    init() {
        do {
            SentrySDK.start { (options: Sentry.Options) in
                options.dsn = "https://0e00826ef2b3fbc195fb428a468fd995@o4504292283580416.ingest.us.sentry.io/4510502660341760"
                options.debug = true // Enabling debug when first installing is always helpful
                options.sendDefaultPii = true
            }
            
            modelContainer = try ModelContainer(
                for: AudioFile.self,
                LoopSegment.self,
                ListeningSession.self
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerManager)
                .environment(sessionTracker)
        }
        .modelContainer(modelContainer)
    }
}

