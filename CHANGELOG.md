## [0.2.8.40] - 2026-01-02

### Features
- Implement audio file loading cancellation for rapid switching and adjust video player controls layout.

### Improvements
- Simplify folder navigation's file selection sync and add debounced audio file loading.
- Improve player teardown and clearing logic with `clearPlayer` and migrate async view operations to `.task`.
- Debounce audio file loading and remove redundant `selectedFile` change observer.
- Consolidate import and clear data actions into a single "Add" menu and update 'Import Audio File' label.

### Other
- Merge pull request #63 from sunset-valley/fix/autoplay


## [0.2.7.39] - 2025-12-31

### Features
- Implement audio file loading cancellation for rapid switching and adjust video player controls layout.

### Bug Fixes
- Improve AVPlayer lifecycle management with tracking and enhance UI responsiveness during player transitions.

### Improvements
- replace `print` statements with categorized `OSLog` for structured logging
- Expose `AVPlayer` from `AudioPlayerManager` and simplify player view state management.

### Other
- Merge pull request #62 from sunset-valley/fix/AudioPlayerManager


## [0.2.6.38] - 2025-12-31

### Improvements
- Expose `AVPlayer` from `AudioPlayerManager` and simplify player view state management.


## [0.2.6.37] - 2025-12-31

### Features
- Synchronize player views with audio file changes and reorder selected file assignment in `MainSplitView`.

### Other
- Merge pull request #61 from sunset-valley/fix/autoplay1


## [0.2.6.36] - 2025-12-31

### Features
- Synchronize player views with audio file changes and reorder selected file assignment in `MainSplitView`.

### Improvements
- Remove redundant `onChange` observers for audio file loading and re-enable direct load call in `MainSplitView`.

### Other
- Merge pull request #60 from sunset-valley/fix/autoplay


## [0.2.6.35] - 2025-12-31

### Improvements
- Remove redundant `onChange` observers for audio file loading and re-enable direct load call in `MainSplitView`.
- Centralize vocabulary query in SubtitleView and pass map to subtitle rows for efficient lookup.

### Other
- Merge pull request #59 from sunset-valley/fix/improve-pause


## [0.2.6.34] - 2025-12-31

### Features
- add Telegram notification for successful releases

### Improvements
- Centralize vocabulary query in SubtitleView and pass map to subtitle rows for efficient lookup.

### Chores
- set development bundle ID

### Other
- Merge pull request #58 from sunset-valley/ci/tg


## [0.2.6.33] - 2025-12-31

### Features
- add Telegram notification for successful releases
- Introduce `AudioPlayerEngineProtocol` to enable `AudioPlayerManager` dependency injection and add integration tests with a mock engine.

### Other
- Merge pull request #57 from sunset-valley/feat/improve-pause


## [0.2.6.32] - 2025-12-31

### Features
- Introduce `AudioPlayerEngineProtocol` to enable `AudioPlayerManager` dependency injection and add integration tests with a mock engine.
- Reactively load audio files in the player view and remove explicit loading from the main split view.

### Improvements
- improve play/pause responsiveness by directly controlling AVPlayer and updating UI state immediately.

### Other
- Merge pull request #56 from sunset-valley/fix/video-swich


## [0.2.6.31] - 2025-12-31

### Features
- Reactively load audio files in the player view and remove explicit loading from the main split view.
- Implement volume debouncing and add a reset volume button to player views.

### Other
- Merge pull request #55 from sunset-valley/feat/volume-boosting


## [0.2.6.30] - 2025-12-31

### Features
- Implement volume debouncing and add a reset volume button to player views.
- Implement volume boosting functionality up to 200% with a UI indicator.


## [0.2.6.29] - 2025-12-31

### Features
- Implement volume boosting functionality up to 200% with a UI indicator.
- Implement combined short and build versioning across release script and CI, and increment build version.

### Other
- Merge pull request #54 from sunset-valley/feat/auto-update-4


## [0.2.6.28] - 2025-12-31

### Features
- Increment project version to 0.2.6, refactor release script to manage build and short versions, and update Project.swift to use a dynamic build version.

### Bug Fixes
- correct CI version extraction to use buildVersionString instead of shortVersionString

### Other
- Merge pull request #53 from sunset-valley/feat/auto-update-3
- Merge pull request #52 from sunset-valley/feat/auto-update-2
- Merge pull request #51 from sunset-valley/feat/auto-update-1


## [0.2.6] - 2025-12-31

### Chores
- Increment project version to 0.2.6 and update changelog and release state.


