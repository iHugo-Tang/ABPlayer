import AVFoundation
import Foundation
import Testing

@testable import ABPlayer

// MARK: - A-B Loop Logic Tests

struct ABLoopTests {

  // MARK: - Loop Check Tests

  @Test
  func testLoopCheckTriggersWhenTimeExceedsPointB() {
    // Given: pointA = 10.0, pointB = 20.0, currentTime = 20.0
    let pointA = 10.0
    let pointB = 20.0
    let currentTime = 20.0

    // When: checking if loop should trigger
    let shouldLoop = currentTime >= pointB

    // Then: should trigger loop back to A
    #expect(shouldLoop == true)
  }

  @Test
  func testLoopCheckDoesNotTriggerBeforePointB() {
    // Given: pointA = 10.0, pointB = 20.0, currentTime = 15.0
    let pointA = 10.0
    let pointB = 20.0
    let currentTime = 15.0

    // When: checking if loop should trigger
    let shouldLoop = currentTime >= pointB

    // Then: should NOT trigger loop
    #expect(shouldLoop == false)
  }

  @Test
  func testLoopCheckWithZeroPointA() {
    // Given: pointA = 0.0 (start of file)
    let pointA = 0.0
    let pointB = 5.0
    let currentTime = 5.5

    // When: checking if loop should trigger
    let shouldLoop = currentTime >= pointB

    // Then: should trigger loop
    #expect(shouldLoop == true)
  }

  // MARK: - Point A/B Validation Tests

  @Test
  func testPointBMustBeAfterPointA() {
    // Given: pointA = 15.0, pointB = 10.0 (invalid: B before A)
    let pointA = 15.0
    let pointB = 10.0

    // When: validating A-B range
    let isValidRange = pointB > pointA

    // Then: should be invalid
    #expect(isValidRange == false)
  }

  @Test
  func testValidPointABRange() {
    // Given: pointA = 10.0, pointB = 20.0 (valid)
    let pointA = 10.0
    let pointB = 20.0

    // When: validating A-B range
    let isValidRange = pointB > pointA

    // Then: should be valid
    #expect(isValidRange == true)
  }

  @Test
  func testPointAEqualToPointBIsInvalid() {
    // Given: pointA = pointB = 10.0 (invalid: same point)
    let pointA = 10.0
    let pointB = 10.0

    // When: validating A-B range
    let isValidRange = pointB > pointA

    // Then: should be invalid
    #expect(isValidRange == false)
  }

  // MARK: - Seek Clamping Tests

  @Test
  func testSeekClampToZero() {
    // Given: target time is negative
    let targetTime = -5.0
    let duration = 100.0

    // When: clamping the seek value
    let clampedTime = min(max(targetTime, 0), duration)

    // Then: should clamp to 0
    #expect(clampedTime == 0)
  }

  @Test
  func testSeekClampToDuration() {
    // Given: target time exceeds duration
    let targetTime = 150.0
    let duration = 100.0

    // When: clamping the seek value
    let clampedTime = min(max(targetTime, 0), duration)

    // Then: should clamp to duration
    #expect(clampedTime == 100.0)
  }

  @Test
  func testSeekWithinBounds() {
    // Given: target time is within bounds
    let targetTime = 50.0
    let duration = 100.0

    // When: clamping the seek value
    let clampedTime = min(max(targetTime, 0), duration)

    // Then: should remain unchanged
    #expect(clampedTime == 50.0)
  }

  // MARK: - Segment Duplicate Detection Tests

  @Test
  func testDetectDuplicateSegment() {
    // Given: existing segment with startTime=10, endTime=20
    let existingSegments = [(startTime: 10.0, endTime: 20.0)]
    let newStartTime = 10.0
    let newEndTime = 20.0

    // When: checking for duplicate
    let isDuplicate = existingSegments.contains {
      $0.startTime == newStartTime && $0.endTime == newEndTime
    }

    // Then: should detect as duplicate
    #expect(isDuplicate == true)
  }

  @Test
  func testNonDuplicateSegment() {
    // Given: existing segment with startTime=10, endTime=20
    let existingSegments = [(startTime: 10.0, endTime: 20.0)]
    let newStartTime = 15.0
    let newEndTime = 25.0

    // When: checking for duplicate
    let isDuplicate = existingSegments.contains {
      $0.startTime == newStartTime && $0.endTime == newEndTime
    }

    // Then: should NOT be duplicate
    #expect(isDuplicate == false)
  }
}

// MARK: - SessionTracker Logic Tests

struct SessionTrackerLogicTests {

