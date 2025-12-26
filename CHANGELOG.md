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


