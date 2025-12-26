import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let playPause = Self("playPause", default: .init(.space))
  static let rewind5s = Self("rewind5s", default: .init(.f))
  static let forward10s = Self("forward10s", default: .init(.g))
  static let setPointA = Self("setPointA", default: .init(.x))
  static let setPointB = Self("setPointB", default: .init(.c))
  static let clearLoop = Self("clearLoop", default: .init(.v))
  static let saveSegment = Self("saveSegment", default: .init(.b))
  static let previousSegment = Self("previousSegment", default: .init(.leftArrow))
  static let nextSegment = Self("nextSegment", default: .init(.rightArrow))
}
