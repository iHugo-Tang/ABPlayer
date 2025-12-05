import SwiftUI
import SwiftData

@main
struct ABPlayerApp: App {
    @State private var playerManager = AudioPlayerManager()
    @State private var sessionTracker = SessionTracker()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerManager)
                .environment(sessionTracker)
        }
        .modelContainer(for: [
            AudioFile.self,
            LoopSegment.self,
            ListeningSession.self
        ])
    }
}

