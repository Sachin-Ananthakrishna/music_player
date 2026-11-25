import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';

/// Bundled tracks shipped in assets/audio/. Titles and artist labels are static
/// because these asset files do not expose runtime ID3 metadata.
const List<Track> _bundledTracks = [
  Track(
    title: 'Track 1',
    artist: 'Unknown Artist',
    path: 'assets/audio/track1.mp3',
  ),
  Track(
    title: 'Track 2',
    artist: 'Unknown Artist',
    path: 'assets/audio/track2.mp3',
  ),
  Track(
    title: 'Track 3',
    artist: 'Unknown Artist',
    path: 'assets/audio/track3.mp3',
  ),
];

const Set<String> _supportedExtensions = {
  'mp3',
  'wav',
  'aac',
  'm4a',
  'ogg',
  'flac',
  'opus',
};

/// Manages audio playback, playlist state, Android media notifications, and
/// the native Android 3-band equalizer through a single [AudioPlayer].
class AudioPlayerService extends ChangeNotifier {
  /// Non-null on Android; null on other platforms where AndroidEqualizer is
  /// unsupported.
  final AndroidEqualizer? _equalizer;

  late final AudioPlayer _player;

  final List<Track> _tracks = List.of(_bundledTracks);
  int _currentIndex = 0;

  // Indices into AndroidEqualizerParameters.bands resolved by proximity to
  // 250 Hz (Low), 1000 Hz (Mid), and 4000 Hz (High).
  int _lowBandIndex = -1;
  int _midBandIndex = -1;
  int _highBandIndex = -1;

  AndroidEqualizerParameters? _eqParams;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _equalizerReady = false;
  bool _disposed = false;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  AudioPlayerService()
      : _equalizer = defaultTargetPlatform == TargetPlatform.android
            ? AndroidEqualizer()
            : null {
    _initPlayer();
  }

  List<Track> get tracks => List.unmodifiable(_tracks);
  Track get currentTrack => _tracks[_currentIndex];
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get equalizerReady => _equalizerReady;
  AndroidEqualizerParameters? get equalizerParameters => _eqParams;

  double get minGainDb => _eqParams?.minDecibels ?? -15.0;
  double get maxGainDb => _eqParams?.maxDecibels ?? 15.0;
  double get lowGain => _bandGain(_lowBandIndex);
  double get midGain => _bandGain(_midBandIndex);
  double get highGain => _bandGain(_highBandIndex);

  double _bandGain(int bandIndex) {
    final params = _eqParams;
    if (params == null || bandIndex < 0 || bandIndex >= params.bands.length) {
      return 0.0;
    }
    return params.bands[bandIndex].gain;
  }