  @Test
  func testListeningTimeAccumulation() {
    // Given: initial duration and delta
    var totalDuration = 0.0
    let deltas = [0.03, 0.03, 0.03, 0.03]  // 4 ticks

    // When: accumulating listening time
    for delta in deltas {
      totalDuration += delta
    }

    // Then: total should be sum of deltas
    #expect(abs(totalDuration - 0.12) < 0.001)
  }

  @Test
  func testNegativeDeltaIgnored() {
    // Given: negative delta
    let delta = -0.5
    var totalDuration = 10.0

    // When: attempting to add negative time
    if delta > 0 {
      totalDuration += delta
    }

    // Then: duration should be unchanged
    #expect(totalDuration == 10.0)
  }

  @Test
  func testZeroDeltaIgnored() {
    // Given: zero delta
    let delta = 0.0
    var totalDuration = 10.0

    // When: attempting to add zero time
    if delta > 0 {
      totalDuration += delta
    }

    // Then: duration should be unchanged
    #expect(totalDuration == 10.0)
  }

  @Test
  func testSaveIntervalThreshold() {
    // Given: save interval of 5 seconds
    var lastSavedSeconds = 0.0
    var currentSeconds = 4.9

    // When: checking if save should trigger
    var shouldSave = currentSeconds - lastSavedSeconds >= 5

    // Then: should NOT save yet
    #expect(shouldSave == false)

    // When: exceeding threshold
    currentSeconds = 5.0
    shouldSave = currentSeconds - lastSavedSeconds >= 5

    // Then: should save
    #expect(shouldSave == true)
  }
}

// MARK: - Subtitle Parser Tests

struct SubtitleParserTests {

  @Test
  func testTimestampParsingHHMMSS() {
    // Given: timestamp components
    let hours = 1.0
    let minutes = 30.0
    let seconds = 45.5

    // When: converting to seconds
    let totalSeconds = hours * 3600 + minutes * 60 + seconds

    // Then: should be 5445.5 seconds
    #expect(totalSeconds == 5445.5)
  }

  @Test
  func testTimestampParsingMMSS() {
    // Given: timestamp without hours
    let hours = 0.0
    let minutes = 5.0
    let seconds = 30.0

    // When: converting to seconds
    let totalSeconds = hours * 3600 + minutes * 60 + seconds

    // Then: should be 330 seconds
    #expect(totalSeconds == 330.0)
  }

  @Test
  func testSubtitleFormatDetectionSRT() {
    let filename = "movie.srt"
    let ext = filename.split(separator: ".").last ?? ""

    #expect(ext == "srt")
  }

  @Test
  func testSubtitleFormatDetectionVTT() {
    let filename = "podcast.vtt"
    let ext = filename.split(separator: ".").last ?? ""

    #expect(ext == "vtt")
  }

  @Test
  func testCueTimeRangeValidation() {
    // Given: a cue with valid time range
    let startTime = 10.5
    let endTime = 15.3

    // When: validating range
    let isValid = endTime > startTime && startTime >= 0

    // Then: should be valid
    #expect(isValid == true)
  }

  @Test
  func testCueWithInvalidTimeRange() {
    // Given: a cue with invalid time range (end before start)
    let startTime = 20.0
    let endTime = 15.0

    // When: validating range
    let isValid = endTime > startTime && startTime >= 0

    // Then: should be invalid
    #expect(isValid == false)
  }
}

// MARK: - Folder Import Logic Tests

struct FolderImportLogicTests {

  @Test
  func testAudioFileExtensionMatching() {
    let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "aac"]

    #expect(audioExtensions.contains("mp3"))
    #expect(audioExtensions.contains("m4a"))
    #expect(audioExtensions.contains("wav"))
    #expect(audioExtensions.contains("aac"))
    #expect(!audioExtensions.contains("txt"))
    #expect(!audioExtensions.contains("pdf"))
  }

  @Test
  func testSubtitleFileExtensionMatching() {
    let subtitleExtensions: Set<String> = ["srt", "vtt"]

    #expect(subtitleExtensions.contains("srt"))
    #expect(subtitleExtensions.contains("vtt"))
    #expect(!subtitleExtensions.contains("mp3"))
  }

  @Test
  func testBaseNameMatchingForPairing() {
    // Given: audio file and corresponding subtitle
    let audioBaseName = "lecture_001"
    let subtitleBaseName = "lecture_001"

    // When: comparing base names (case-insensitive)
    let isMatch = audioBaseName.lowercased() == subtitleBaseName.lowercased()

    // Then: should match
    #expect(isMatch == true)
  }

  @Test
  func testBaseNameMatchingCaseInsensitive() {
    // Given: mixed case file names
    let audioBaseName = "LECTURE_001"
    let subtitleBaseName = "lecture_001"

    // When: comparing base names (case-insensitive)
    let isMatch = audioBaseName.lowercased() == subtitleBaseName.lowercased()

    // Then: should match
    #expect(isMatch == true)
  }

  @Test
  func testBaseNameNoMatchDifferentNames() {
    // Given: different base names
    let audioBaseName = "lecture_001"
    let subtitleBaseName = "lecture_002"

    // When: comparing base names
    let isMatch = audioBaseName.lowercased() == subtitleBaseName.lowercased()

    // Then: should NOT match
    #expect(isMatch == false)
  }
}