## [0.2.6] - 2025-12-31

### Other
- Merge pull request #50 from sunset-valley/feat/auto-update


## [0.2.6] - 2025-12-31

### Features
- Integrate Sparkle for in-app updates and automate release artifact generation in CI.
- Observe AVPlayer rate to update playback state and manage session tracking and progress persistence.
- Release 0.2.5 with `autoPlayNext` playback mode, updated icons, and UI enhancements.

### Improvements
- Introduce `onHidePopover` for explicit word selection dismissal and simplify hover-based deselection logic.

### Chores
- ignore buildServer.json

### Other
- Merge pull request #49 from sunset-valley/feat/loopmode-auto-next1


## [0.2.5] - 2025-12-30

### Features
- add `autoPlayNext` playback mode and its sequential file handling logic.
- update application icons
- enhance window and split view resizing behavior, update Sentry configuration, and remove build server config.

### Other
- Merge pull request #48 from sunset-valley/feat/loopmode-auto-next
- Merge branch 'main' into feat/loopmode-auto-next


## [0.2.4] - 2025-12-30

### Features
- add `autoPlayNext` playback mode and its sequential file handling logic.

### Bug Fixes
- Update version string parsing and updating in CI and release scripts to match new `Project.swift` format.

### Improvements
- Centralize `CFBundleShortVersionString` by introducing a new `shortVersionString` constant.
- use bundle identifier to dynamically determine app support folder name


## [0.2.3] - 2025-12-30

### Features
- Rework typography system, enhance subtitle font size selection, and introduce a development build target.
- Add configurable font size for subtitles and integrate it into the subtitle rendering components.
- reimplement pause countdown UI as an overlay in subtitle view and remove old indicator from transcription view.

### Improvements
- use bundle identifier to dynamically determine app support folder name
- Remove redundant frame and background styling from VideoPlayerView.


## [0.2.2] - 2025-12-30

### Features
- reimplement pause countdown UI as an overlay in subtitle view and remove old indicator from transcription view.
- Add number-based sorting options and persist the selected sort order using AppStorage.


## [0.2.1] - 2025-12-30

### Features
- Add number-based sorting options and persist the selected sort order using AppStorage.
- Add video playback functionality with a dedicated player view, controls, and segment display.

### Improvements
- rename PlayerView to AudioPlayerView


## [0.2.0] - 2025-12-30

### Features
- Add video playback functionality with a dedicated player view, controls, and segment display.
- Persist and restore player loop mode using AppStorage.
- Add word creation date, enable 'Remember' action after 12 hours, and refactor word menu actions to use cleaned words.
- Introduce vocabulary removal, display remembered counts, and refactor word menu buttons with a new `MenuButton` component.

### Improvements
- rename PlayerView to AudioPlayerView

### Other
- Replace conditional checkmark for selected loop mode with dedicated icon for each option.


## [0.1.23] - 2025-12-29

### Features
- Persist and restore player loop mode using AppStorage.
- Add word creation date, enable 'Remember' action after 12 hours, and refactor word menu actions to use cleaned words.
- Introduce vocabulary removal, display remembered counts, and refactor word menu buttons with a new `MenuButton` component.
- show progress view in sidebar when clearing all data

### Other
- Replace conditional checkmark for selected loop mode with dedicated icon for each option.


## [0.1.22] - 2025-12-29

### Features
- show progress view in sidebar when clearing all data
- trigger `onDismiss` callback when the popover is dismissed


## [0.1.21] - 2025-12-29

### Features
- trigger `onDismiss` callback when the popover is dismissed

### Chores
- Add padding to individual subtitle words.


## [0.1.20] - 2025-12-29

### Features
- Enable folder rescan via security-scoped bookmarks and improve synchronization of audio files with subtitles, PDFs, and transcription records.

### Chores
- Add padding to individual subtitle words.


## [0.1.19] - 2025-12-29

### Features
- Enable folder rescan via security-scoped bookmarks and improve synchronization of audio files with subtitles, PDFs, and transcription records.
- Implement idempotent folder synchronization using deterministic IDs and separate debug app data storage.


## [0.1.18] - 2025-12-29

### Features
- Implement idempotent folder synchronization using deterministic IDs and separate debug app data storage.
- Update to version 0.1.17, introducing vocabulary tracking, scroll pause countdown, interactive word selection, and improved subtitle lookup, alongside focusability adjustments.
- Implement vocabulary tracking with a SwiftData model, integrating word difficulty display and 'forgot/remembered' actions into subtitles.

