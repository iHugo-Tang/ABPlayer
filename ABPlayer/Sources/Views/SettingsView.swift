import SwiftUI

/// Settings view for configuring transcription options
struct SettingsView: View {
  @Environment(TranscriptionSettings.self) private var settings
  @Environment(TranscriptionManager.self) private var transcriptionManager
  @State private var isSelectingDirectory = false
  @State private var downloadedModels: [(name: String, size: Int64)] = []
  @State private var modelToDelete: String?
  @State private var showDeleteConfirmation = false
  @State private var isMigrating = false
  @State private var migrationError: String?
  @State private var previousDirectory: String = ""
  @State private var isDownloading = false

  var body: some View {
    Form {
      transcriptionSection
      downloadedModelsSection
    }
    .formStyle(.grouped)
    .navigationTitle("Settings")
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
    .onAppear {
      refreshModels()
    }
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
        if isDownloading {
          HStack(spacing: 6) {
            ProgressView()
              .controlSize(.small)
            Text("Downloading...")
              .foregroundStyle(.secondary)
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

          if !settings.modelDirectory.isEmpty {
            Button {
              settings.modelDirectory = ""
              refreshModels()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
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

    } header: {
      Label("Transcription", systemImage: "text.bubble")
    } footer: {
      VStack(alignment: .leading, spacing: 8) {
        Text(
          "WhisperKit uses on-device speech recognition. Larger models are more accurate but require more storage and memory."
        )

        if !settings.modelDirectory.isEmpty {
          Text("Models will be saved to: \(settings.modelDirectory)")
            .captionStyle()
        } else {
          Text("Models will be saved to: \(TranscriptionSettings.defaultModelDirectory.path)")
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
    downloadedModels = settings.listDownloadedModels()
  }

  private func downloadCurrentModel() async {
    isDownloading = true
    do {
      try await transcriptionManager.loadModel(
        modelName: settings.modelName,
        downloadBase: settings.modelDirectoryURL
      )
      refreshModels()
    } catch {
      migrationError = "Failed to download model: \(error.localizedDescription)"
    }
    isDownloading = false
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

// MARK: - Preview

#Preview {
  SettingsView()
    .environment(TranscriptionSettings())
    .environment(TranscriptionManager())
    .frame(width: 500, height: 500)
}