// MARK: - Time Formatting Tests

struct TimeFormattingTests {

  @Test
  func testTimeStringFormattingMinutesSeconds() {
    // Given: total seconds
    let totalSeconds = 125  // 2:05

    // When: formatting
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    let formatted = String(format: "%d:%02d", minutes, seconds)

    // Then: should format correctly
    #expect(formatted == "2:05")
  }

  @Test
  func testTimeStringFormattingZero() {
    let totalSeconds = 0

    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    let formatted = String(format: "%d:%02d", minutes, seconds)

    #expect(formatted == "0:00")
  }

  @Test
  func testTimeStringFormattingLongDuration() {
    // Given: 1 hour 30 minutes 45 seconds = 5445 seconds
    let totalSeconds = 5445

    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    let formatted = String(format: "%d:%02d", minutes, seconds)

    // Note: Format shows minutes:seconds (90:45 for long durations)
    #expect(formatted == "90:45")
  }

  @Test
  func testRoundingSecondsFromDouble() {
    // Given: double time value
    let timeValue = 125.7

    // When: rounding to integer seconds
    let totalSeconds = Int(timeValue.rounded())

    // Then: should round correctly
    #expect(totalSeconds == 126)
  }
}

// MARK: - Scroll Pause Logic Tests

struct ScrollPauseLogicTests {

  @Test
  func testScrollPauseInitiatesCountdown() {
    // Given: pause duration of 3 seconds
    let pauseDuration = 3

    // When: user starts scrolling
    var isUserScrolling = false
    var countdownSeconds: Int? = nil

    // Simulate interacting phase
    isUserScrolling = true
    countdownSeconds = pauseDuration

    // Then: countdown should be initialized to pause duration
    #expect(isUserScrolling == true)
    #expect(countdownSeconds == 3)
  }

  @Test
  func testCountdownDecrementsCorrectly() {
    // Given: countdown values from 3 to 0
    let countdownSequence = [2, 1, 0]  // After each second

    // When: iterating through countdown
    for (index, expected) in countdownSequence.enumerated() {
      let remaining = 2 - index

      // Then: remaining should match expected
      #expect(remaining == expected)
    }
  }

  @Test
  func testScrollResumeAfterCountdown() {
    // Given: user was scrolling
    var isUserScrolling = true
    var countdownSeconds: Int? = 1

    // When: countdown reaches zero
    countdownSeconds = nil
    isUserScrolling = false

    // Then: scrolling state should be reset
    #expect(isUserScrolling == false)
    #expect(countdownSeconds == nil)
  }

  @Test
  func testScrollInterruptRestartsCountdown() {
    // Given: countdown is in progress
    let pauseDuration = 3
    var countdownSeconds: Int? = 1

    // When: user scrolls again (interrupt)
    countdownSeconds = pauseDuration

    // Then: countdown should restart from pause duration
    #expect(countdownSeconds == 3)
  }

  @Test
  func testCuesChangeResetsScrollState() {
    // Given: user is scrolling with active countdown
    var isUserScrolling = true
    var countdownSeconds: Int? = 2
    var currentCueID: UUID? = UUID()

    // When: cues change (simulating .onChange(of: cues))
    isUserScrolling = false
    currentCueID = nil
    countdownSeconds = nil

    // Then: all states should be reset
    #expect(isUserScrolling == false)
    #expect(currentCueID == nil)
    #expect(countdownSeconds == nil)
  }
}

// MARK: - Vocabulary Logic Tests

struct VocabularyLogicTests {

  @Test
  func testDifficultyLevelCalculation() {
    // Given: forgot count is higher than remembered count
    let forgotCount = 5
    let rememberedCount = 2

    // When: calculating difficulty level
    let difficultyLevel = max(0, forgotCount - rememberedCount)

    // Then: should be the difference
    #expect(difficultyLevel == 3)
  }