### Improvements
- Replace linear search with binary search for active subtitle cue lookup.

### Other
- feat(subtitle): enable interactive word selection and display using a new flow layout


## [0.1.17] - 2025-12-29

### Features
- Implement vocabulary tracking with a SwiftData model, integrating word difficulty display and 'forgot/remembered' actions into subtitles.
- Add scroll pause countdown with UI, tests, VS Code settings, and build instructions.

### Improvements
- Replace linear search with binary search for active subtitle cue lookup.

### Other
- feat(subtitle): enable interactive word selection and display using a new flow layout


## [0.1.16] - 2025-12-29

### Features
- Add scroll pause countdown with UI, tests, VS Code settings, and build instructions.
- Pause playback during slider seeking and implement user-scroll detection to disable subtitle auto-scroll.


## [0.1.15] - 2025-12-29

### Features
- Pause playback during slider seeking and implement user-scroll detection to disable subtitle auto-scroll.
- Implement persistent volume control, improve session tracking resilience, and configure ModelContainer for all schema types.

### Other
- Merge pull request #29 from sunset-valley/fix/crash-delete-sqlite-file


## [0.1.14] - 2025-12-29

### Features
- Implement persistent volume control, improve session tracking resilience, and configure ModelContainer for all schema types.
- Offload listening session SwiftData operations to a background ModelActor and refactor SessionTracker for UI coordination.
- introduce dedicated ListeningSession SwiftData model, refactor SessionTracker to use it and leverage autosave, update agent guidelines, and add PlaybackRecord to schema.

### Chores
- remove SwiftUI debug print statement from TranscriptionView


## [0.1.13] - 2025-12-28

### Features
- introduce dedicated ListeningSession SwiftData model, refactor SessionTracker to use it and leverage autosave, update agent guidelines, and add PlaybackRecord to schema.
- Initialize playback records before use and update `isPlaybackComplete` to check completion count.
- Introduce `PlaybackRecord` model to store detailed playback state and replace `AudioFile`'s `lastPlaybackTime` property.
- Generate deterministic AudioFile IDs via SHA256 hash, adjust SwiftData deletion order for external storage attributes, and add CoreData ER diagram.
- Implement asynchronous selection syncing with a loading indicator and task cancellation.

### Chores
- remove SwiftUI debug print statement from TranscriptionView

### Other
- Remove `onPlayFile` parameter and selected file checkmark from `FolderNavigationView`, and add `selectedFile` change observer.


## [0.1.12] - 2025-12-28

### Features
- Initialize playback records before use and update `isPlaybackComplete` to check completion count.
- Introduce `PlaybackRecord` model to store detailed playback state and replace `AudioFile`'s `lastPlaybackTime` property.
- Generate deterministic AudioFile IDs via SHA256 hash, adjust SwiftData deletion order for external storage attributes, and add CoreData ER diagram.
- Implement asynchronous selection syncing with a loading indicator and task cancellation.

### Improvements
- remove conditional session saving logic from duration update

### Other
- Remove `onPlayFile` parameter and selected file checkmark from `FolderNavigationView`, and add `selectedFile` change observer.


## [0.1.11] - 2025-12-28

### Features
- Release version 0.1.10, adding player section expansion and navigation split view fix.

### Improvements
- remove conditional session saving logic from duration update


## [0.1.10] - 2025-12-28

### Features
- Allow player section to expand when content panel is not shown.
- Release version 0.1.9, adding new audio playback, transcription management, and UI enhancements, and fixing navigation split view column width.

### Bug Fixes
- Apply navigation split view column width modifier directly to the sidebar.


## [0.1.9] - 2025-12-28

### Features
- Release version 0.1.8, adding new audio playback, transcription management, and UI enhancements.
- Add `isPlaybackComplete` property to audio models and use it for icon styling in folder navigation.
- Add transcription queue manager to handle transcription tasks and integrate it into the app and transcription view.
- Store and retrieve audio transcriptions as SRT files, update audio model with transcription status, and show transcription indicator in folder view.
- Implement cancellable model downloads with progress UI and cache cleanup.
- Configure default window dimensions, refine split view column sizing, and add persistent, draggable player section width.

### Bug Fixes
- Apply navigation split view column width modifier directly to the sidebar.


## [0.1.8] - 2025-12-28

