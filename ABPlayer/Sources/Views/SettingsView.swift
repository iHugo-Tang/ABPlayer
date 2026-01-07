import KeyboardShortcuts
import SwiftUI

/// FFmpeg path validation status
enum FFmpegStatus {
  case unchecked
  case valid
  case invalid
  case notFound
}

/// Settings view for configuring application options
struct SettingsView: View {
  @Environment(TranscriptionSettings.self) private var settings
  @Environment(TranscriptionManager.self) private var transcriptionManager

  // Navigation selection
  @State private var selectedTab: SettingsTab? = .transcription

  // Transcription states
  @State private var isSelectingDirectory = false
  @State private var downloadedModels: [(name: String, size: Int64)] = []
  @State private var modelToDelete: String?
  @State private var showDeleteConfirmation = false
  @State private var isMigrating = false
  @State private var migrationError: String?
  @State private var previousDirectory: String = ""

  // FFmpeg states
  @State private var isSelectingFFmpegPath = false
  @State private var ffmpegPathStatus: FFmpegStatus = .unchecked

  // Shortcuts states
  @State private var showResetConfirmation = false

  var body: some View {
    NavigationSplitView {
      //      EmptyView()
      //        .toolbar(removing: .sidebarToggle)
      //    } content: {
      List(selection: $selectedTab) {
        ForEach(SettingsTab.allCases) { tab in
          NavigationLink(value: tab) {
            Label(tab.rawValue, systemImage: tab.icon)
          }
        }
      }
      .listStyle(.sidebar)
      .scrollContentBackground(.hidden)
      .navigationSplitViewColumnWidth(min: 200, ideal: 200)
    } detail: {
      Group {
        if let selectedTab {
          switch selectedTab {
          case .shortcuts:
            shortcutsView
          case .transcription:
            transcriptionSettingsView
          }
        } else {
          ContentUnavailableView("Select a setting", systemImage: "gear")
        }
      }
      .navigationTitle("Settings")
    }
    .navigationSplitViewStyle(.balanced)
    .frame(minWidth: 400, idealWidth: 600)
    .frame(minHeight: 400, idealHeight: 600)
    // Common modifiers
    .fileImporter(
      isPresented: $isSelectingFFmpegPath,
      allowedContentTypes: [.unixExecutable],
      allowsMultipleSelection: false
    ) { result in
      handleFFmpegPathSelection(result)
    }
    .fileImporter(
      isPresented: $isSelectingDirectory,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      handleDirectorySelection(result)
    }
    .confirmationDialog(
      "Delete Model",
      isPresented: $showDeleteConfirmation,
      presenting: modelToDelete
    ) { model in
      Button("Delete \(model)", role: .destructive) {
        deleteModel(named: model)
      }
      Button("Cancel", role: .cancel) {
        modelToDelete = nil
      }
    } message: { model in
      Text("Are you sure you want to delete the model \"\(model)\"? This cannot be undone.")
    }
    .alert("Migration Error", isPresented: .constant(migrationError != nil)) {
      Button("OK") { migrationError = nil }
    } message: {
      if let error = migrationError {
        Text(error)
      }
    }
    .confirmationDialog(
      "Reset Keyboard Shortcuts",
      isPresented: $showResetConfirmation
    ) {
      Button("Reset to Defaults", role: .destructive) {
        resetAllShortcuts()
      }
      Button("Cancel", role: .cancel) {
        showResetConfirmation = false
      }
    } message: {
      Text("Are you sure you want to reset all keyboard shortcuts to their default values?")
    }
    .onAppear {
      if selectedTab == .transcription {
        refreshModels()
        ffmpegPathStatus = .unchecked
      }
    }
    .onChange(of: selectedTab) { _, newValue in
      if newValue == .transcription {
        refreshModels()
      }
    }
  }

  // MARK: - Shortcuts View

  private var shortcutsView: some View {
    Form {
      Section("Playback") {
        shortcutRow(title: "Play/Pause:", name: .playPause)
        shortcutRow(title: "Rewind 5s:", name: .rewind5s)
        shortcutRow(title: "Forward 10s:", name: .forward10s)
      }

      Section("Loop Controls") {
        shortcutRow(title: "Set Point A:", name: .setPointA)
        shortcutRow(title: "Set Point B:", name: .setPointB)
        shortcutRow(title: "Clear Loop:", name: .clearLoop)
        shortcutRow(title: "Save Segment:", name: .saveSegment)
      }

      Section("Navigation") {
        shortcutRow(title: "Previous Segment:", name: .previousSegment)
        shortcutRow(title: "Next Segment:", name: .nextSegment)
      }

      Section {
        HStack {
          Spacer()
          Button("Reset to Defaults") {
            showResetConfirmation = true
          }
          .buttonStyle(.borderedProminent)
          Spacer()
        }
      } footer: {
        Text("Reset all keyboard shortcuts to their default values")
          .captionStyle()
      }
    }
    .formStyle(.grouped)
  }