  Future<void> _initPlayer() async {
    // Attach AndroidEqualizer to the player's AudioPipeline so it shares the
    // exact Android audio session ID with ExoPlayer.
    final pipeline = AudioPipeline(
      androidAudioEffects: _equalizer != null ? [_equalizer] : [],
    );

    _player = AudioPlayer(audioPipeline: pipeline);

    _subscriptions.addAll([
      _player.playingStream.listen((playing) {
        _isPlaying = playing;
        _safeNotifyListeners();
      }),
      _player.positionStream.listen((pos) {
        _position = pos;
        _safeNotifyListeners();
      }),
      _player.durationStream.listen((dur) {
        _duration = dur ?? Duration.zero;
        _safeNotifyListeners();
      }),
      // Keep _currentIndex in sync when tracks advance automatically or when
      // the user skips from the Android media notification / lock screen.
      _player.currentIndexStream.listen((index) {
        if (index != null && index >= 0 && index < _tracks.length) {
          _currentIndex = index;
          _safeNotifyListeners();
        }
      }),
      // Loop cleanly back to the first track and pause when the playlist ends.
      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed && !_player.hasNext) {
          _player.seek(Duration.zero, index: 0);
          _player.pause();
        }
      }),
    ]);

    await _loadInitialPlaylist();

    if (_equalizer != null) {
      await _initEqualizer();
    }
  }

  /// Loads the bundled tracks as a playlist so just_audio_background can drive
  /// notification next/previous actions directly on the single AudioPlayer.
  Future<void> _loadInitialPlaylist() async {
    try {
      await _player.setAudioSources(
        _tracks.map(_toAudioSource).toList(),
        initialIndex: 0,
        preload: true,
      );
    } catch (e) {
      debugPrint('AudioPlayerService: failed to load initial playlist: $e');
    }
  }

  /// Builds an [AudioSource] tagged with a [MediaItem] as required by
  /// just_audio_background to populate Android notification metadata.
  AudioSource _toAudioSource(Track track) {
    final mediaItem = MediaItem(
      id: track.path,
      title: track.title,
      artist: track.artist,
    );
    return track.isAsset
        ? AudioSource.asset(track.path, tag: mediaItem)
        : AudioSource.file(track.path, tag: mediaItem);
  }

  /// Enables AndroidEqualizer and maps Low/Mid/High to the closest available
  /// hardware bands on the device.
  Future<void> _initEqualizer() async {
    final eq = _equalizer;
    if (eq == null) return;
    try {
      await eq.setEnabled(true);
      final params = await eq.parameters;

      if (params.bands.isEmpty) {
        debugPrint('AudioPlayerService: EQ reports 0 bands.');
        return;
      }

      _eqParams = params;
      // just_audio reports AndroidEqualizerBand.centerFrequency in Hz.
      _lowBandIndex = _closestBandIndex(params.bands, 250.0);
      _midBandIndex = _closestBandIndex(params.bands, 1000.0);
      _highBandIndex = _closestBandIndex(params.bands, 4000.0);

      _equalizerReady = true;
      _safeNotifyListeners();
    } catch (e) {
      // On emulators or devices without audiofx support, leave _equalizerReady
      // false so the UI disables EQ controls instead of failing.
      debugPrint('AudioPlayerService: equalizer init failed: $e');
    }
  }

  int _closestBandIndex(List<AndroidEqualizerBand> bands, double targetHz) {
    int best = 0;
    double bestDiff = (bands[0].centerFrequency - targetHz).abs();
    for (int i = 1; i < bands.length; i++) {
      final diff = (bands[i].centerFrequency - targetHz).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  // ── Playback & playlist controls ──────────────────────────────────────────

  /// Adds a user-selected audio file from the device and starts playing it.
  /// Returns a user-facing error message if the file is unsupported or fails
  /// to load, or `null` on success.
  Future<String?> addTrackFromFile(String filePath, String fileName) async {
    final ext = _fileExtension(fileName);
    if (ext.isNotEmpty && !_supportedExtensions.contains(ext)) {
      return 'Unsupported audio format (.$ext).';
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return 'Selected audio file could not be found.';
    }

    final title = _stripExtension(fileName);
    final track = Track(
      title: title.isEmpty ? 'Device Track' : title,
      artist: 'Device Audio',
      path: filePath,
      isAsset: false,
    );

    final newIndex = _tracks.length;
    _tracks.add(track);
    try {
      await _player.addAudioSource(_toAudioSource(track));
      await _player.seek(Duration.zero, index: newIndex);
      _currentIndex = newIndex;
      _safeNotifyListeners();
      await play();
      return null;
    } catch (e) {
      // Roll back the failed entry so the track list stays consistent.
      if (_tracks.length > newIndex) {
        _tracks.removeAt(newIndex);
      }
      _safeNotifyListeners();
      debugPrint('AudioPlayerService: failed to load "$filePath": $e');
      return 'Unable to play "$fileName". The file may be unsupported or corrupted.';
    }
  }

  String _fileExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  String _stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// Loads and starts playing the track at [index].
  Future<void> playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    try {
      await _player.seek(Duration.zero, index: index);
      _currentIndex = index;
      _safeNotifyListeners();
      await play();
    } catch (e) {
      debugPrint('AudioPlayerService: playTrack($index) error: $e');
    }
  }

  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('AudioPlayerService: play() error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('AudioPlayerService: pause() error: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('AudioPlayerService: seekTo() error: $e');
    }
  }

  /// Seeks relative to the current position, clamped between 0 and [_duration].
  Future<void> seekBy(Duration offset) async {
    final target = _position + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration
            ? _duration
            : target);
    await seekTo(clamped);
  }

  Future<void> skipToNext() async {
    try {
      if (_player.hasNext) {
        await _player.seekToNext();
      } else {
        await _player.seek(Duration.zero, index: 0);
      }
    } catch (e) {
      debugPrint('AudioPlayerService: skipToNext() error: $e');
    }
  }

  /// Restarts the current track if more than 3 s have elapsed; otherwise moves
  /// to the previous track (wrapping to the last track from index 0).
  Future<void> skipToPrevious() async {
    if (_position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    try {
      if (_player.hasPrevious) {
        await _player.seekToPrevious();
      } else {
        await _player.seek(Duration.zero, index: _tracks.length - 1);
      }
    } catch (e) {
      debugPrint('AudioPlayerService: skipToPrevious() error: $e');
    }
  }

  // ── Equalizer controls ────────────────────────────────────────────────────

  Future<void> setLowGain(double gainDb) => _setBandGain(_lowBandIndex, gainDb);

  Future<void> setMidGain(double gainDb) => _setBandGain(_midBandIndex, gainDb);

  Future<void> setHighGain(double gainDb) =>
      _setBandGain(_highBandIndex, gainDb);

  /// Resets Low, Mid, and High bands to 0 dB (flat response).
  Future<void> resetEq() async {
    await Future.wait([
      _setBandGain(_lowBandIndex, 0.0),
      _setBandGain(_midBandIndex, 0.0),
      _setBandGain(_highBandIndex, 0.0),
    ]);
  }

  Future<void> _setBandGain(int bandIndex, double gainDb) async {
    if (!_equalizerReady || _eqParams == null || bandIndex < 0) return;
    if (bandIndex >= _eqParams!.bands.length) return;
    try {
      await _eqParams!.bands[bandIndex].setGain(gainDb);
      _safeNotifyListeners();
    } catch (e) {
      debugPrint(
          'AudioPlayerService: setGain(band=$bandIndex, gain=$gainDb) error: $e');
    }
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    // Disposing AudioPlayer releases all attached AudioPipeline effects,
    // including AndroidEqualizer, and tears down the background audio session.
    await _player.dispose();
    super.dispose();
  }
}