### Features
- Add `isPlaybackComplete` property to audio models and use it for icon styling in folder navigation.
- Add transcription queue manager to handle transcription tasks and integrate it into the app and transcription view.
- Store and retrieve audio transcriptions as SRT files, update audio model with transcription status, and show transcription indicator in folder view.
- Implement cancellable model downloads with progress UI and cache cleanup.
- Configure default window dimensions, refine split view column sizing, and add persistent, draggable player section width.
- Release version 0.1.7 with new features and fixes, and enhance the release script for automatic version incrementing.
- Introduce asynchronous transcription model listing and update tests and settings view to use it.


## [0.1.7] - 2025-12-26

### Features
- Introduce asynchronous transcription model listing and update tests and settings view to use it.
- Introduce Git LFS for media files, add architecture documentation, and implement comprehensive business logic tests.
- Bump version to 0.1.6, add architecture documentation, update app icons, improve session tracker resilience, and add MIT License.
- Add architecture documentation and update app icon assets, including a new 1024x1024 icon and cleanup of old versions.

### Other
- Add demo video link to README
- Fix HTML entities in README.md
- Fix video tag in README.md


## [0.1.6] - 2025-12-26

### Features
- Add architecture documentation and update app icon assets, including a new 1024x1024 icon and cleanup of old versions.
- bump version to 0.1.5, improve session tracker resilience, and update segment navigation button icons.
- Improve session tracker resilience to deleted sessions and ensure all sessions are deleted when clearing user data.
- update segment navigation button icons

### Chores
- Add architecture documentation and demo video, and overhaul README with comprehensive project details.

### Other
- Add MIT License to the project


## [0.1.5] - 2025-12-26

### Features
- Improve session tracker resilience to deleted sessions and ensure all sessions are deleted when clearing user data.
- update segment navigation button icons
- bump version to 0.1.4, adding a draggable content panel, NavigationSplitView, and a session timer to the toolbar.


## [0.1.4] - 2025-12-26

### Features
- Release version 0.1.3, introducing UI improvements and an enhanced release script.
- Implement a draggable and resizable content panel using a custom divider instead of HSplitView.
- Replace HSplitView with NavigationSplitView for dynamic content panel visibility.
- add session timer to toolbar and refine various text styles.


## [0.1.3] - 2025-12-26

### Features
- Implement a draggable and resizable content panel using a custom divider instead of HSplitView.
- Replace HSplitView with NavigationSplitView for dynamic content panel visibility.
- add session timer to toolbar and refine various text styles.
- Enhance release script to categorize changelog entries and bump version to 0.1.2.


## [0.1.2] - 2025-12-26

### Features
- Add application update script, `.env.example`, and bump version to 0.1.1 with various new features and UI improvements.
- Relocate segment navigation buttons to the saved segments header and move the 'Save' button to the main player controls.


## [0.1.1] - 2025-12-26

- feat: Relocate segment navigation buttons to the saved segments header and move the 'Save' button to the main player controls.
- chore: stop tracking build_output.log
- feat: Introduce automated release script, changelog, and update CI to use changelog for release notes.
- feat: Add folder and audio file deletion with context menus and enhance session save error handling.
- refactor: Improve `clearAllData` to stop playback, reset UI state, and delete SwiftData entities individually in a dependency-aware order.
- feat: bump app version to 0.1.0
- feat: Implement macOS Settings window with command shortcut and refine its layout and sizing.
- feat: Add data cleaning script, implement shortcut reset with updated default modifiers, and refine view frame constraints.
- feat: Implement keyboard shortcut customization and refactor segment management to AudioPlayerManager
- feat: Display loading state for empty transcription cues, reset transcription manager after caching, and add manager reset tests.
- feat: add debug logging for view geometry changes in PlayerView and MainSplitView
- feat: Add EmptyStateView, introduce typography system, and switch app's root view to MainSplitView.


# Changelog

## [0.1.0] - 2025-12-26

- feat: Add folder and audio file deletion with context menus and enhance session save error handling.
- refactor: Improve `clearAllData` to stop playback, reset UI state, and delete SwiftData entities individually in a dependency-aware order.
- feat: bump app version to 0.1.0
- feat: Implement macOS Settings window with command shortcut and refine its layout and sizing.
- feat: Add data cleaning script, implement shortcut reset with updated default modifiers, and refine view frame constraints.
- feat: Implement keyboard shortcut customization and refactor segment management to AudioPlayerManager
- feat: Display loading state for empty transcription cues, reset transcription manager after caching, and add manager reset tests.
- feat: add debug logging for view geometry changes in PlayerView and MainSplitView
- feat: Add EmptyStateView, introduce typography system, and switch app's root view to MainSplitView.
- refactor: move empty state to overlay and add focusable(false) to button


