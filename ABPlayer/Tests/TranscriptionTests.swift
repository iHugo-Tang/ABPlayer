import Foundation
import Testing

@testable import ABPlayer

// MARK: - Transcription Cache Tests

struct TranscriptionCacheTests {

  @Test
  func testHashGenerationIsConsistent() {
    let data = "audio_file.mp3".data(using: .utf8)!

    let hash1 = Transcription.hash(from: data)
    let hash2 = Transcription.hash(from: data)

    #expect(hash1 == hash2, "Hash should be consistent for same input")
  }

  @Test
  func testHashGenerationIsDifferentForDifferentData() {
    let data1 = "audio1.mp3".data(using: .utf8)!
    let data2 = "audio2.mp3".data(using: .utf8)!

    let hash1 = Transcription.hash(from: data1)
    let hash2 = Transcription.hash(from: data2)

    #expect(hash1 != hash2, "Hash should be different for different inputs")
  }

  @Test
  func testHashIsHexFormat() {
    let data = "test.mp3".data(using: .utf8)!

    let hash = Transcription.hash(from: data)

    // Should be 8 character hex string
    #expect(hash.count == 8, "Hash should be 8 characters")
    #expect(hash.allSatisfy { $0.isHexDigit }, "Hash should be hex characters")
  }
}

// MARK: - Subtitle Cue Encoding Tests

struct SubtitleCueEncodingTests {

  @Test
  func testCueEncodingDecoding() {
    let cues = [
      SubtitleCue(startTime: 0.0, endTime: 2.5, text: "Hello"),
      SubtitleCue(startTime: 2.5, endTime: 5.0, text: "World"),
    ]

    let data = try! JSONEncoder().encode(cues)
    let decoded = try! JSONDecoder().decode([SubtitleCue].self, from: data)

    #expect(decoded.count == 2)
    #expect(decoded[0].text == "Hello")
    #expect(decoded[0].startTime == 0.0)
    #expect(decoded[0].endTime == 2.5)
    #expect(decoded[1].text == "World")
    #expect(decoded[1].startTime == 2.5)
  }

  @Test
  func testCueWithSpecialCharacters() {
    let cue = SubtitleCue(
      startTime: 0.0,
      endTime: 1.0,
      text: "Hello \"World\" with 'quotes' and\nnewlines"
    )

    let data = try! JSONEncoder().encode([cue])
    let decoded = try! JSONDecoder().decode([SubtitleCue].self, from: data)

    #expect(decoded[0].text == "Hello \"World\" with 'quotes' and\nnewlines")
  }

  @Test
  func testEmptyCuesArray() {
    let cues: [SubtitleCue] = []

    let data = try! JSONEncoder().encode(cues)
    let decoded = try! JSONDecoder().decode([SubtitleCue].self, from: data)

    #expect(decoded.isEmpty)
  }
}

// MARK: - Transcription State Tests

struct TranscriptionStateTests {

  @Test
  func testIdleStateEquality() {
    #expect(TranscriptionState.idle == TranscriptionState.idle)
  }

  @Test
  func testLoadingStateEquality() {
    #expect(TranscriptionState.loading == TranscriptionState.loading)
  }

  @Test
  func testTranscribingStateEqualityWithSameProgress() {
    #expect(
      TranscriptionState.transcribing(progress: 0.5)
        == TranscriptionState.transcribing(progress: 0.5))
  }

  @Test
  func testTranscribingStateInequalityWithDifferentProgress() {
    #expect(
      TranscriptionState.transcribing(progress: 0.5)
        != TranscriptionState.transcribing(progress: 0.6))
  }

  @Test
  func testCompletedStateEquality() {
    #expect(TranscriptionState.completed == TranscriptionState.completed)
  }

  @Test
  func testFailedStateEqualityWithSameMessage() {
    #expect(
      TranscriptionState.failed("Error")
        == TranscriptionState.failed("Error"))
  }

  @Test
  func testFailedStateInequalityWithDifferentMessage() {
    #expect(
      TranscriptionState.failed("Error 1")
        != TranscriptionState.failed("Error 2"))
  }

  @Test
  func testDifferentStatesAreNotEqual() {
    #expect(TranscriptionState.idle != TranscriptionState.loading)
    #expect(TranscriptionState.loading != TranscriptionState.completed)
    #expect(TranscriptionState.transcribing(progress: 0.5) != TranscriptionState.completed)
  }
}

// MARK: - Transcription Settings Tests

struct TranscriptionSettingsTests {

  @Test
  func testAvailableModelsNotEmpty() {
    #expect(!TranscriptionSettings.availableModels.isEmpty)
  }

  @Test
  func testDefaultModelInAvailableModels() {
    let defaultModel = "distil-large-v3"
    let modelIds = TranscriptionSettings.availableModels.map { $0.id }

    #expect(modelIds.contains(defaultModel))
  }

  @Test
  func testAvailableLanguagesIncludesAutoDetect() {
    let languageIds = TranscriptionSettings.availableLanguages.map { $0.id }

    #expect(languageIds.contains("auto"))
  }

  @Test
  func testAvailableLanguagesIncludesEnglish() {
    let languageIds = TranscriptionSettings.availableLanguages.map { $0.id }

    #expect(languageIds.contains("en"))
  }
}