  private func shortcutRow(title: String, name: KeyboardShortcuts.Name) -> some View {
    KeyboardShortcuts.Recorder(title, name: name)
  }

  private func resetAllShortcuts() {
    // Reset all shortcuts to their default values
    KeyboardShortcuts.reset(.playPause)
    KeyboardShortcuts.reset(.rewind5s)
    KeyboardShortcuts.reset(.forward10s)
    KeyboardShortcuts.reset(.setPointA)
    KeyboardShortcuts.reset(.setPointB)
    KeyboardShortcuts.reset(.clearLoop)
    KeyboardShortcuts.reset(.saveSegment)
    KeyboardShortcuts.reset(.previousSegment)
    KeyboardShortcuts.reset(.nextSegment)
  }

  // MARK: - Transcription Settings View

  private var transcriptionSettingsView: some View {
    Form {
      transcriptionSection
      downloadedModelsSection
    }
    .formStyle(.grouped)
  }

  // MARK: - Transcription Section

  private var transcriptionSection: some View {
    Section {
      // Model Selection
      Picker(
        "Model",
        selection: Binding(
          get: { settings.modelName },
          set: { settings.modelName = $0 }
        )
      ) {
        ForEach(TranscriptionSettings.availableModels, id: \.id) { model in
          Text(model.name).tag(model.id)
        }
      }

      // Model Status
      HStack {
        Text("Status")
        Spacer()
        if case .downloading(let progress, let modelName) = transcriptionManager.state,
          modelName == settings.modelName
        {
          HStack(spacing: 8) {
            ProgressView(value: progress)
              .progressViewStyle(.linear)
              .frame(width: 60)
              .controlSize(.small)

            Text("\(Int(progress * 100))%")
              .monospacedDigit()
              .foregroundStyle(.secondary)
              .font(.caption)

            Button {
              transcriptionManager.cancelDownload()
              settings.deleteDownloadCache(modelName: modelName)
              refreshModels()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Cancel download")
          }
        } else if isCurrentModelDownloaded {
          HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
            Text("Downloaded")
              .foregroundStyle(.secondary)
          }
        } else {
          Button {
            Task { await downloadCurrentModel() }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "arrow.down.circle")
              Text("Download")
            }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }
      }

      // Language Selection
      Picker(
        "Language",
        selection: Binding(
          get: { settings.language },
          set: { settings.language = $0 }
        )
      ) {
        ForEach(TranscriptionSettings.availableLanguages, id: \.id) { language in
          Text(language.name).tag(language.id)
        }
      }

      // Model Directory
      LabeledContent("Model Directory") {
        HStack {
          Text(displayDirectory)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)

          Button("Choose...") {
            previousDirectory = settings.modelDirectory
            isSelectingDirectory = true
          }
        }
      }

      // Auto-transcribe toggle
      Toggle(
        "Auto-transcribe new files",
        isOn: Binding(
          get: { settings.autoTranscribe },
          set: { settings.autoTranscribe = $0 }
        ))

