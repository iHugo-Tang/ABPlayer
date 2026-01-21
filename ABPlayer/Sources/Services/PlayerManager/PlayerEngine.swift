import AVFoundation
import CoreMedia
import Foundation
import OSLog

// MARK: - Audio Engine Actor (Background)

actor PlayerEngine: PlayerEngineProtocol {
  private var player: AVPlayer? {
    didSet {
      Logger.audio.debug(
        "[AudioPlayerEngine] player set to: \(self.player != nil ? String(describing: Unmanaged.passUnretained(self.player!).toOpaque()) : "nil")"
      )
    }
  }
  private var timeObserverToken: Any?
  private var currentScopedURL: URL?
  private var currentAsset: AVURLAsset?
  private var lastPersistedTime: Double = 0
  private var lastPlaybackTick: Double?
  private var rateObservation: NSKeyValueObservation?

  private var loadingID: UUID?

  var currentPlayer: AVPlayer? { player }

  func load(
    bookmarkData: Data,
    resumeTime: Double,
    onDurationLoaded: @MainActor @Sendable @escaping (Double) -> Void,
    onTimeUpdate: @MainActor @Sendable @escaping (Double) -> Void,
    onLoopCheck: @MainActor @Sendable @escaping (Double) -> Void,
    onPlaybackStateChange: @MainActor @Sendable @escaping (Bool) -> Void,
    onPlayerReady: @MainActor @Sendable @escaping (AVPlayer) -> Void
  ) async throws -> AVPlayerItem? {
    let myLoadID = UUID()
    loadingID = myLoadID

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
    currentAsset = asset

    let time = try await asset.load(.duration)

    guard loadingID == myLoadID else {
      Logger.audio.debug(
        "[AudioPlayerEngine] Loading cancelled after duration load (id: \(myLoadID))")
      url.stopAccessingSecurityScopedResource()
      return nil
    }

    let assetDuration = CMTimeGetSeconds(time)
    let finalDuration = (assetDuration.isFinite && assetDuration > 0) ? assetDuration : 0

    await onDurationLoaded(finalDuration)

    let item = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: item)
    Logger.audio.debug(
      "[AudioPlayerEngine] 🆕 Created new player: \(String(describing: Unmanaged.passUnretained(player).toOpaque())) item: \(asset.url)"
    )
    player.volume = 1.0
    self.player = player

    await onPlayerReady(player)

    guard loadingID == myLoadID else {
      Logger.audio.debug(
        "[AudioPlayerEngine] Loading cancelled after onPlayerReady (id: \(myLoadID))")
      teardownPlayerInternal()
      return nil
    }

    lastPlaybackTick = nil
    lastPersistedTime = 0

    if resumeTime > 0 {
      let target = CMTime(seconds: resumeTime, preferredTimescale: 600)
      await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
      lastPersistedTime = resumeTime
    }

    addTimeObserver(onTimeUpdate: onTimeUpdate, onLoopCheck: onLoopCheck)

    rateObservation = player.observe(\.rate) { player, _ in
      Task { @MainActor in
        onPlaybackStateChange(player.rate != 0 && player.error == nil)
      }
    }

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

  func syncPauseState() {
    lastPlaybackTick = nil
  }

  func syncPlayState() {
    guard let player else { return }
    lastPlaybackTick = CMTimeGetSeconds(player.currentTime())
  }

  func seek(to time: Double) {
    guard let player else { return }
    let target = CMTime(seconds: time, preferredTimescale: 600)
    player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    lastPersistedTime = time
  }

  func setVolume(_ volume: Float) async {
    guard let player = player,
      let currentItem = player.currentItem
    else { return }

    if volume <= 1.0 {
      player.volume = volume
      await MainActor.run { currentItem.audioMix = nil }
    } else {
      player.volume = 1.0

      guard let asset = currentAsset,
        let audioTracks = try? await asset.loadTracks(withMediaType: .audio),
        let audioTrack = audioTracks.first
      else { return }

      let audioMix = AVMutableAudioMix()
      let params = AVMutableAudioMixInputParameters(track: audioTrack)
      params.setVolume(volume, at: .zero)
      audioMix.inputParameters = [params]
      await MainActor.run { currentItem.audioMix = audioMix }
    }
  }

  func teardown() {
      self.teardownPlayerInternal()
  }

  private func teardownPlayerInternal() {
    if let player {
      Logger.audio.debug(
        "[AudioPlayerEngine] 🗑️ Tearing down player: \(String(describing: Unmanaged.passUnretained(player).toOpaque()))"
      )
      player.pause()
      player.replaceCurrentItem(with: nil)
      if let timeObserverToken {
        player.removeTimeObserver(timeObserverToken)
      }
    } else {
      Logger.audio.debug(
        "[AudioPlayerEngine] 🗑️ teardownPlayerInternal() called but player is already nil")
    }
    timeObserverToken = nil

    rateObservation?.invalidate()
    rateObservation = nil

    if let currentScopedURL {
      currentScopedURL.stopAccessingSecurityScopedResource()
    }
    currentScopedURL = nil
    currentAsset = nil
    player = nil
    lastPersistedTime = 0
    lastPlaybackTick = nil
    Logger.audio.debug("[AudioPlayerEngine] ✅ Teardown complete, player set to nil")
  }

  private func addTimeObserver(
    onTimeUpdate: @MainActor @Sendable @escaping (Double) -> Void,
    onLoopCheck: @MainActor @Sendable @escaping (Double) -> Void
  ) {
    guard let player else { return }

    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)

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
