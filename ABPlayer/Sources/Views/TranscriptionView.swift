import SwiftData
import SwiftUI

/// View for transcription display and controls
struct TranscriptionView: View {
  let audioFile: AudioFile

  @Environment(TranscriptionManager.self) private var transcriptionManager
  @Environment(TranscriptionSettings.self) private var settings
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(\.modelContext) private var modelContext

  @State private var cachedCues: [SubtitleCue] = []
  @State private var hasCheckedCache = false

  var body: some View {
    Group {
      switch transcriptionManager.state {
      case .idle:
        if cachedCues.isEmpty && hasCheckedCache {
          noTranscriptionView
        } else if !cachedCues.isEmpty {
          transcriptionContentView
        } else {
          loadingCacheView
        }

      case .downloading(let progress, let modelName):
        downloadingView(progress: progress, modelName: modelName)

      case .loading(let modelName):
        loadingModelView(modelName: modelName)

      case .transcribing(let progress, let fileName):
        transcribingView(progress: progress, fileName: fileName)

      case .completed:
        if !cachedCues.isEmpty {
          transcriptionContentView
        } else {
          loadingCacheView
        }

      case .failed(let error):
        failedView(error: error)

      case .cancelled:
        noTranscriptionView
      }
    }
    .task {
      await loadCachedTranscription()
    }
    .onChange(of: audioFile.id) { _, _ in
      // Reset when audio file changes
      cachedCues = []
      hasCheckedCache = false
      transcriptionManager.reset()
      Task {
        await loadCachedTranscription()
      }
    }
  }

  // MARK: - Content View

  private var transcriptionContentView: some View {
    VStack(spacing: 0) {
      // Toolbar with cache management
      HStack {
        Spacer()

        Button {
          Task { await clearAndRetranscribe() }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
            Text("Re-transcribe")
          }
          .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      SubtitleView(cues: cachedCues)
        .id(cachedCues.count)
    }
  }

  // MARK: - Loading Cache View

  private var loadingCacheView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .controlSize(.regular)
      Text("Checking cache...")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Empty State

  private var noTranscriptionView: some View {
    VStack(spacing: 20) {
      Image(systemName: "text.bubble")
        .font(.system(size: 56, weight: .light))
        .foregroundStyle(.quaternary)

      VStack(spacing: 8) {
        Text("No Transcription")
          .font(.title2)
          .fontWeight(.medium)

        Text("Generate subtitles using on-device speech recognition")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 280)
      }

      Button {
        Task { await startTranscription() }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "waveform")
          Text("Transcribe Audio")
        }
        .font(.body.weight(.medium))
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }

  // MARK: - Progress Views

  private func downloadingView(progress: Double, modelName: String) -> some View {
    VStack {
      progressView(
        icon: "arrow.down.circle",
        title: "Downloading Model",
        subtitle: modelName,
        progress: progress,
        showPercentage: true
      )

      Button("Cancel") {
        transcriptionManager.cancelDownload()
        settings.deleteDownloadCache(modelName: modelName)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .padding(.bottom, 20)
    }
  }

  private func loadingModelView(modelName: String) -> some View {
    progressView(
      icon: "brain",
      title: "Loading Model",
      subtitle: modelName,
      progress: nil,
      showPercentage: false,
      footnote: "This may take a moment on first run"
    )
  }

  private func transcribingView(progress: Double, fileName: String) -> some View {
    progressView(
      icon: "waveform",
      title: "Transcribing",
      subtitle: fileName,
      progress: progress > 0 ? progress : nil,
      showPercentage: progress > 0
    )
  }

  private func progressView(
    icon: String,
    title: String,
    subtitle: String,
    progress: Double?,
    showPercentage: Bool,
    footnote: String? = nil
  ) -> some View {
    VStack(spacing: 20) {
      Image(systemName: icon)
        .font(.system(size: 40, weight: .light))
        .foregroundStyle(.tint)
        .symbolEffect(.pulse, options: .repeating)

      VStack(spacing: 6) {
        Text(title)
          .font(.headline)

        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      if let progress {
        VStack(spacing: 8) {
          ProgressView(value: progress)
            .progressViewStyle(.linear)
            .frame(maxWidth: 200)

          if showPercentage {
            Text("\(Int(progress * 100))%")
              .captionStyle()
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        }
      } else {
        ProgressView()
          .controlSize(.regular)
      }

      if let footnote {
        Text(footnote)
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }

  // MARK: - Failed View

  private func failedView(error: String) -> some View {
    VStack(spacing: 20) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 48, weight: .light))
        .foregroundStyle(.orange)

      VStack(spacing: 8) {
        Text("Transcription Failed")
          .font(.title3)
          .fontWeight(.medium)

        Text(error)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 300)
      }

      Button {
        transcriptionManager.reset()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "arrow.clockwise")
          Text("Try Again")
        }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }

  // MARK: - Cache Operations

  private func loadCachedTranscription() async {
    let audioFileId = audioFile.id.uuidString

    // Query cache from SwiftData
    let descriptor = FetchDescriptor<Transcription>(
      predicate: #Predicate { $0.audioFileId == audioFileId }
    )

    if let cached = try? modelContext.fetch(descriptor).first {
      cachedCues = cached.cues
    }
    hasCheckedCache = true
  }

  private func startTranscription() async {
    do {
      let url = try resolveURL(from: audioFile.bookmarkData)
      let cues = try await transcriptionManager.transcribe(
        audioURL: url,
        settings: settings
      )
      cachedCues = cues
      transcriptionManager.reset()

      // Cache the result
      let audioFileId = audioFile.id.uuidString

      // Check if cache already exists and update it
      let descriptor = FetchDescriptor<Transcription>(
        predicate: #Predicate { $0.audioFileId == audioFileId }
      )

      if let existing = try? modelContext.fetch(descriptor).first {
        existing.cues = cues
        existing.createdAt = Date()
        existing.modelUsed = settings.modelName
        existing.language = settings.language
      } else {
        let cache = Transcription(
          audioFileId: audioFileId,
          audioFileName: audioFile.displayName,
          cues: cues,
          modelUsed: settings.modelName,
          language: settings.language == "auto" ? nil : settings.language
        )
        modelContext.insert(cache)
      }

      try? modelContext.save()
    } catch {
      // Error is handled by TranscriptionManager state
    }
  }

  private func clearAndRetranscribe() async {
    // Delete existing cache
    let audioFileId = audioFile.id.uuidString
    let descriptor = FetchDescriptor<Transcription>(
      predicate: #Predicate { $0.audioFileId == audioFileId }
    )

    if let existing = try? modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
      try? modelContext.save()
    }

    // Reset state and start fresh transcription
    cachedCues = []
    transcriptionManager.reset()
    await startTranscription()
  }

  private func resolveURL(from bookmarkData: Data) throws -> URL {
    var isStale = false
    return try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
  }
}

// MARK: - Empty State

struct TranscriptionEmptyView: View {
  var body: some View {
    ContentUnavailableView(
      "No Audio Selected",
      systemImage: "text.bubble",
      description: Text("Select an audio file to transcribe")
    )
  }
}
