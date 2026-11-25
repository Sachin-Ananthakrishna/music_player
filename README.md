# Music Player with 3-Band Equalizer

An Android music player built with Flutter for the **Bose Professional Software Development Intern – Frontend Applications** practical challenge.

## Overview

This application plays bundled MP3 audio assets offline and provides real-time 3-band audio equalization (**Low**, **Mid**, and **High**) using Android's native audio effects pipeline. It is designed for portrait-oriented Android phones with a clean Material 3 dark interface.

## Features

- **Offline Bundled Audio Playback**: Plays three bundled MP3 tracks (`assets/audio/track1.mp3`, `track2.mp3`, `track3.mp3`) with no network or streaming dependencies.
- **Transport Controls**: Play, Pause, Previous track (restarts current track if `> 3s` elapsed, otherwise goes to previous), and Next track with automatic advance on track completion.
- **Seekable Progress Bar**: Displays elapsed time and total duration (`mm:ss`) and preserves local drag state while scrubbing so the slider does not jump.
- **Track Selection**: Lists all bundled tracks, highlights the active track, and switches playback on tap.
- **Real-Time 3-Band Equalizer** *(requires physical Android device verification)*: Adjusts **Low**, **Mid**, and **High** gain in dB while audio is playing, plus a **Reset** button to return all three bands to `0.0 dB` (flat).

## Screenshots

> **Placeholder:** Insert portrait screenshots from a physical Android device here after verification.

## Tech Stack

Verified from `pubspec.yaml`, `pubspec.lock`, and `flutter --version`:

- **Flutter**: `3.44.8` (`stable`)
- **Dart**: `3.12.2` (SDK constraint `^3.12.2`)
- **Audio Playback & Android EQ**: `just_audio: ^0.10.6` (resolved `0.10.6`)
- **Icons**: `cupertino_icons: ^1.0.8`
- **Linting (dev)**: `flutter_lints: ^6.0.0`
- **Target Platform**: Android (`android.media.audiofx.Equalizer` via `just_audio`'s `AndroidEqualizer`)

## Architecture

The project uses a straightforward separation between data model, audio service, screen, and reusable widgets without external state management packages:

- [`lib/main.dart`](lib/main.dart) (`MusicPlayerApp`): Configures portrait orientation lock, Material 3 dark theme, and `PlayerScreen` as the home route.
- [`lib/models/track.dart`](lib/models/track.dart) (`Track`): Immutable model holding `title`, `artist`, and `assetPath`.
- [`lib/services/audio_player_service.dart`](lib/services/audio_player_service.dart) (`AudioPlayerService`): `ChangeNotifier` managing a single `AudioPlayer` instance, bundled track loading, playback state/position/duration streams, and the `AndroidEqualizer`.
- [`lib/screens/player_screen.dart`](lib/screens/player_screen.dart) (`PlayerScreen`): Owns and disposes `AudioPlayerService`, listens to updates via `ListenableBuilder`, and composes the player layout.
- [`lib/widgets/progress_slider.dart`](lib/widgets/progress_slider.dart) (`ProgressSlider`): Seek slider with `mm:ss` elapsed and total duration labels.
- [`lib/widgets/playback_controls.dart`](lib/widgets/playback_controls.dart) (`PlaybackControls`): Previous, prominent circular Play/Pause, and Next buttons.
- [`lib/widgets/equalizer_controls.dart`](lib/widgets/equalizer_controls.dart) (`EqualizerControls`): `Equalizer` card with `Low`, `Mid`, `High` sliders, dB readouts, and `Reset` button.

## Audio Playback Implementation

- `AudioPlayerService` creates one `AudioPlayer` configured with an `AudioPipeline`.
- Bundled tracks are registered under `assets/audio/` in `pubspec.yaml` and loaded via `AudioSource.asset(...)`.
- Streams from `just_audio` (`playingStream`, `positionStream`, `durationStream`, and `processingStateStream`) update internal state and notify the UI.
- `seekTo(Duration)` seeks the active source; `playTrack(int)` loads and starts a selected track; `skipToNext()` and `skipToPrevious()` navigate across the three bundled tracks; reaching `ProcessingState.completed` automatically advances to the next track.

## Equalizer Implementation

- **Native Android EQ API**: Uses `just_audio`'s `AndroidEqualizer` (backed by Android's `android.media.audiofx.Equalizer`), with `<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />` declared in `android/app/src/main/AndroidManifest.xml`. No custom DSP algorithm is implemented.
- **Attachment**: `AndroidEqualizer` is passed into `AudioPipeline(androidAudioEffects: [_equalizer])` when constructing `AudioPlayer`, attaching it directly to the player's Android audio session.
- **Band Mapping**: After enabling the equalizer, `AudioPlayerService` awaits `AndroidEqualizer.parameters` to inspect the device's actual band count and `centerFrequency` (in Hz). It dynamically maps **Low**, **Mid**, and **High** to the available bands closest to `250 Hz`, `1000 Hz`, and `4000 Hz` respectively.
- **Gain Range & Units**: Uses the device-reported `minDecibels` and `maxDecibels` range in dB (falling back to `-15.0..15.0` dB for display if unavailable).
- **Real-Time Updates & Reset**: `setLowGain`, `setMidGain`, and `setHighGain` call `band.setGain(gainDb)` on the mapped `AndroidEqualizerBand` while audio is playing without restarting the track. `resetEq()` sets all three mapped bands to `0.0 dB` and notifies listeners so the sliders and dB labels reset together.

