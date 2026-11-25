# Music Player with 3-Band Equalizer

An Android music player built with Flutter for the **Bose Professional Software Development Intern – Frontend Applications** practical challenge.

## Overview

This application plays bundled MP3 audio assets offline, lets users add audio files from their Android device, provides Android media notification/lock-screen controls, and includes real-time 3-band audio equalization (**Low**, **Mid**, and **High**) using Android's native audio effects pipeline. It is designed for portrait-oriented Android phones with a Material 3 dark interface.

## Features

- **Bundled Audio Playback**: Plays three bundled MP3 tracks (`assets/audio/track1.mp3`, `track2.mp3`, `track3.mp3`) offline.
- **User-Selected Music**: **Add Music** button opens the Android system file picker so users can add local audio files (`mp3`, `wav`, `aac`, `m4a`, `ogg`, `flac`, `opus`) alongside bundled tracks.
- **Playback Controls**: Play, Pause, Previous track (restarts current track if `> 3s` elapsed, otherwise goes to previous), and Next track with automatic advance across the playlist.
- **5-Second Seek Controls & Progress Slider**: Rewind 5s and Forward 5s buttons (clamped to `0` and track duration) alongside a seekable slider with `mm:ss` elapsed time and total duration.
- **Real-Time 3-Band Equalizer** *(requires physical Android device verification)*: Adjusts **Low**, **Mid**, and **High** gain in dB while audio is playing, plus a **Reset** button to return all three bands to `0.0 dB` (flat).
- **Android Notification & Lock-Screen Controls** *(requires physical Android device verification)*: Displays current track title, artist label, play/pause, previous, and next controls in the Android media notification and lock screen.

## Screenshots

> **Placeholder:** Insert portrait screenshots from a physical Android device here after verification.

## Tech Stack & Packages

Verified from `pubspec.yaml`, `pubspec.lock`, and `flutter --version`:

- **Flutter**: `3.44.8` (`stable`)
- **Dart**: `3.12.2` (SDK constraint `^3.12.2`)
- **Target Platform**: Android
- **Packages**:
  - `just_audio: ^0.10.6` (resolved `0.10.6`) — Audio playback, playlist management, and `AndroidEqualizer`
  - `just_audio_background: ^0.0.1-beta.17` (resolved `0.0.1-beta.17`, using `audio_service: 0.18.19`) — Android media notification and lock-screen controls
  - `file_picker: ^13.4.1` (resolved `13.4.1`) — System file picker for selecting device audio files
  - `cupertino_icons: ^1.0.8` (resolved `1.0.9`)
  - `flutter_lints: ^6.0.0` (dev dependency)

## Project Architecture

- [`lib/main.dart`](lib/main.dart) (`MusicPlayerApp`): Locks portrait orientation, initializes `JustAudioBackground`, configures the Material 3 dark theme, and sets `PlayerScreen` as home.
- [`lib/models/track.dart`](lib/models/track.dart) (`Track`): Immutable model with `title`, `artist`, `path`, and `isAsset`.
- [`lib/services/audio_player_service.dart`](lib/services/audio_player_service.dart) (`AudioPlayerService`): `ChangeNotifier` managing a single `AudioPlayer` instance, bundled and user-selected playlist items, 5-second relative seeking, `AndroidEqualizer`, and stream subscriptions.
- [`lib/screens/player_screen.dart`](lib/screens/player_screen.dart) (`PlayerScreen`): Owns and disposes `AudioPlayerService`, triggers `FilePicker.pickFile(type: FileType.audio)`, and composes the player UI.
- [`lib/widgets/progress_slider.dart`](lib/widgets/progress_slider.dart) (`ProgressSlider`): Seek slider with `mm:ss` elapsed/duration labels and 5-second rewind/forward buttons.
- [`lib/widgets/playback_controls.dart`](lib/widgets/playback_controls.dart) (`PlaybackControls`): Previous, prominent circular Play/Pause, and Next buttons.
- [`lib/widgets/equalizer_controls.dart`](lib/widgets/equalizer_controls.dart) (`EqualizerControls`): `Equalizer` card with `Low`, `Mid`, `High` sliders, dB readouts, and `Reset` button.

## Audio Playback & Controls

- **Bundled Playback**: The three bundled tracks are registered under `assets/audio/` in `pubspec.yaml` and loaded as a `just_audio` playlist via `setAudioSources(...)` with `AudioSource.asset(...)`.
- **User-Selected Playback**: `FilePicker.pickFile(type: FileType.audio)` opens the Android system picker without requesting broad storage permissions. Selected files are validated, appended to the playlist via `addAudioSource(AudioSource.file(...))`, and played immediately. Cancellation is ignored cleanly, and invalid/unplayable files are rolled back with a `SnackBar` message.
- **5-Second Seek**: `seekBy(Duration)` adds `-5s` or `+5s` to the current position, clamps between `Duration.zero` and `duration`, and delegates to `seekTo(...)`.

