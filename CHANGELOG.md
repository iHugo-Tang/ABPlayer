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


