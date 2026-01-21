import Foundation

// MARK: - Segment Management

extension PlayerManager {
  @discardableResult
  func saveCurrentSegment() -> LoopSegment? {
    guard let pointA, let pointB, pointB > pointA else {
      return nil
    }

    guard let audioFile = currentFile else {
      return nil
    }

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

  func selectPreviousSegment() {
    let segments = sortedSegments()
    guard !segments.isEmpty else { return }

    let currentIndex = currentSegmentIndex(in: segments)
    let newIndex = max(0, currentIndex - 1)
    let segment = segments[newIndex]
    apply(segment: segment)
  }

  func selectNextSegment() {
    let segments = sortedSegments()
    guard !segments.isEmpty else { return }

    let currentIndex = currentSegmentIndex(in: segments)
    let newIndex = min(segments.count - 1, currentIndex + 1)
    let segment = segments[newIndex]
    apply(segment: segment)
  }

  private func sortedSegments(descending: Bool = true) -> [LoopSegment] {
    guard let audioFile = currentFile else {
      return []
    }
    return audioFile.segments.sorted { first, second in
      descending ? first.startTime > second.startTime : first.startTime < second.startTime
    }
  }

  private func currentSegmentIndex(in segments: [LoopSegment]) -> Int {
    if let currentSegmentID,
      let index = segments.firstIndex(where: { $0.id == currentSegmentID })
    {
      return index
    }
    return 0
  }
}
