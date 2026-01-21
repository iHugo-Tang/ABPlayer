import AVFoundation
import Foundation

// MARK: - Audio Engine Protocol

protocol PlayerEngineProtocol: Actor {
  var currentPlayer: AVPlayer? { get }

  func load(
    bookmarkData: Data,
    resumeTime: Double,
    onDurationLoaded: @MainActor @Sendable @escaping (Double) -> Void,
    onTimeUpdate: @MainActor @Sendable @escaping (Double) -> Void,
    onLoopCheck: @MainActor @Sendable @escaping (Double) -> Void,
    onPlaybackStateChange: @MainActor @Sendable @escaping (Bool) -> Void,
    onPlayerReady: @MainActor @Sendable @escaping (AVPlayer) -> Void
  ) async throws -> AVPlayerItem?

  func play() -> Bool
  func pause()
  func syncPauseState()
  func syncPlayState()
  func seek(to time: Double)
  func setVolume(_ volume: Float) async
  func teardown()
}
