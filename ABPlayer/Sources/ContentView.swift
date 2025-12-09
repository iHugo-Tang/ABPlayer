import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine
#if os(macOS)
import AppKit
#endif

public struct ContentView: View {
    @Environment(AudioPlayerManager.self) private var playerManager
    @Environment(SessionTracker.self) private var sessionTracker
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AudioFile.createdAt, order: .forward)
    private var audioFiles: [AudioFile]

    @State private var selectedFile: AudioFile?
    @State private var isImportingFile: Bool = false
    @State private var importErrorMessage: String?
    @AppStorage("lastSelectedAudioFileID") private var lastSelectedAudioFileID: String?

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let selectedFile {
                PlayerView(audioFile: selectedFile)
            } else {
                VStack {
                    Text("No file selected")
                        .font(.title2)
                    Text("Use the + button to import an MP3 file and start creating A-B loops.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [UTType.mp3],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .onAppear {
            sessionTracker.attachModelContext(modelContext)
            playerManager.sessionTracker = sessionTracker
            restoreLastSelectionIfNeeded()
        }
        .task(id: audioFiles.map(\.id)) {
            restoreLastSelectionIfNeeded()
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            sessionTracker.persistProgress()
            sessionTracker.endSessionIfIdle()
        }
        #endif
        .alert(
            "Import Failed",
            isPresented: .constant(importErrorMessage != nil),
            presenting: importErrorMessage
        ) { _ in
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: { message in
            Text(message)
        }
    }

    private var sidebar: some View {
        let list = List {
            mp3Section
        }

        return list
            .navigationTitle("ABPlayer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isImportingFile = true
                    } label: {
                        Label("Add MP3", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                versionFooter
            }
    }

    private var mp3Section: some View {
        Section("MP3 Files") {
            if audioFiles.isEmpty {
                Text("No files yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(audioFiles, id: \.id) { file in
                    fileRow(for: file)
                }
            }
        }
    }

    @ViewBuilder
    private func fileRow(for file: AudioFile) -> some View {
        let isSelected = selectedFile?.id == file.id

        Button {
            selectFile(file)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(file.displayName)
                        .lineLimit(1)
                    Text(file.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var versionFooter: some View {
        Text("Version \(bundleShortVersion) • Build \(bundleVersion)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }

    private var bundleShortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var bundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importErrorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else {
                return
            }

            addAudioFile(from: url)
        }
    }

    private func addAudioFile(from url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let displayName = url.lastPathComponent
            let audioFile = AudioFile(
                displayName: displayName,
                bookmarkData: bookmarkData
            )

            modelContext.insert(audioFile)
            selectFile(audioFile)
        } catch {
            importErrorMessage = "Failed to import file: \(error.localizedDescription)"
        }
    }

    private func selectFile(_ file: AudioFile) {
        selectedFile = file
        lastSelectedAudioFileID = file.id.uuidString

        if playerManager.currentFile?.id == file.id,
           playerManager.currentFile != nil {
            playerManager.currentFile = file
            return
        }

        playerManager.load(audioFile: file)
    }

    private func restoreLastSelectionIfNeeded() {
        guard selectedFile == nil else {
            if let currentFile = playerManager.currentFile,
               let matchedFile = audioFiles.first(where: { $0.id == currentFile.id }) {
                selectedFile = matchedFile
                playerManager.currentFile = matchedFile
            }
            return
        }

        if let currentFile = playerManager.currentFile,
           let matchedFile = audioFiles.first(where: { $0.id == currentFile.id }) {
            selectedFile = matchedFile
            playerManager.currentFile = matchedFile
            return
        }

        guard let lastSelectedAudioFileID,
              let lastID = UUID(uuidString: lastSelectedAudioFileID),
              let file = audioFiles.first(where: { $0.id == lastID }) else {
            return
        }

        selectFile(file)
    }
}

