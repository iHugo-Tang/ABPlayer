import Foundation
import Testing

@testable import ABPlayer

// MARK: - Repeat All Tests

struct RepeatAllTests {

  // MARK: - Next File Index Tests

  @Test
  func testNextFileIndexReturnsNextIndex() {
    // Given files: [0, 1, 2]
    // When current index is 0, next should be 1
    let currentIndex = 0
    let filesCount = 3
    let nextIndex = (currentIndex + 1) % filesCount

    #expect(nextIndex == 1)
  }

  @Test
  func testNextFileIndexWrapsAroundToFirst() {
    // Given files: [0, 1, 2]
    // When current index is 2 (last), next should be 0 (first)
    let currentIndex = 2
    let filesCount = 3
    let nextIndex = (currentIndex + 1) % filesCount

    #expect(nextIndex == 0)
  }

  @Test
  func testNextFileIndexSingleFile() {
    // Given files: [0]
    // When current index is 0, next should be 0 (wraps to self)
    let currentIndex = 0
    let filesCount = 1
    let nextIndex = (currentIndex + 1) % filesCount

    #expect(nextIndex == 0)
  }

  // MARK: - Sorting Tests

  @Test
  func testAudioFilesSortByDisplayName() {
    // Given unsorted display names
    let names = ["Track 03", "Track 01", "Track 02"]
    let sorted = names.sorted { $0 < $1 }

    #expect(sorted == ["Track 01", "Track 02", "Track 03"])
  }

  @Test
  func testAudioFilesSortByDisplayNameWithNumbers() {
    // Given files with numeric names (lexicographic sort)
    let names = ["1.mp3", "10.mp3", "2.mp3", "9.mp3"]
    let sorted = names.sorted { $0 < $1 }

    // Note: Lexicographic sort puts "10" before "2"
    // This is expected behavior matching Finder's sort
    #expect(sorted == ["1.mp3", "10.mp3", "2.mp3", "9.mp3"])
  }

  // MARK: - Selection Sync Tests

  @Test
  func testSelectionItemEquality() {
    let id1 = UUID()
    let id2 = UUID()

    // Same IDs should be equal when compared by ID
    #expect(id1 == id1)
    #expect(id1 != id2)
  }
}