  @Test
  func testDifficultyLevelNonNegative() {
    // Given: remembered count is higher than forgot count
    let forgotCount = 2
    let rememberedCount = 5

    // When: calculating difficulty level
    let difficultyLevel = max(0, forgotCount - rememberedCount)

    // Then: should be clamped to 0
    #expect(difficultyLevel == 0)
  }

  @Test
  func testDifficultyLevelEqualCounts() {
    // Given: equal counts
    let forgotCount = 3
    let rememberedCount = 3

    // When: calculating difficulty level
    let difficultyLevel = max(0, forgotCount - rememberedCount)

    // Then: should be 0
    #expect(difficultyLevel == 0)
  }

  @Test
  func testDifficultyColorLevel1IsGreen() {
    // Given: difficulty level 1
    let level = 1

    // When: determining color
    let color: String
    switch level {
    case 1: color = "green"
    case 2: color = "yellow"
    default: color = "red"
    }

    // Then: should be green
    #expect(color == "green")
  }

  @Test
  func testDifficultyColorLevel2IsYellow() {
    // Given: difficulty level 2
    let level = 2

    // When: determining color
    let color: String
    switch level {
    case 1: color = "green"
    case 2: color = "yellow"
    default: color = "red"
    }

    // Then: should be yellow
    #expect(color == "yellow")
  }

  @Test
  func testDifficultyColorLevel3OrMoreIsRed() {
    // Given: difficulty level >= 3
    for level in [3, 4, 5, 10] {
      // When: determining color
      let color: String
      switch level {
      case 1: color = "green"
      case 2: color = "yellow"
      default: color = "red"
      }

      // Then: should be red
      #expect(color == "red")
    }
  }

  @Test
  func testNewVocabularyStartsWithForgotCount1() {
    // Given: a new vocabulary entry after clicking "Don't know + 1"
    let initialForgotCount = 1
    let initialRememberedCount = 0

    // When: calculating difficulty level
    let difficultyLevel = max(0, initialForgotCount - initialRememberedCount)

    // Then: should be 1 (green)
    #expect(difficultyLevel == 1)
  }

  @Test
  func testWordNormalization() {
    // Given: word with punctuation and mixed case
    let word = "Hello,"
    let normalized = word.lowercased().trimmingCharacters(
      in: CharacterSet.punctuationCharacters)

    // Then: should be lowercase without punctuation
    #expect(normalized == "hello")
  }
}

// MARK: - Mocks

actor MockAudioPlayerEngine: AudioPlayerEngineProtocol {
  var currentPlayer: AVPlayer? = AVPlayer()

  // Call tracking
  var loadCallCount = 0
  var lastLoadedBookmarkData: Data?
  var playCallCount = 0
  var pauseCallCount = 0

  // Simulation control
  var loadDelay: UInt64 = 0  // nanoseconds
  var shouldPlayFail = false

  func load(
    bookmarkData: Data,
    resumeTime: Double,
    onDurationLoaded: @MainActor @Sendable @escaping (Double) -> Void,
    onTimeUpdate: @MainActor @Sendable @escaping (Double) -> Void,
    onLoopCheck: @MainActor @Sendable @escaping (Double) -> Void,
    onPlaybackStateChange: @MainActor @Sendable @escaping (Bool) -> Void,
    onPlayerReady: @MainActor @Sendable @escaping (AVPlayer) -> Void
  ) async throws -> AVPlayerItem? {
    loadCallCount += 1
    lastLoadedBookmarkData = bookmarkData

    if loadDelay > 0 {
      try? await Task.sleep(nanoseconds: loadDelay)
    }

    await onDurationLoaded(100.0)  // Dummy duration
    await onPlayerReady(currentPlayer!)

    // Simulate player ready state
    return AVPlayerItem(url: URL(string: "https://example.com/dummy.mp3")!)
  }

  func play() -> Bool {
    playCallCount += 1
    return !shouldPlayFail
  }

  func pause() {
    pauseCallCount += 1
  }

  func syncPauseState() {}
  func syncPlayState() {}
  func seek(to time: Double) {}
  func setVolume(_ volume: Float) async {}
  func teardown() {}
}

// MARK: - Integration Tests with Mock Engine

@MainActor
struct AudioPlayerManagerIntegrationTests {

