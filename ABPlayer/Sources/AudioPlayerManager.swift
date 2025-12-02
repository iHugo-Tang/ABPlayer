import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class AudioPlayerManager {
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var currentScopedURL: URL?

    var currentFile: AudioFile?

    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0

    var pointA: Double?
    var pointB: Double?

    var isLooping: Bool {
        guard let pointA, let pointB else {
            return false
        }

        return pointB > pointA
    }

    deinit {
        Task { [weak self] in
            await self?.teardownPlayer()
        }
    }

    func load(audioFile: AudioFile) {
        do {
            let url = try resolveBookmark(from: audioFile)
            preparePlayer(with: url)
            currentFile = audioFile
        } catch {
            assertionFailure("Failed to load audio file: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player else {
            return
        }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(to time: Double) {
        guard let player else {
            return
        }

        let clampedTime = min(max(time, 0), duration)
        let target = CMTime(seconds: clampedTime, preferredTimescale: 600)

        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clampedTime
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

        guard let pointA else {
            return
        }

        if currentTime <= pointA {
            return
        }

        pointB = currentTime
    }

    func clearLoop() {
        pointA = nil
        pointB = nil
    }

    func apply(segment: LoopSegment, autoPlay: Bool = true) {
        pointA = segment.startTime
        pointB = segment.endTime
        seek(to: segment.startTime)

        if autoPlay && !isPlaying {
            togglePlayPause()
        }
    }

    private func resolveBookmark(from audioFile: AudioFile) throws -> URL {
        var isStale = false

        let url = try URL(
            resolvingBookmarkData: audioFile.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            // For now we rely on the stale bookmark still being resolvable.
            // Callers can choose to recreate the bookmark if needed.
        }

        return url
    }

    private func preparePlayer(with url: URL) {
        teardownPlayer()

        guard url.startAccessingSecurityScopedResource() else {
            assertionFailure("Unable to access security scoped resource")
            return
        }

        currentScopedURL = url

        let asset = AVURLAsset(url: url)
        let assetDuration = CMTimeGetSeconds(asset.duration)

        if assetDuration.isFinite && assetDuration > 0 {
            duration = assetDuration
        } else {
            duration = 0
        }

        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)

        self.player = player
        currentTime = 0
        isPlaying = false
        clearLoop()

        addTimeObserver()
    }

    private func addTimeObserver() {
        guard let player else {
            return
        }

        let interval = CMTime(seconds: 0.03, preferredTimescale: 600)

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else {
                return
            }

            let seconds = CMTimeGetSeconds(time)

            if seconds.isFinite && seconds >= 0 {
                currentTime = seconds
            }

            guard isLooping,
                  let pointA,
                  let pointB else {
                return
            }

            if seconds >= pointB {
                let target = CMTime(seconds: pointA, preferredTimescale: 600)

                player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }

    private func teardownPlayer() {
        if let player, let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }

        timeObserverToken = nil

        if let currentScopedURL {
            currentScopedURL.stopAccessingSecurityScopedResource()
        }

        currentScopedURL = nil
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        clearLoop()
    }
}


