## [0.2.9.66] - 2026-01-26

### Chores
- add padding to SegmentsSection for better layout


## [0.2.9.65] - 2026-01-26

### Features
- add tab removal and dynamic view allocation for MainSplitView
- implement dynamic view allocation system for main split view
- add dynamic pane content switching for bottomLeft and right panels

### Bug Fixes
- sync player state with navigation selection on restore

### Improvements
- centralize session timer in MainSplitView


## [0.2.9.64] - 2026-01-25

### Bug Fixes
- decouple file importer presentation state from import type


## [0.2.9.63] - 2026-01-25

### Improvements
- consolidate file importers using enum state


## [0.2.9.62] - 2026-01-24

### Features
- separate layout persistence for audio and video

### Bug Fixes
- use real bookmarks in PlayerManagerIntegrationTests

### Improvements
- unify player layout with ResizableSplitPanel and ThreePanelLayout
- disable app hang tracking

### Chores
- reorganize git-release skill into directory structure


## [0.2.9.61] - 2026-01-24

### Features
- implement managed media library system
- handle file load errors and add session reset

### Bug Fixes
- force UI refresh after folder rescan by saving context

### Improvements
- move SortingUtility to Utils folder
- support in-place import and use relative paths for IDs
- extract services from FolderNavigationViewModel
- switch to MainActor and use absolute paths for folder IDs
- move file load error tracking to ABFile model

### Chores
- replace hardcoded selection color with asset
- update business logic tests for PlayerManager and circular queue


## [0.2.9.60] - 2026-01-20

### Features
- implement next/previous navigation with circular queue support

### Improvements
- move selection and queue state from MainSplitView to PlayerManager
- reorganize AudioPlayerManager into modular PlayerManager structure
- extract playback queue and loop logic to dedicated service


## [0.2.9.59] - 2026-01-19

### Improvements
- improve HUD animation and visibility state management


## [0.2.9.58] - 2026-01-19

### Features
- add HUD feedback, subtitle toggle, and track navigation controls

### Chores
- refine VideoPlayerView layout and SegmentsSection spacing


## [0.2.9.57] - 2026-01-19

### Bug Fixes
- allow mp4 files by using UTType.movie in fileImporter

### Improvements
- migrate player and transcription views to MVVM and decompose components

### Chores
- update BgPrimary color and adjust navigation header background
- improve sidebar background and remove redundant panel background


## [0.2.9.56] - 2026-01-19

### Improvements
- simplify hover logic in SubtitleCueRow
- do not widthTraccksTextView


## [0.2.9.55] - 2026-01-17

### Bug Fixes
- control Sentry app hang tracking by scene phase

### Chores
- update git-release process instructions
- upgrade Sentry from 9.0.0 to 9.1.0

### Other
- release: 0.2.9-53 (#79)


## [0.2.9.54] - 2026-01-17

### Other

- fix(monitoring): control Sentry app hang tracking by scene phase
- chore(deps): upgrade Sentry from 9.0.0 to 9.1.0
- Merge pull request #78 from sunset-valley/release/0.2.9-52

## [0.2.9.53] - 2026-01-17

### Features

- implement VocabularyService and refactor SubtitleView for better state management

### Bug Fixes

- resolve compiler warnings, concurrency issues, and asset naming conflicts

### Improvements

- improve robustness with logging, assertions, and async-stream countdown
- extract layout and string building logic into dedicated utilities and add tests
- extract logic to SubtitleViewModel and modularize sub-components
- exclude merge commits and support scoped commits in changelog

### Chores

- add architecture diagram for subtitle system
- convert videos

