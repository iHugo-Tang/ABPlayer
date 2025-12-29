import AVFoundation
import Foundation
import Observation

// MARK: - Loop Mode

enum LoopMode: String, CaseIterable {
  case none
  case repeatOne  // 无限重播当前文件
  case repeatAll  // 重播当前目录
  case shuffle  // 随机播放当前目录

  var displayName: String {
    switch self {
    case .none: "Off"
    case .repeatOne: "Repeat One"
    case .repeatAll: "Repeat All"
    case .shuffle: "Shuffle"
    }
  }

  var iconName: String {
    switch self {
    case .none: "repeat"
    case .repeatOne: "repeat.1"
    case .repeatAll: "repeat"
    case .shuffle: "shuffle"
    }
  }
}

// MARK: - Observable UI State (MainActor)

@MainActor
@Observable
final class AudioPlayerManager {
  private let _engine = AudioPlayerEngine()

  var currentFile: AudioFile?
  var sessionTracker: SessionTracker?

  var isPlaying: Bool = false
  var currentTime: Double = 0
  var duration: Double = 0
  var volume: Float = 1.0

  var pointA: Double?
  var pointB: Double?

  /// Whether A-B looping should be active when a valid range is set.
  var isLoopEnabled: Bool = true

  /// Current loop mode for playback behavior
  var loopMode: LoopMode = .none

  /// Currently selected segment ID
  var currentSegmentID: UUID?

  /// Callback when a segment is saved (provides the saved segment)
  var onSegmentSaved: ((LoopSegment) -> Void)?

  /// Callback when playback ends (used for repeat all / shuffle)
  var onPlaybackEnded: ((AudioFile?) -> Void)?

  private var lastPersistedTime: Double = 0
  private var endOfFileObserver: Any?

  /// Whether A and B define a valid loop range.
  var hasValidLoopRange: Bool {
    guard let pointA, let pointB else {
      return false
    }

    return pointB > pointA
  }

  /// Whether the player is currently configured to loop (valid range + enabled).
  var isLooping: Bool {
    isLoopEnabled && hasValidLoopRange
  }

  deinit {
    _engine.teardownSync()
  }

  func cleanup() {
    if let observer = endOfFileObserver {
      NotificationCenter.default.removeObserver(observer)
      endOfFileObserver = nil
    }
  }

  // MARK: - Public API

  func load(audioFile: AudioFile, fromStart: Bool = false) async {
    // 使用缓存的时长立即显示 UI
    if let cached = audioFile.cachedDuration, cached > 0 {
      duration = cached
    }

    currentFile = audioFile
    currentTime = 0
    isPlaying = false
    clearLoop()
    lastPersistedTime = 0

    // Remove previous observer
    if let observer = endOfFileObserver {
      NotificationCenter.default.removeObserver(observer)
      endOfFileObserver = nil
    }

    let bookmarkData = audioFile.bookmarkData
    // 如果 fromStart 为 true，从0开始播放，否则使用保存的进度
    let resumeTime = fromStart ? 0 : audioFile.currentPlaybackPosition

    do {
      let playerItem = try await _engine.load(
        bookmarkData: bookmarkData,
        resumeTime: resumeTime,
        onDurationLoaded: { [weak self] loadedDuration in
          guard let self else { return }
          self.duration = loadedDuration
          audioFile.cachedDuration = loadedDuration
        },
        onTimeUpdate: { [weak self] seconds in
          guard let self else { return }
          self.handleTimeUpdate(seconds)
        },
        onLoopCheck: { [weak self] seconds in
          guard let self else { return }
          self.handleLoopCheck(seconds)
        }
      )

      // Setup end-of-file notification observer
      if let item = playerItem {
        self.endOfFileObserver = NotificationCenter.default.addObserver(
          forName: .AVPlayerItemDidPlayToEndTime,
          object: item,
          queue: .main
        ) { [weak self] _ in
          Task { @MainActor [weak self] in
            self?.handlePlaybackEnded()
          }
        }
      }

      // Restore position after load
      if resumeTime > 0 {
        currentTime = resumeTime
        lastPersistedTime = resumeTime
      }

      // Apply current volume
      await _engine.setVolume(volume)
    } catch {
      assertionFailure("Failed to load audio file: \(error)")
    }
  }

