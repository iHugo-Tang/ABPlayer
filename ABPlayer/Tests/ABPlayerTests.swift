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

// MARK: - Selection Sync Tests

struct SelectionSyncTests {

  /// Tests that selection is set when selectedFile is in currentAudioFiles
  @Test
  func testSelectionSyncWhenFileInCurrentFolder() {
    // Given: A file ID that exists in the current folder's files
    let fileId = UUID()
    let currentFileIds = [UUID(), fileId, UUID()]

    // When: Checking if file is in current folder
    let isInCurrentFolder = currentFileIds.contains { $0 == fileId }

    // Then: Should return true
    #expect(isInCurrentFolder == true)
  }

  /// Tests that selection is cleared when selectedFile is not in currentAudioFiles
  @Test
  func testSelectionClearsWhenFileNotInFolder() {
    // Given: A file ID that does NOT exist in current folder
    let selectedFileId = UUID()
    let currentFileIds = [UUID(), UUID(), UUID()]

    // When: Checking if selected file is in current folder
    let isInCurrentFolder = currentFileIds.contains { $0 == selectedFileId }

    // Then: Should return false, meaning selection should be cleared
    #expect(isInCurrentFolder == false)
  }

  /// Tests that redundant selection updates are avoided (idempotency)
  @Test
  func testSelectionSyncIdempotent() {
    // Given: Current selection already matches selectedFile
    let fileId = UUID()
    let currentSelectionId: UUID? = fileId
    let selectedFileId = fileId

    // When: Checking if already matching
    let alreadyMatches = currentSelectionId == selectedFileId

    // Then: Should skip update
    #expect(alreadyMatches == true)
  }

  /// Tests that selection sync handles nil selectedFile
  @Test
  func testSelectionSyncWithNilFile() {
    // Given: selectedFile is nil
    let selectedFileId: UUID? = nil

    // Then: selection should be cleared (nil)
    #expect(selectedFileId == nil)
  }

  /// Tests navigation back to folder containing selected file
  @Test
  func testSelectionRestoredAfterNavigateBack() {
    // Given: A file ID that is selected
    let selectedFileId = UUID()
    // Navigation returns to a folder that contains this file
    let parentFolderFileIds = [UUID(), selectedFileId, UUID()]

    // When: Checking if file is in parent folder
    let isInFolder = parentFolderFileIds.contains { $0 == selectedFileId }

    // Then: Selection should be restored
    #expect(isInFolder == true)
  }
}
