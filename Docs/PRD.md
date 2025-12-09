# ABPlayer Lite PRD

## Background & Goals
- Provide an A-B loop practice tool for local MP3 files in language learning, phrase drills, and similar scenarios.
- Goal: quickly import a single audio file, mark A/B points, loop playback, save/reuse segments, and track practice time plus playback progress.

## Core Features
- **Audio import & list**
  - Import a single MP3 via file picker (stored with security-scoped bookmark); list shows name and date in ascending import order.
  - Remember the last selected file, auto-restore on launch or data change; show an alert on import failure.
- **Playback & progress**
  - Play/pause, back 5s, forward 10s; scrub with a slider to any time, showing current/total duration.
  - Persist `lastPlaybackTime` on exit and resume from it on reload.
- **A-B looping & shortcuts**
  - Set A (x), set B (c), clear (v); reject if B ≤ A.
  - When playback reaches B, jump to A and keep looping.
- **Segment management**
  - Save current A-B as a segment (auto-increment label), de-duplicate identical start/end; toggle list sort by start time (asc/desc).
  - Tap a segment to apply/jump; left/right arrow to move to previous/next; delete a segment and reindex.
- **Practice time tracking**
  - Accumulate current session duration while playing (seconds), show in header; persist every 5s and on exit.
- **State & version**
  - Show app version/build; persist playback progress and session when closing (macOS).

## Key Flows
1) Launch → restore last audio/segment/progress.  
2) Import MP3 → load and resume from last time.  
3) Play and set A/B → loop or save as segment.  
4) Reuse segments: pick from list or use left/right arrows → auto-jump (can auto-play).  
5) Quit/close window → persist playback progress and session duration.

## Data Models (SwiftData)
- `AudioFile`: id, displayName, bookmarkData (external storage), createdAt, segments [LoopSegment], lastPlaybackTime (Double).
- `LoopSegment`: id, label, startTime, endTime, index, createdAt, audioFile.
- `ListeningSession`: id, startedAt, durationSeconds, endedAt.

## Platform / Tech Constraints
- SwiftUI + SwiftData + AVPlayer; security-scoped bookmarks for local files; single-window experience.
- MP3 only; single-file import.
- macOS termination notification triggers progress and session persistence.

## Non-goals / Open Items
- Not implemented: rename/delete files, batch import, playlists, speed/volume/waveform control, segment export/share, custom shortcuts.
