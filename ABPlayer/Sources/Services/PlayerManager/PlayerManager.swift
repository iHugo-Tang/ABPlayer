import AVFoundation
import Foundation
import OSLog
import Observation

// MARK: - Observable UI State (MainActor)

@MainActor
@Observable
final class PlayerManager {
  private let _engine: any PlayerEngineProtocol

  init(engine: (any PlayerEngineProtocol)? = nil) {
    self._engine = engine ?? PlayerEngine()
  }

  private(set) weak var player: AVPlayer?

  private var loadingFileID: UUID?

  var currentFile: ABFile?
  var selectedFile: ABFile?
  var sessionTracker: SessionTracker?
  
  var lastSelectedAudioFileID: String? {
    get { UserDefaults.standard.string(forKey: "lastSelectedAudioFileID") }
    set { UserDefaults.standard.set(newValue, forKey: "lastSelectedAudioFileID") }
  }
  
  var lastFolderID: String? {
    get { UserDefaults.standard.string(forKey: "lastFolderID") }
    set { UserDefaults.standard.set(newValue, forKey: "lastFolderID") }
  }

  var avPlayer: AVPlayer? {
    get async { await _engine.currentPlayer }
  }

  var isPlaying: Bool = false
  var currentTime: Double = 0
  var duration: Double = 0
  var volume: Float = 1.0

  var pointA: Double?
  var pointB: Double?

  var isLoopEnabled: Bool = true

  var playbackQueue = PlaybackQueue()

  var loopMode: PlaybackQueue.LoopMode {
    get { playbackQueue.loopMode }
    set { playbackQueue.loopMode = newValue }
  }

  var currentSegmentID: UUID?

  var onSegmentSaved: ((LoopSegment) -> Void)?

  var onPlaybackEnded: ((ABFile?) -> Void)?

  private var lastPersistedTime: Double = 0
  private var endOfFileObserver: Any?
  private var loadAudioTask: Task<Void, Never>?

  var hasValidLoopRange: Bool {
    guard let pointA, let pointB else {
      return false
    }

    return pointB > pointA
  }

  var isLooping: Bool {
    isLoopEnabled && hasValidLoopRange
  }

  func clearPlayer()async {
    player = nil
    await _engine.teardown()
  }

  deinit {
    Task { [weak self] in
      await self?.clearPlayer()
    }
  }

  func cleanup() {
    if let observer = endOfFileObserver {
      NotificationCenter.default.removeObserver(observer)
      endOfFileObserver = nil
    }
  }

  // MARK: - Public API

