import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let playPause = Self("playPause", default: .init(.space, modifiers: .option))
  static let rewind5s = Self("rewind5s", default: .init(.f, modifiers: .option))
  static let forward10s = Self("forward10s", default: .init(.g, modifiers: .option))
  static let setPointA = Self("setPointA", default: .init(.x, modifiers: .option))
  static let setPointB = Self("setPointB", default: .init(.c, modifiers: .option))
  static let clearLoop = Self("clearLoop", default: .init(.v, modifiers: .option))
  static let saveSegment = Self("saveSegment", default: .init(.b, modifiers: .option))
  static let previousSegment = Self(
    "previousSegment", default: .init(.leftArrow, modifiers: .option))
  static let nextSegment = Self("nextSegment", default: .init(.rightArrow, modifiers: .option))
  
  static let counterIncrement = Self("counterIncrement", default: .init(.a, modifiers: [.option, .control]))
  static let counterDecrement = Self("counterDecrement", default: .init(.d, modifiers: [.option, .control]))
  static let counterReset = Self("counterReset", default: .init(.r, modifiers: [.option, .control]))
}
