# Winamp Clone - Project Brain

## Project Summary
A native macOS MP3 player inspired by the classic Winamp. Built with Swift, SwiftUI, and AVFoundation.

## Tech Stack
- **Language**: Swift 6
- **Framework**: SwiftUI
- **Audio API**: AVFoundation
- **UI Architecture**: MVVM

## History

### [2026-01-21] Playlist Interaction Refinement | [log-20260121-interaction-refinement](./GEMINI--logs.md#log-20260121-interaction-refinement)
- Implemented **Spacebar** shortcut for Play/Pause.
- Added **Context Menu** (Reveal in Finder, Copy Path) to playlist items.
- Enabled **Full-Row Selection** and **Double-Click to Play**.

### [2026-01-21] Native Responsiveness Overhaul | [log-20260121-responsive-ui](./GEMINI--logs.md#log-20260121-responsive-ui)
- Removed all fixed-width constraints (app now stretches to any window size).
- Implemented a dynamic HUD with an adaptive spectrum analyzer.
- Ensured the playlist and search bar scale fluidly with the window.

### [2026-01-21] Native Feature Refinement | [log-20260121-feature-refinement](./GEMINI--logs.md#log-20260121-feature-refinement)
- Implemented bidirectional Shuffle (works with Prev and Next).
- Added Playlist Search with dynamic queue management.
- Unified Play/Pause transport control and removed Stop/Volume.
- Fixed progress bar seeking sensitivity.

### [2026-01-21] Native Swift Overhaul | [log-20260121-swift-native](./GEMINI--logs.md#log-20260121-swift-native)
- Completely rebuilt the app in Swift for native macOS performance.
- Implemented retro UI matching classic Winamp skin.
- Added Shuffle mode and Drag & Drop support.
- Implemented vertical resizing for the playlist area.

### [2026-01-21] Native Desktop Conversion (Deprecated) | [log-20260121-electron-desktop](./GEMINI--logs.md#log-20260121-electron-desktop)
- Wrapped the application in Electron (Later replaced by pure Swift).

### [2026-01-21] Core Build Completed (Web Version) | [log-20260121-winamp-build](./GEMINI--logs.md#log-20260121-winamp-build)
- Initial web-based implementation.

### [2026-01-21] Project Initialization | [log-20260121-init](./GEMINI--logs.md#log-20260121-init)
- Defined the project manifesto.
- Initialized core project documentation.