      // FFmpeg Path
      LabeledContent("FFmpeg Path") {
        HStack {
          Text(displayFFmpegPath)
            .foregroundStyle(ffmpegStatusColor)
            .lineLimit(1)
            .truncationMode(.middle)

          Button("Choose...") {
            isSelectingFFmpegPath = true
          }
        }
      }

    } header: {
      Label("Transcription", systemImage: "text.bubble")
    } footer: {
      VStack(alignment: .leading, spacing: 8) {
        Text(
          "WhisperKit uses on-device speech recognition. Larger models are more accurate but require more storage and memory."
        )

        HStack(spacing: 4) {
          Text("Models will be saved to:")
          Button {
            let url =
              settings.modelDirectory.isEmpty
              ? TranscriptionSettings.defaultModelDirectory
              : URL(fileURLWithPath: settings.modelDirectory)
            NSWorkspace.shared.open(url)
          } label: {
            Text(
              settings.modelDirectory.isEmpty
                ? TranscriptionSettings.defaultModelDirectory.path
                : settings.modelDirectory
            )
            .underline()
            .foregroundStyle(.primary)
          }
          .buttonStyle(.plain)
          .onHover { inside in
            if inside {
              NSCursor.pointingHand.push()
            } else {
              NSCursor.pop()
            }
          }
        }
        .captionStyle()

        Text(
          "FFmpeg is required for extracting audio from video files. If not installed, video transcription will fail."
        )
        .captionStyle()

        if ffmpegPathStatus != .valid {
          Text("Install with: brew install ffmpeg")
            .captionStyle()
        }
      }
    }
  }

  // MARK: - Downloaded Models Section

  private var downloadedModelsSection: some View {
    Section {
      if isMigrating {
        HStack {
          ProgressView()
            .controlSize(.small)
          Text("Moving models...")
            .foregroundStyle(.secondary)
        }
      } else if downloadedModels.isEmpty {
        Text("No models downloaded")
          .foregroundStyle(.secondary)
      } else {
        ForEach(downloadedModels, id: \.name) { model in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(model.name)
                .bodyStyle()
              Text(TranscriptionSettings.formatSize(model.size))
                .captionStyle()
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
              modelToDelete = model.name
              showDeleteConfirmation = true
            } label: {
              Image(systemName: "trash")
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
          }
          .padding(.vertical, 2)
        }
      }
    } header: {
      Label("Downloaded Models", systemImage: "square.and.arrow.down")
    } footer: {
      if !downloadedModels.isEmpty {
        let totalSize = downloadedModels.reduce(0) { $0 + $1.size }
        Text("Total: \(TranscriptionSettings.formatSize(totalSize))")
      }
    }
  }

  // MARK: - Helpers

  private var displayFFmpegPath: String {
    if settings.ffmpegPath.isEmpty {
      if let detected = TranscriptionSettings.autoDetectFFmpegPath() {
        return "Auto-detected: \(detected)"
      }
      return "Not found"
    }
    return settings.ffmpegPath
  }

  private var ffmpegStatusColor: Color {
    updateFFmpegStatus()

    switch ffmpegPathStatus {
    case .valid:
      return .green
    case .invalid, .notFound:
      return .red
    case .unchecked:
      return .secondary
    }
  }

  private func updateFFmpegStatus() {
    if ffmpegPathStatus == .unchecked {
      if settings.ffmpegPath.isEmpty {
        if let _ = TranscriptionSettings.autoDetectFFmpegPath() {
          ffmpegPathStatus = .valid
        } else {
          ffmpegPathStatus = .notFound
        }
      } else {
        if TranscriptionSettings.isFFmpegValid(at: settings.ffmpegPath) {
          ffmpegPathStatus = .valid
        } else {
          ffmpegPathStatus = .invalid
        }
      }
    }
  }

  private func handleFFmpegPathSelection(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      if let url = urls.first {
        settings.ffmpegPath = url.path
        ffmpegPathStatus = .unchecked
      }
    case .failure:
      break
    }
  }

  private var displayDirectory: String {
    if settings.modelDirectory.isEmpty {
      return "Default"
    }
    return (settings.modelDirectory as NSString).lastPathComponent
  }

  /// Check if the currently selected model is downloaded
  private var isCurrentModelDownloaded: Bool {
    // WhisperKit uses naming like "openai_whisper-tiny" or "distil-whisper_distil-large-v3"
    downloadedModels.contains { model in
      model.name.contains(settings.modelName)
    }
  }

  private func refreshModels() {
    Task {
      downloadedModels = await settings.listDownloadedModelsAsync()
    }
  }

  private func downloadCurrentModel() async {
    do {
      try await transcriptionManager.loadModel(
        modelName: settings.modelName,
        downloadBase: settings.modelDirectoryURL
      )
      refreshModels()
    } catch is CancellationError {
      // Download cancelled, no need to show error
    } catch {
      migrationError = "Failed to download model: \(error.localizedDescription)"
    }
  }

  private func deleteModel(named name: String) {
    do {
      try settings.deleteModel(named: name)
      refreshModels()
    } catch {
      migrationError = "Failed to delete model: \(error.localizedDescription)"
    }
    modelToDelete = nil
  }

  private func handleDirectorySelection(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      if let url = urls.first {
        // Store bookmark for security-scoped access
        if (try? url.bookmarkData(
          options: [.withSecurityScope],
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )) != nil {
          let newPath = url.path
          let oldPath =
            previousDirectory.isEmpty
            ? TranscriptionSettings.defaultModelDirectory.path
            : previousDirectory

          // Check if we need to migrate
          if !downloadedModels.isEmpty && oldPath != newPath {
            migrateModels(from: oldPath, to: newPath)
          }

          settings.modelDirectory = newPath
          refreshModels()
        }
      }
    case .failure:
      break
    }
  }

  private func migrateModels(from oldPath: String, to newPath: String) {
    isMigrating = true

    Task {
      do {
        let oldURL = URL(fileURLWithPath: oldPath)
        let newURL = URL(fileURLWithPath: newPath)
        try settings.migrateModels(from: oldURL, to: newURL)
      } catch {
        await MainActor.run {
          migrationError = "Failed to migrate models: \(error.localizedDescription)"
        }
      }

      await MainActor.run {
        isMigrating = false
        refreshModels()
      }
    }
  }
}

// MARK: - Supporting Views

enum SettingsTab: String, CaseIterable, Identifiable {
  case shortcuts = "Shortcuts"
  case transcription = "Transcription"

  var id: Self { self }

  var icon: String {
    switch self {
    case .shortcuts: return "keyboard"
    case .transcription: return "text.bubble"
    }
  }
}

// MARK: - Preview

#Preview {
  SettingsView()
    .environment(TranscriptionSettings())
    .environment(TranscriptionManager())
    .frame(width: 800, height: 600)
}
