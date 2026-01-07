import SwiftData
import SwiftUI

/// View for transcription display and controls
struct TranscriptionView: View {
  let audioFile: AudioFile

  @Environment(TranscriptionManager.self) private var transcriptionManager
  @Environment(TranscriptionQueueManager.self) private var queueManager
  @Environment(TranscriptionSettings.self) private var settings
  @Environment(AudioPlayerManager.self) private var playerManager
  @Environment(\.modelContext) private var modelContext

  @AppStorage("subtitleFontSize") private var subtitleFontSize: Double = 16

  @State private var cachedCues: [SubtitleCue] = []
  @State private var hasCheckedCache = false
  /// Countdown seconds for pause highlight/scroll (nil when not paused)
  @State private var pauseCountdown: Int?

  /// Current file's task from the queue
  private var currentTask: TranscriptionTask? {
    queueManager.getTask(for: audioFile.id)
  }

  var body: some View {
    Group {
      // Check if current file has a task in the queue
      if let task = currentTask {
        taskProgressView(task: task)
      } else {
        // Original logic for non-queued state
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

        case .extractingAudio(let progress, let fileName):
          extractingAudioView(progress: progress, fileName: fileName)

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
        Button {
          Task { await clearAndRetranscribe() }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
            Text("Re-transcribe")
          }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)

        Spacer()

        // Subtitle Font Size Picker
        HStack(spacing: 0) {
          ForEach([("Small", 14.0), ("Medium", 16.0), ("Large", 18.0)], id: \.0) { label, size in
            Button {
              subtitleFontSize = size
            } label: {
              Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(
              subtitleFontSize == size ? Color.accentColor : Color.secondary.opacity(0.15)
            )
            .foregroundStyle(subtitleFontSize == size ? .white : .secondary)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      SubtitleView(cues: cachedCues, countdownSeconds: $pauseCountdown, fontSize: subtitleFontSize)
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
      }

      Button {
        startTranscription()
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

  private func extractingAudioView(progress: Double, fileName: String) -> some View {
    progressView(
      icon: "waveform.and.mic",
      title: "Extracting Audio",
      subtitle: fileName,
      progress: progress > 0 ? progress : nil,
      showPercentage: progress > 0,
      footnote: "Converting video to audio format"
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

  /// View for queue task progress
  private func taskProgressView(task: TranscriptionTask) -> some View {
    VStack {
      switch task.status {
      case .queued:
        progressView(
          icon: "clock",
          title: "Queued",
          subtitle: task.audioFileName,
          progress: nil,
          showPercentage: false,
          footnote: "Waiting for other transcriptions to complete"
        )

      case .downloading(let progress):
        VStack {
          progressView(
            icon: "arrow.down.circle",
            title: "Downloading Model",
            subtitle: settings.modelName,
            progress: progress,
            showPercentage: true
          )
          cancelButton(taskId: task.id)
        }

      case .loading:
        VStack {
          progressView(
            icon: "brain",
            title: "Loading Model",
            subtitle: settings.modelName,
            progress: nil,
            showPercentage: false,
            footnote: "This may take a moment on first run"
          )
          cancelButton(taskId: task.id)
        }

      case .extractingAudio(let progress):
        VStack {
          progressView(
            icon: "waveform.and.mic",
            title: "Extracting Audio",
            subtitle: task.audioFileName,
            progress: progress > 0 ? progress : nil,
            showPercentage: progress > 0,
            footnote: "Converting video to audio format"
          )
          cancelButton(taskId: task.id)
        }

      case .transcribing(let progress):
        VStack {
          progressView(
            icon: "waveform",
            title: "Transcribing",
            subtitle: task.audioFileName,
            progress: progress > 0 ? progress : nil,
            showPercentage: progress > 0
          )
          cancelButton(taskId: task.id)
        }

      case .completed:
        // Reload cache and show content
        if !cachedCues.isEmpty {
          transcriptionContentView
        } else {
          loadingCacheView
            .task {
              await loadCachedTranscription()
              // Remove completed task from queue
              queueManager.removeTask(id: task.id)
            }
        }

      case .failed(let error):
        VStack(spacing: 20) {
          failedView(error: error)
          Button("Remove") {
            queueManager.removeTask(id: task.id)
          }
          .buttonStyle(.bordered)
        }

      case .cancelled:
        VStack(spacing: 20) {
          noTranscriptionView
        }
        .task {
          queueManager.removeTask(id: task.id)
        }
      }
    }
  }

  private func cancelButton(taskId: UUID) -> some View {
    Button("Cancel") {
      queueManager.cancelTask(id: taskId)
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .padding(.bottom, 20)
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
    // 1. 优先检查SRT文件 (先检查数据库标志位，如果不一致再尝试文件系统作为容错)
    if audioFile.hasTranscriptionRecord
      || FileManager.default.fileExists(atPath: audioFile.srtFileURL?.path ?? "")
    {
      if let srtCues = loadSRTFile() {
        cachedCues = srtCues
        hasCheckedCache = true

        return
      }
    }

    // 2. 回退到数据库缓存
    // audioFileId  String  "74FB0384-C8CB-4059-B3F9-42B986FF94EB"
    let audioFileId = audioFile.id.uuidString
    let descriptor = FetchDescriptor<Transcription>(
      predicate: #Predicate { $0.audioFileId == audioFileId }
    )

    if let cached = try? modelContext.fetch(descriptor).first {
      cachedCues = cached.cues
    }
    hasCheckedCache = true
  }

  private func loadSRTFile() -> [SubtitleCue]? {
    guard let srtURL = audioFile.srtFileURL else { return nil }

    // 需要security-scoped access
    guard let audioURL = try? resolveURL(from: audioFile.bookmarkData) else { return nil }

    let gotAccess = audioURL.startAccessingSecurityScopedResource()
    defer { if gotAccess { audioURL.stopAccessingSecurityScopedResource() } }

    return try? SubtitleParser.parse(from: srtURL)
  }

  private func startTranscription() {
    // Set modelContext on queue manager if needed
    if queueManager.modelContext == nil {
      queueManager.modelContext = modelContext
    }
    // Enqueue the transcription task
    queueManager.enqueue(audioFile: audioFile)
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

    // Delete SRT file
    if let srtURL = audioFile.srtFileURL {
      if let audioURL = try? resolveURL(from: audioFile.bookmarkData),
        audioURL.startAccessingSecurityScopedResource()
      {
        try? FileManager.default.removeItem(at: srtURL)
        audioURL.stopAccessingSecurityScopedResource()
      }
    }
    audioFile.hasTranscriptionRecord = false

    // Reset state and start fresh transcription
    cachedCues = []
    transcriptionManager.reset()
    startTranscription()
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