## Challenges Faced

- **Verifying `just_audio` `0.10.6` `AndroidEqualizer` API details**: In `just_audio` `0.10.6`, `AndroidEqualizer.parameters` is a `Future<AndroidEqualizerParameters>` rather than a stream, `AndroidEqualizerBand.centerFrequency` is reported in **Hz** (not milli-Hz), and the effect is released automatically when `AudioPlayer.dispose()` runs. Inspecting the resolved package source caught these mismatches before runtime.
- **Personal Development Challenges** *(to be completed by the author)*:
  - *[Add any device-specific observations, setup issues, or personal learnings here after testing on your Android phone.]*

## How to Run

1. **Install dependencies**:
   ```powershell
   flutter pub get
   ```
2. **Connect an Android device**:
   - Enable **Developer Options** and **USB Debugging** on your Android phone, connect via USB, and verify detection:
     ```powershell
     flutter devices
     ```
3. **Run the application**:
   ```powershell
   flutter run
   ```

## Testing

- **Static analysis & widget smoke test**: `flutter analyze` (`No issues found!`) and `flutter test` (`test/widget_test.dart`) passed locally.
- **Physical-device manual testing checklist** *(pending physical-device confirmation)*:
  1. Launch in portrait on a physical Android phone and verify no layout overflow.
  2. Tap Play/Pause and confirm audio starts/pauses and button icon updates.
  3. Drag the seek slider and verify elapsed time updates smoothly without jumping back, and playback seeks on release.
  4. Test Next, Previous (`< 3s` vs `> 3s` elapsed), and tapping each track in the list; confirm active track highlighting updates.
  5. While playing audio (preferably with headphones), adjust **Low**, **Mid**, and **High** sliders and confirm real-time tonal changes without track interruption.
  6. Tap **Reset** and verify all three sliders return to `0.0 dB` and the audio returns to flat response.

## AI Tools Disclosure

- **ChatGPT** was used for planning, task breakdown, and prompt preparation.
- **Cline / AI coding assistance** (using Claude Sonnet 4.6 and Gemini) was used for coding assistance, code generation, debugging, and documentation.
- The final implementation will be reviewed and verified by the author.

## Limitations

- **Android-only Equalizer**: `AndroidEqualizer` is only initialized when running on Android; EQ controls are disabled on other platforms or emulators lacking `audiofx` support.
- **Static Track Metadata**: Track titles (`Track 1`–`Track 3`) and `Unknown Artist` are hard-coded rather than parsed from ID3 tags.
- **3-Band Mapping**: Maps `Low`, `Mid`, and `High` onto three representative bands of the device's native equalizer rather than exposing every hardware band.
- **No Background Media Controls**: Lock-screen/notification media controls are not implemented.
- **Physical Device Verification**: Audio playback and equalizer output on a physical Android phone have not yet been confirmed by the author.

## License

No license has been selected yet. *(Placeholder — add a license file or notice if required.)*

## Audio Assets Attribution

Credits from the original project setup for the bundled audio files:
- `bensound.com` (License code: `AOENVH17UKINZJM7`, Artist: Lunar Years)
- Sub_Clair from Pixabay
- ikoliks from Pixabay
