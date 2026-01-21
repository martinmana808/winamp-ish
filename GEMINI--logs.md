# Winamp Clone - The Vault

<a name="log-20260121-init"></a>
## [2026-01-21] Project Initialization

**User Prompt:**
make a simple winamp clone. 
an mp3 player that I can just throw mp3 in and they get played from their original location (no itunes-fucking-copying-ritual no library no nothing). Just an mp3 player with a list of files (temporary) that will play one after the other. Kind of a queue. 

**Implementation Plan:** 
(Pending)

**Walkthrough:**
(Pending)

<a name="log-20260121-winamp-build"></a>
## [2026-01-21] Winamp Build: Core Implementation

**User Prompt:**
make a simple winamp clone. 
an mp3 player that I can just throw mp3 in and they get played from their original location (no itunes-fucking-copying-ritual no library no nothing). Just an mp3 player with a list of files (temporary) that will play one after the other. Kind of a queue. 

**Implementation Plan:**
# Winamp Clone Implementation Plan

The goal is to create a sleek, modern, file-focused MP3 player that allows users to drop files and play them sequentially without any library management.

## User Review Required

> [!IMPORTANT]
> **Browser Restrictions**: Browsers cannot access local files by path for security reasons. The user MUST explicitly select files via a file picker or Drag & Drop. The "original location" playback is achieved by creating temporary object URLs for the selected blobs.

## Proposed Changes

### [Frontend/UI]

#### [NEW] [index.html](file:///Users/martinmana/Documents/Projects/winamp-clone/index.html)
- Main layout container.
- Player header with status display (track info, time, bitrate, etc.).
- Main control section (Play, Pause, Skip, Prev, Volume).
- Visualizer section (Canvas).
- Playlist section (interactive list).
- Hidden file input for file selection.

#### [NEW] [styles.css](file:///Users/martinmana/Documents/Projects/winamp-clone/styles.css)
- Custom design system:
    - **Palette**: Deep charcoal, vibrant ambers/blues for accents.
    - **Effects**: Glassmorphism (backdrop-filter), glowing borders.
    - **Typography**: Orbitron or similar tech-y font (via Google Fonts).
- Layout: Responsive, fixed-height player with scrollable playlist.

### [Logic/Audio]

#### [NEW] [app.js](file:///Users/martinmana/Documents/Projects/winamp-clone/app.js)
- **AudioContext Initialization**: Set up Web Audio API node graph (Source -> Analyser -> Gain -> Destination).
- **Playlist Manager**: State management for the current queue.
- **File Handler**: Processes `File` objects from input/DnD, extracts metadata (via dummy logic or lightweight library if needed, but I'll stick to filename first to keep it simple).
- **Playback Controls**: Logic for sequential playback, looping, and track switching.
- **Visualizer Engine**: RequestAnimationFrame loop to draw spectrum on canvas.

## Verification Plan

### Automated Tests
- N/A (Manual verification is more suitable for this UI/Audio focused project).

### Manual Verification
1.  Open `index.html` in browser.
2.  Drag and drop multiple MP3 files.
3.  Verify they appear in the playlist.
4.  Verify playback starts and continues to the next track.
5.  Check visualizer response.
6.  Test playback controls (play/pause/skip).

**Walkthrough:**
# Winamp Clone Walkthrough

I have built a simple, modern Winamp clone using Vanilla JS, HTML5, and the Web Audio API.

## Features Implemented
- **Pure File Playback**: No library or database. Files are played directly from user selection.
- **Temporary Queue**: Drag and drop files to create a temporary playlist for the session.
- **Glassmorphism Design**: A sleek, dark, premium aesthetic with backdrop blurs and glowing accents.
- **Web Audio Core**: Integrated `AudioContext` with `AnalyserNode` for real-time visualization.
- **Spectrum Visualizer**: A custom canvas-based spectrum visualizer that reacts to the music.
- **Controls**: Play, Pause, Stop, Previous/Next, Seek, and Volume slider.

## How to Use
1.  Open `index.html` in your browser.
2.  Press the **+ ADD** button or **Drag & Drop** your MP3 files into the player.
3.  Click on any track in the playlist to play it immediately, or hit **PLAY**.
4.  The player will automatically advance to the next track when the current one ends.

## Technical Details
- **File Handling**: Uses `URL.createObjectURL(file)` to create temporary playback links for the browser.
- **Visualizer**: Uses `requestAnimationFrame` and `getByteFrequencyData` to render the audio spectrum in real-time.

> [!NOTE]
> The browser tool encountered an issue during verification, but the code is complete and ready for manual testing.