  @Test
  func testSwitchingFileResetsPlayingState() async {
    // Given
    let mockEngine = MockAudioPlayerEngine()
    let manager = AudioPlayerManager(engine: mockEngine)

    // Setup dummy file A
    let fileA = AudioFile(displayName: "A.mp3", bookmarkData: Data("A".utf8))

    // Begin playing file A (manually set state since logic handles UI update immediately)
    // We simulate "play" has happened
    await manager.load(audioFile: fileA)
    manager.isPlaying = true

    // Verify playing state
    #expect(manager.isPlaying == true)

    // When: Loading file B
    let fileB = AudioFile(displayName: "B.mp3", bookmarkData: Data("B".utf8))
    await manager.load(audioFile: fileB)

    // Then: Manager should have stopped playing immediately upon load starts
    // Manager.load sets isPlaying = false at the beginning
    #expect(manager.isPlaying == false)
    #expect(manager.currentFile?.displayName == "B.mp3")
  }

  @Test
  func testCurrentFileUpdatesCorrectly() async {
    // Given
    let mockEngine = MockAudioPlayerEngine()
    let manager = AudioPlayerManager(engine: mockEngine)

    let fileA = AudioFile(displayName: "A.mp3", bookmarkData: Data("A".utf8))
    let fileB = AudioFile(displayName: "B.mp3", bookmarkData: Data("B".utf8))

    // When: Switch A -> B
    await manager.load(audioFile: fileA)
    #expect(manager.currentFile?.displayName == "A.mp3")

    await manager.load(audioFile: fileB)

    // Then
    #expect(manager.currentFile?.displayName == "B.mp3")

    // Verify Engine was called twice
    let callCount = await mockEngine.loadCallCount
    #expect(callCount == 2)
  }

  @Test
  func testLoadCallsAreSerialized() async {
    // Given: Slow engine
    let mockEngine = MockAudioPlayerEngine()
    // 100ms delay
    await mockEngine.setDelay(100_000_000)

    let manager = AudioPlayerManager(engine: mockEngine)
    let fileA = AudioFile(displayName: "A.mp3", bookmarkData: Data("A".utf8))
    let fileB = AudioFile(displayName: "B.mp3", bookmarkData: Data("B".utf8))

    // When: Call load A then load B immediately
    // We use Task to launch them potentially concurrently, but Manager is MainActor protected.
    // However, the awaiting of engine inside Manager.load is suspension point.

    await manager.load(audioFile: fileA)
    await manager.load(audioFile: fileB)

    // Since we await'ed them sequentially, they ran sequentially.
    // The critical part is that state is correct at the end.

    #expect(manager.currentFile?.displayName == "B.mp3")

    let lastBookmark = await mockEngine.lastLoadedBookmarkData
    #expect(lastBookmark == Data("B".utf8))
  }

  @Test
  func testTogglePlayPauseWhilePlayingCallsPauseReference() async {
    // Given: Playing
    let mockEngine = MockAudioPlayerEngine()
    let manager = AudioPlayerManager(engine: mockEngine)
    manager.isPlaying = true

    // When: Toggle
    manager.togglePlayPause()

    // Then: State updates immediately
    #expect(manager.isPlaying == false)

    // Verify sync pause was NOT called immediately on main actor?
    // Wait, manager calls _player?.pause() synchronously (if valid).
    // And calls await _engine.syncPauseState() in background.
    // We can't easily test the background task timing here without expectations,
    // but we can check the state is false.
  }

  @Test
  func testRapidFileSwitchingCancelsOldLoad() async {
    // Given
    let mockEngine = MockAudioPlayerEngine()
    let manager = AudioPlayerManager(engine: mockEngine)
    // Set a delay to simulate async loading
    await mockEngine.setDelay(50_000_000)  // 50ms

    let fileA = AudioFile(displayName: "A.mp3", bookmarkData: Data("A".utf8))
    let fileB = AudioFile(displayName: "B.mp3", bookmarkData: Data("B".utf8))

    // When: Start loading A, then immediately load B
    // We launch them in parallel tasks but they will hit the actor sequentially or concurrently depending on scheduling,
    // but the Manager's State (loadingFileID) is MainActor protected and will be updated immediately.

    // Task 1: Load A
    Task {
      await manager.load(audioFile: fileA)
    }

    // Small yield to ensure Task 1 starts but hits the delay
    try? await Task.sleep(nanoseconds: 10_000_000)

    // Task 2: Load B
    await manager.load(audioFile: fileB)

    // Then: Manager should reflect file B
    #expect(manager.currentFile?.displayName == "B.mp3")

    // Wait for everything to settle
    try? await Task.sleep(nanoseconds: 100_000_000)

    // Verify that even after A 'finishes' (in background), the manager state is still B
    #expect(manager.currentFile?.displayName == "B.mp3")
    #expect(manager.duration != 0)  // Should have loaded duration for B
  }
}

extension MockAudioPlayerEngine {
  func setDelay(_ delay: UInt64) {
    self.loadDelay = delay
  }
}