## Equalizer Implementation

- **Native Android EQ API**: Uses `just_audio`'s `AndroidEqualizer` (backed by `android.media.audiofx.Equalizer`). No custom DSP algorithm is implemented.
- **Attachment**: `AndroidEqualizer` is passed into `AudioPipeline(androidAudioEffects: [_equalizer])` on the single `AudioPlayer` instance.
- **Band Mapping**: After enabling the equalizer, `AudioPlayerService` awaits `AndroidEqualizer.parameters` to read the device's band count and `centerFrequency` (in Hz), mapping **Low**, **Mid**, and **High** to the bands closest to `250 Hz`, `1000 Hz`, and `4000 Hz`.
- **Gain & Reset**: Uses the device-reported `minDecibels..maxDecibels` range in dB. Slider changes call `band.setGain(gainDb)` in real time without restarting playback; **Reset** sets all three mapped bands to `0.0 dB` and notifies the UI.

## Android Notification Controls & Configuration

- `JustAudioBackground.init(...)` is called in `main()` before `runApp`, and each `AudioSource` in the playlist is tagged with a `MediaItem` (`id`, `title`, `artist`).
- `android/app/src/main/kotlin/com/example/music_player/MainActivity.kt` extends `AudioServiceActivity` so the Flutter engine binds to the media service.
- `android/app/src/main/AndroidManifest.xml` declares:
  - `MODIFY_AUDIO_SETTINGS` (for `Equalizer`)
  - `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (for `AudioService` foreground media playback)
  - `POST_NOTIFICATIONS` (for Android 13+ notification visibility)
  - `com.ryanheise.audioservice.AudioService` (`foregroundServiceType="mediaPlayback"`) and `com.ryanheise.audioservice.MediaButtonReceiver`

## Challenges Faced

- **Inspecting `just_audio` `0.10.6` and `file_picker` `13.4.1` APIs**: `just_audio` `0.10.6` exposes `AndroidEqualizer.parameters` as a `Future` and `centerFrequency` in Hz (not milli-Hz), while `file_picker` `13.4.1` uses static `FilePicker.pickFile(...)` rather than `FilePicker.platform.pickFiles(...)`. Inspecting the installed package sources prevented runtime/API mismatches.
- **Personal Development Challenges** *(to be completed by the author)*:
  - *[Add any device-specific observations or learnings after testing on your Android phone.]*

## Installation & Running

1. **Install dependencies**:
   ```powershell
   flutter pub get
   ```
2. **Connect an Android device**:
   - Enable **Developer Options** and **USB Debugging** on your Android phone, connect via USB, and verify:
     ```powershell
     flutter devices
     ```
3. **Run the application**:
   ```powershell
   flutter run
   ```

## Testing

- Static analysis (`flutter analyze`) and Android build checks verify compilation, while real audio output, file picking, equalizer effects, and media notifications require **manual testing on a physical Android phone**:
  1. Launch in portrait on a physical Android phone and verify no layout overflow.
  2. Play/Pause bundled tracks, test Next/Previous, and drag the seek slider.
  3. Tap **Rewind 5s** and **Forward 5s** near the slider; verify 5-second jumps clamped at `00:00` and total duration.
  4. Tap **Add Music**, pick an audio file from the device, and verify it appears in the list and plays; also test canceling the picker.
  5. Adjust **Low**, **Mid**, and **High** EQ sliders while playing audio and tap **Reset** to verify `0.0 dB` flat reset.
  6. Pull down the Android notification shade (and check the lock screen) to verify track title, artist, Play/Pause, Previous, and Next controls.

## AI Tools Disclosure

- **ChatGPT** was used for planning, task breakdown, and prompt preparation.
- **Cline / AI coding assistance** (using Claude Sonnet 4.6 and Gemini) was used for coding assistance, code generation, debugging, and documentation.
- The final implementation will be reviewed and verified by the author.

## Known Limitations

- **Android-only Equalizer & Notifications**: `AndroidEqualizer` is Android-only; EQ controls are disabled on other platforms or emulators without `audiofx` support.
- **Static Bundled Metadata**: Bundled tracks use static titles (`Track 1`–`Track 3`) and `Unknown Artist`; device tracks use the filename and `Device Audio` rather than parsing ID3 tags.
- **Session-Only Added Tracks**: User-selected tracks are kept in memory for the current app session (no local database persistence).
- **3-Band Mapping**: Maps `Low`, `Mid`, and `High` onto three representative bands of the device's native equalizer.
- **Physical Device Verification Pending**: Real-device playback, file picking, EQ audio output, and notification controls have not yet been confirmed on a physical Android phone.

## License

No license has been selected yet. *(Placeholder — add a license file or notice if required.)*

## Audio Assets Attribution

Credits from the original project setup for the bundled audio files:
- `bensound.com` (License code: `AOENVH17UKINZJM7`, Artist: Lunar Years)
- Sub_Clair from Pixabay
- ikoliks from Pixabay
