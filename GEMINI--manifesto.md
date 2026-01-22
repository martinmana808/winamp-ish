# Winamp Clone - Manifesto

## The Spirit
In a world of bloated streaming services, complex libraries, and algorithmic "discoveries," we return to the core of music listening: **The File.**

This is not a library manager. This is not a social network for music. This is a **player**. 

## The Pivot to Native
While web technologies are powerful, a true macOS experience requires **Native Swift**. We have transitioned from Electron to a pure Swift/SwiftUI implementation to leverage:
- **AVFoundation**: For industry-standard audio processing.
- **System Performance**: Lower CPU/Memory footprint than a browser-based shell.
- **Deep Integration**: Native Drag & Drop and window behaviors.

## The Solution
A simple, high-performance, and visually stunning native macOS MP3 player.
- **AVAudioEngine**: High-fidelity audio with real-time FFT spectrum analysis.
- **Hardware Integration**: System-wide media key support (MPRemoteCommandCenter).
- **Direct Access**: Use files from their original location without importing.
- **Retro Aesthetic**: A faithful recreation of the classic Winamp skin, modernized for 2026.

## Future Plans
- **Playlist Persistence**: Saving your queue and state between launches.
- **Custom Skinning**: Expanding the UI to allow classic .wsz skin loading.
- **CoreAudio EQ**: Implementing a 10-band native equalizer.
