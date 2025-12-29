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

  @State private var cachedCues: [SubtitleCue] = []
  @State private var hasCheckedCache = false
  /// Countdown seconds for pause highlight/scroll (nil when not paused)
  @State private var pauseCountdown: Int?
  /// Whether the countdown info popover is shown
  @State private var showCountdownInfo = false

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
          .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)

        Spacer()

        // Pause countdown indicator
        if pauseCountdown != nil || showCountdownInfo {
          let countdown = pauseCountdown ?? 0
          HStack(spacing: 8) {
            HStack(spacing: 4) {
              Image(systemName: "timer.circle")
              Text("\(countdown)s")
                .monospacedDigit()
            }

            Button {
              showCountdownInfo.toggle()
            } label: {
              Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showCountdownInfo) {
              VStack(alignment: .leading, spacing: 8) {
                Text("Pause Sync")
                  .font(.headline)
                Text(
                  "When you scroll or click the subtitle, the automatic scrolling and highlighting will pause.\nAfter the countdown ends, it will automatically resume."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
              }
              .padding()
              .frame(width: 240)
            }
          }
          .font(.caption)
          .help("Highlight and scroll paused for \(countdown) seconds")
        }

      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      SubtitleView(cues: cachedCues, countdownSeconds: $pauseCountdown)
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
    if audioFile.hasTranscription
      || FileManager.default.fileExists(atPath: audioFile.srtFileURL?.path ?? "")
    {
      if let srtCues = loadSRTFile() {
        cachedCues = srtCues
        hasCheckedCache = true

        // 修复不一致的标志位
        if !audioFile.hasTranscription {
          audioFile.hasTranscription = true
        }
        return
      } else {
        // 如果读取失败（例如文件被删），更新标志位
        if audioFile.hasTranscription {
          audioFile.hasTranscription = false
        }
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
    audioFile.hasTranscription = false

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