  func load(audioFile: ABFile, fromStart: Bool = false) async {
    guard audioFile.isBookmarkValid else {
      Logger.audio.error("Load aborted: Bookmark invalid or file missing for \(audioFile.displayName)")
      return
    }

    if let cached = audioFile.cachedDuration, cached > 0 {
      duration = cached
    }

    let fileID = audioFile.id
    loadingFileID = fileID
    audioFile.loadError = nil

    currentFile = audioFile
    currentTime = 0
    isPlaying = false
    clearLoop()
    lastPersistedTime = 0

    if let observer = endOfFileObserver {
      NotificationCenter.default.removeObserver(observer)
      endOfFileObserver = nil
    }

    let bookmarkData = audioFile.bookmarkData
    let resumeTime = fromStart ? 0 : audioFile.currentPlaybackPosition

    do {
      let playerItem = try await _engine.load(
        bookmarkData: bookmarkData,
        resumeTime: resumeTime,
        onDurationLoaded: { [weak self] loadedDuration in
          guard let self, self.loadingFileID == fileID else { return }
          self.duration = loadedDuration
          audioFile.cachedDuration = loadedDuration
        },
        onTimeUpdate: { [weak self] seconds in
          guard let self, self.currentFile?.id == fileID else { return }
          self.handleTimeUpdate(seconds)
        },
        onLoopCheck: { [weak self] seconds in
          guard let self, self.currentFile?.id == fileID else { return }
          self.handleLoopCheck(seconds)
        },
        onPlaybackStateChange: { [weak self] isPlaying in
          guard let self, self.currentFile?.id == fileID else { return }
          self.handlePlaybackStateUpdate(isPlaying)
        },
        onPlayerReady: { [weak self] player in
          guard let self, self.loadingFileID == fileID else { return }
          self.player = player
        }
      )

      guard loadingFileID == fileID else {
        return
      }

      if let item = playerItem {
        self.endOfFileObserver = NotificationCenter.default.addObserver(
          forName: .AVPlayerItemDidPlayToEndTime,
          object: item,
          queue: .main
        ) { [weak self] _ in
          Task { @MainActor [weak self] in
            guard let self, self.currentFile?.id == fileID else { return }
            self.handlePlaybackEnded()
          }
        }
      }

      if resumeTime > 0 {
        currentTime = resumeTime
        lastPersistedTime = resumeTime
      }

      await _engine.setVolume(volume)
    } catch {
      if loadingFileID == fileID {
        audioFile.loadError = error.localizedDescription
        Logger.audio.error("Failed to load audio file: \(error, privacy: .public)")
      }
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
        if let file = self.currentFile {
          if file.playbackRecord == nil {
            file.playbackRecord = PlaybackRecord(audioFile: file)
          }
          file.playbackRecord?.lastPlayedAt = Date()
        }
      }
    }
  }

  func pause() {
    guard isPlaying else { return }

    Task { [weak self] in
      guard let self else { return }
      await _engine.pause()
      self.isPlaying = false
      self.sessionTracker?.persistProgress()
    }
  }

  func togglePlayPause() {
    let startTime = CFAbsoluteTimeGetCurrent()
    Logger.audio.debug("[Performance] togglePlayPause() called, isPlaying: \(self.isPlaying)")

    if isPlaying {
      isPlaying = false
      let uiUpdateTime = CFAbsoluteTimeGetCurrent()
      Logger.audio.debug(
        "[Performance] isPlaying = false (immediate) after \((uiUpdateTime - startTime) * 1000)ms")

      player?.pause()
      let pauseTime = CFAbsoluteTimeGetCurrent()
      Logger.audio.debug(
        "[Performance] player.pause() (sync) completed after \((pauseTime - uiUpdateTime) * 1000)ms"
      )

      Logger.audio.debug(
        "[Performance] User perceives pause after \((CFAbsoluteTimeGetCurrent() - startTime) * 1000)ms"
      )

      Task { [weak self] in
        guard let self else { return }
        await _engine.syncPauseState()
        self.sessionTracker?.persistProgress()
        Logger.audio.debug(
          "[Performance] Background sync completed after \((CFAbsoluteTimeGetCurrent() - startTime) * 1000)ms"
        )
      }
    } else {
      isPlaying = true
      let uiUpdateTime = CFAbsoluteTimeGetCurrent()
      Logger.audio.debug(
        "[Performance] isPlaying = true (immediate) after \((uiUpdateTime - startTime) * 1000)ms")

      player?.play()
      let playTime = CFAbsoluteTimeGetCurrent()
      Logger.audio.debug(
        "[Performance] player.play() (sync) completed after \((playTime - uiUpdateTime) * 1000)ms")

      Logger.audio.debug(
        "[Performance] User perceives play after \((CFAbsoluteTimeGetCurrent() - startTime) * 1000)ms"
      )

      Task { [weak self] in
        guard let self else { return }
        await _engine.syncPlayState()
        if let file = self.currentFile {
          if file.playbackRecord == nil {
            file.playbackRecord = PlaybackRecord(audioFile: file)
          }
          file.playbackRecord?.lastPlayedAt = Date()
        }
        Logger.audio.debug(
          "[Performance] Background sync completed after \((CFAbsoluteTimeGetCurrent() - startTime) * 1000)ms"
        )
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

  // MARK: - Internal Handlers

  fileprivate func handleTimeUpdate(_ seconds: Double) {
    currentTime = seconds

    if abs(seconds - lastPersistedTime) >= 1 {
      currentFile?.currentPlaybackPosition = seconds
      lastPersistedTime = seconds
    }

    if isPlaying {
      sessionTracker?.addListeningTime(0.1)
    }
  }

  fileprivate func handleLoopCheck(_ seconds: Double) {
    guard isLooping,
      let pointA,
      let pointB
    else { return }

    if seconds >= pointB {
      seek(to: pointA)
    }
  }

  fileprivate func handlePlaybackStateUpdate(_ isPlaying: Bool) {
    guard self.isPlaying != isPlaying else { return }

    self.isPlaying = isPlaying

    if isPlaying {
      if let file = currentFile {
        if file.playbackRecord == nil {
          file.playbackRecord = PlaybackRecord(audioFile: file)
        }
        file.playbackRecord?.lastPlayedAt = Date()
      }
    } else {
      sessionTracker?.persistProgress()
    }
  }

  fileprivate func handlePlaybackEnded() {
    if let file = currentFile {
      if file.playbackRecord == nil {
        file.playbackRecord = PlaybackRecord(audioFile: file)
      }
      file.playbackRecord?.lastPlayedAt = Date()
      file.playbackRecord?.completionCount += 1
    }

    switch playbackQueue.loopMode {
    case .none:
      isPlaying = false

    case .repeatOne:
      isPlaying = false
      seek(to: 0)
      play()

    case .repeatAll, .shuffle, .autoPlayNext:
      onPlaybackEnded?(currentFile)
    }
  }

  // MARK: - File Selection

  func selectFile(
    _ file: ABFile,
    fromStart: Bool = false,
    debounce: Bool = true
  ) async {
    lastSelectedAudioFileID = file.id.uuidString
    lastFolderID = file.folder?.id.uuidString

    playbackQueue.setCurrentFile(file)

    if currentFile?.id == file.id,
      currentFile != nil
    {
      currentFile = file
      return
    }

    selectedFile = file

    loadAudioTask?.cancel()
    if debounce {
      loadAudioTask = Task {
        await clearPlayer()
        if !Task.isCancelled {
          await load(audioFile: file, fromStart: fromStart)
        }
      }
    } else {
      await load(audioFile: file, fromStart: fromStart)
    }
  }

  func playFile(
    _ file: ABFile,
    fromStart: Bool = false
  ) async {
    await selectFile(
      file,
      fromStart: fromStart,
      debounce: false
    )
    play()
  }

  func playNext() async {
    guard let file = playbackQueue.playNext() else {
      return
    }
    let isPlaying = isPlaying
    // TODO: refactor it：always play from start and show a button to restore playing progress
    await selectFile(
      file,
      fromStart: true,
      debounce: false
    )
    if isPlaying {
      play()
    }
  }

  func playPrev() async {
    guard let file = playbackQueue.playPrev() else {
      return
    }
    await selectFile(
      file,
      fromStart: true,
      debounce: false
    )
    if isPlaying {
      play()
    }
  }
}
