import Foundation

// MARK: - Loop Management

extension PlayerManager {
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
}