  /// Handle when a file finishes playing
  private func handlePlaybackEnded() {
    // Record completion stats
    if let file = currentFile {
      if file.playbackRecord == nil {
        file.playbackRecord = PlaybackRecord(audioFile: file)
      }
      file.playbackRecord?.lastPlayedAt = Date()
      file.playbackRecord?.completionCount += 1
    }

    switch loopMode {
    case .none:
      isPlaying = false

    case .repeatOne:
      // Restart the same file from beginning
      isPlaying = false
      seek(to: 0)
      play()

    case .repeatAll, .shuffle:
      // Notify ContentView to play next/random file
      onPlaybackEnded?(currentFile)
    }
  }

  func play(fromStart: Bool = false) {
    guard !isPlaying else { return }

    Task { [weak self] in
      guard let self else { return }
      if fromStart {
        seek(to: 0)
      }
      let success = await _engine.play()
      if success {
        self.isPlaying = true
        self.sessionTracker?.startSessionIfNeeded()
        // Update last played time
        if let file = self.currentFile {
          if file.playbackRecord == nil {
            file.playbackRecord = PlaybackRecord(audioFile: file)
          }
          file.playbackRecord?.lastPlayedAt = Date()
        }
      }
    }
  }

  func togglePlayPause() {
    if isPlaying {
      Task { [weak self] in
        guard let self else { return }
        await _engine.pause()
        self.isPlaying = false
        self.sessionTracker?.persistProgress()
      }
    } else {
      Task { [weak self] in
        guard let self else { return }
        let success = await _engine.play()
        if success {
          self.isPlaying = true
          self.sessionTracker?.startSessionIfNeeded()
          // Update last played time
          if let file = self.currentFile {
            if file.playbackRecord == nil {
              file.playbackRecord = PlaybackRecord(audioFile: file)
            }
            file.playbackRecord?.lastPlayedAt = Date()
          }
        }
      }
    }
  }

  func seek(to time: Double) {
    let maxTime: Double
    if duration > 0 {
      maxTime = duration
    } else {
      maxTime = time
    }

    let clampedTime = min(max(time, 0), maxTime)
    currentTime = clampedTime

    if clampedTime.isFinite && clampedTime >= 0 {
      currentFile?.currentPlaybackPosition = clampedTime
      lastPersistedTime = clampedTime
    }

    Task { [weak self] in
      guard let self else { return }
      await _engine.seek(to: clampedTime)
    }
  }

  func setVolume(_ volume: Float) {
    self.volume = volume
    Task {
      await _engine.setVolume(volume)
    }
  }

  func setPointA() {
    pointA = currentTime

    if let pointB, pointB <= currentTime {
      self.pointB = nil
    }
  }

  func setPointB() {
    if pointA == nil {
      pointA = currentTime
    }

    guard let pointA else { return }

    if currentTime <= pointA { return }

    pointB = currentTime
  }

  func clearLoop() {
    pointA = nil
    pointB = nil
  }

  func apply(segment: LoopSegment, autoPlay: Bool = true) {
    currentSegmentID = segment.id
    pointA = segment.startTime
    pointB = segment.endTime
    seek(to: segment.startTime)

    if autoPlay && !isPlaying {
      togglePlayPause()
    }
  }

  // MARK: - Segment Management

  /// Save the current A-B loop as a new segment
  /// Returns the newly created segment, or nil if no valid loop range exists
  @discardableResult
  func saveCurrentSegment() -> LoopSegment? {
    guard let pointA, let pointB, pointB > pointA else {
      return nil
    }

    guard let audioFile = currentFile else {
      return nil
    }

    // Check if segment already exists
    if let existingSegment = audioFile.segments.first(
      where: { $0.startTime == pointA && $0.endTime == pointB }
    ) {
      currentSegmentID = existingSegment.id
      return existingSegment
    }

    let nextIndex = (audioFile.segments.map(\.index).max() ?? -1) + 1
    let label = "Segment \(nextIndex + 1)"

    let segment = LoopSegment(
      label: label,
      startTime: pointA,
      endTime: pointB,
      index: nextIndex,
      audioFile: audioFile
    )

    audioFile.segments.append(segment)
    currentSegmentID = segment.id
    onSegmentSaved?(segment)
    return segment
  }

  /// Get sorted segments for current file
  private func sortedSegments(descending: Bool = true) -> [LoopSegment] {
    guard let audioFile = currentFile else {
      return []
    }
    return audioFile.segments.sorted { first, second in
      descending ? first.startTime > second.startTime : first.startTime < second.startTime
    }
  }

  /// Find the current segment index in the sorted list
  private func currentSegmentIndex(in segments: [LoopSegment]) -> Int {
    if let currentSegmentID,
      let index = segments.firstIndex(where: { $0.id == currentSegmentID })
    {
      return index
    }
    return 0
  }

