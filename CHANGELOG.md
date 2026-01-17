## [0.2.9.52] - 2026-01-16

### Other
- fix(subtitle): improve SubtitleView layout and height calculation
- feat(opencode): update github-release
- Merge pull request #77 from sunset-valley/release/0.2.9-51


## [0.2.9.51] - 2026-01-13

### Other
- refactor(analytics): replace Firebase with TelemetryDeck
- feat(opencode): update github-release
- Merge pull request #76 from sunset-valley/release/0.2.9-50


## [0.2.9.50] - 2026-01-13

### Other
- feat(firebase): integrate Firebase for analytics and auth
- Merge pull request #75 from sunset-valley/feat/load-duration-file
- chore(agent): add github-release skill for release automation


## [0.2.9.49] - 2026-01-13

### Bug Fixes
- tests

### Other
- feat(import): convert importer to async actor and load duration metadata
- feat(ui): add unplayed indicator and adjust row heights
- Merge pull request #74 from sunset-valley/feat/ui-file-list


## [0.2.9.48] - 2026-01-12

### Improvements
- extract views

### Other
- feat(ui): improve footer design and add feedback link
- refactor(ui): improve selection animations and async transcription caching
- refactor(ui): simplify folder navigation and update typography color system
- refactor(models): rename AudioFile to ABFile and add FileType support
- feat(ui): implement press gesture with auto-deselect and improved list layout
- feat(ui): improve list styling and add auto-deselect behavior
- refactor(navigation): extract FolderNavigationViewModel and component views
- refactor(files): update style of file view
- refactor(content-panel): disable bar background for narrow layouts
- Merge pull request #73 from sunset-valley/refactor/subtitle


## [0.2.8.47] - 2026-01-07

### Bug Fixes
- Refine subtitle word selection and row tap interaction to prevent immediate popover dismissal.

### Chores
- Reformat popover `isPresented` binding setter for readability.

### Other
- refactor(audio-player): swap segments and content panel layout
- feat(subtitle): optimize word selection with caching and add FPS monitor
- refactor(subtitle): use InteractiveAttributedTextView for all states
- fix(subtitle): improve popover arrow direction and hover area bounds
- fix(subtitle): avoid state update cycle in popover logic
- fix(subtitle): position popover relative to clicked word
- fix(subtitle): fix popover position and dismissal issues
- Merge pull request #72 from sunset-valley/fix/transcribe-mp4


## [0.2.8.46] - 2026-01-06

### Other
- feat(transcription): add configurable FFmpeg path with auto-detection
- feat(transcription): add video file support with audio extraction
- Merge pull request #71 from sunset-valley/ci/release-45


## [0.2.8.45] - 2026-01-06

### Other
- Merge pull request #70 from sunset-valley/fix/perf-hang
- perf(subtitle): fix 1000ms+ main thread hangs by caching FlowLayout and simplifying views
- Merge pull request #69 from sunset-valley/ci/release


## [0.2.8.44] - 2026-01-06

### Other
- feat(release): auto-commit release changes and filter ci commits from changelog
- Merge pull request #68 from sunset-valley/fix/perf-hang
- fix(perf): reduce layout churn to prevent 2000ms hang


## [0.2.8.43] - 2026-01-06

### Features
- Adjust video player font sizes, implement smoother resizing, and refine UI layouts for version 0.2.8.42.

### Other
- fix(perf): reduce layout churn to prevent 2000ms hang