  /// Select the previous segment in the list
  func selectPreviousSegment() {
    let segments = sortedSegments()
    guard !segments.isEmpty else { return }

    let currentIndex = currentSegmentIndex(in: segments)
    let newIndex = max(0, currentIndex - 1)
    let segment = segments[newIndex]
    apply(segment: segment)
  }

  /// Select the next segment in the list
  func selectNextSegment() {
    let segments = sortedSegments()
    guard !segments.isEmpty else { return }

    let currentIndex = currentSegmentIndex(in: segments)
    let newIndex = min(segments.count - 1, currentIndex + 1)
    let segment = segments[newIndex]
    apply(segment: segment)
  }

  // MARK: - Private Handlers

  private func handleTimeUpdate(_ seconds: Double) {
    currentTime = seconds

    // Persist playback time periodically (every 1 second)
    if abs(seconds - lastPersistedTime) >= 1 {
      currentFile?.currentPlaybackPosition = seconds
      lastPersistedTime = seconds
    }

    // Track listening time
    if isPlaying {
      sessionTracker?.addListeningTime(0.03)
    }
  }

  private func handleLoopCheck(_ seconds: Double) {
    guard isLooping,
      let pointA,
      let pointB
    else { return }

    if seconds >= pointB {
      seek(to: pointA)
    }
  }
}

// MARK: - Audio Engine Actor (Background)

actor AudioPlayerEngine {
  private var player: AVPlayer?
  private var timeObserverToken: Any?
  private var currentScopedURL: URL?
  private var lastPersistedTime: Double = 0
  private var lastPlaybackTick: Double?

  func load(
    bookmarkData: Data,
    resumeTime: Double,
    onDurationLoaded: @MainActor @Sendable @escaping (Double) -> Void,
    onTimeUpdate: @MainActor @Sendable @escaping (Double) -> Void,
    onLoopCheck: @MainActor @Sendable @escaping (Double) -> Void
  ) async throws -> AVPlayerItem? {
    teardownPlayerInternal()

    var isStale = false
    let url = try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )

    guard url.startAccessingSecurityScopedResource() else {
      assertionFailure("Unable to access security scoped resource")
      return nil
    }

    currentScopedURL = url

    let asset = AVURLAsset(url: url)

    // Load duration asynchronously (non-blocking)
    let time = try await asset.load(.duration)
    let assetDuration = CMTimeGetSeconds(time)
    let finalDuration = (assetDuration.isFinite && assetDuration > 0) ? assetDuration : 0

    await onDurationLoaded(finalDuration)

    let item = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: item)
    player.volume = 1.0  // Will be updated by manager
    self.player = player

    lastPlaybackTick = nil
    lastPersistedTime = 0

    // Resume playback position
    if resumeTime > 0 {
      let target = CMTime(seconds: resumeTime, preferredTimescale: 600)
      await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
      lastPersistedTime = resumeTime
    }

    addTimeObserver(onTimeUpdate: onTimeUpdate, onLoopCheck: onLoopCheck)
    return item
  }

  func play() -> Bool {
    guard let player else { return false }
    player.play()
    lastPlaybackTick = CMTimeGetSeconds(player.currentTime())
    return true
  }

  func pause() {
    player?.pause()
    lastPlaybackTick = nil
  }

  func seek(to time: Double) {
    guard let player else { return }
    let target = CMTime(seconds: time, preferredTimescale: 600)
    player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    lastPersistedTime = time
  }

  func setVolume(_ volume: Float) {
    player?.volume = volume
  }

  nonisolated func teardownSync() {
    Task { await self.teardownPlayerInternal() }
  }

  private func teardownPlayerInternal() {
    if let player, let timeObserverToken {
      player.removeTimeObserver(timeObserverToken)
    }
    timeObserverToken = nil

    if let currentScopedURL {
      currentScopedURL.stopAccessingSecurityScopedResource()
    }
    currentScopedURL = nil
    player = nil
    lastPersistedTime = 0
    lastPlaybackTick = nil
  }

  private func addTimeObserver(
    onTimeUpdate: @MainActor @Sendable @escaping (Double) -> Void,
    onLoopCheck: @MainActor @Sendable @escaping (Double) -> Void
  ) {
    guard let player else { return }

    let interval = CMTime(seconds: 0.03, preferredTimescale: 600)

    timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      time in

      let seconds = CMTimeGetSeconds(time)

      Task { @MainActor in
        guard seconds.isFinite && seconds >= 0 else { return }
        onTimeUpdate(seconds)
        onLoopCheck(seconds)
      }
    }
  }
}
