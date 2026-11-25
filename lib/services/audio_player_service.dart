import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';

/// All three bundled tracks. Titles and artist labels are hard-coded because
/// the asset files carry no embedded metadata readable at runtime.
const List<Track> _bundledTracks = [
  Track(
    title: 'Track 1',
    artist: 'Unknown Artist',
    assetPath: 'assets/audio/track1.mp3',
  ),
  Track(
    title: 'Track 2',
    artist: 'Unknown Artist',
    assetPath: 'assets/audio/track2.mp3',
  ),
  Track(
    title: 'Track 3',
    artist: 'Unknown Artist',
    assetPath: 'assets/audio/track3.mp3',
  ),
];

/// Manages audio playback and the native Android equalizer.
///
/// The equalizer is wired through just_audio's [AudioPipeline] so it is
/// attached directly to the same audio session as the player — no extra
/// MethodChannel glue is needed.
///
/// Callers should [dispose] this service when done to release resources.
class AudioPlayerService extends ChangeNotifier {
  // ── Equalizer (Android only) ──────────────────────────────────────────────

  /// Non-null on Android; null on every other platform (or if init failed).
  final AndroidEqualizer? _equalizer;

  // ── Player ────────────────────────────────────────────────────────────────

  late final AudioPlayer _player;

  // ── Track list ────────────────────────────────────────────────────────────

  final List<Track> _tracks = List.unmodifiable(_bundledTracks);
  int _currentIndex = 0;

  // ── EQ band indices resolved after AndroidEqualizer.parameters is ready ──

  int _lowBandIndex = -1;   // closest to  250 Hz
  int _midBandIndex = -1;   // closest to 1000 Hz
  int _highBandIndex = -1;  // closest to 4000 Hz

  // ── Cached parameters (fetched once from the native EQ) ───────────────────

  AndroidEqualizerParameters? _eqParams;

  // ── Public state snapshots (kept in sync via stream subscriptions) ─────────

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// True after the EQ was successfully initialised and enabled.
  bool _equalizerReady = false;
  bool _disposed = false;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  // ── Constructor ───────────────────────────────────────────────────────────

  AudioPlayerService()
      : _equalizer = defaultTargetPlatform == TargetPlatform.android
            ? AndroidEqualizer()
            : null {
    _initPlayer();
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Track> get tracks => _tracks;
  Track get currentTrack => _tracks[_currentIndex];
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get equalizerReady => _equalizerReady;

  /// The cached EQ parameters (band list, gain range).
  /// Non-null only after [_equalizerReady] becomes true.
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

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _initPlayer() async {
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
      // Auto-advance to the next track when the current one finishes.
      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          skipToNext();
        }
      }),
    ]);

    await _loadCurrentTrack();

    if (_equalizer != null) {
      await _initEqualizer();
    }
  }

  Future<void> _loadCurrentTrack() async {
    try {
      await _player.setAudioSource(
        AudioSource.asset(_tracks[_currentIndex].assetPath),
        preload: true,
      );
    } catch (e) {
      debugPrint('AudioPlayerService: failed to load '
          '"${_tracks[_currentIndex].assetPath}": $e');
    }
  }

  /// Enables the [AndroidEqualizer] and resolves which bands map to Low, Mid,
  /// and High.
  ///
  /// [AndroidEqualizer.parameters] is a [Future] that completes once the
  /// native EQ is attached to the audio session and responds. Frequencies are
  /// reported in milli-Hz (double), so 250 Hz → 250000.0.
  ///
  /// We pick the three bands by proximity to these canonical centre freqs:
  ///   Low  → 250 Hz, Mid → 1000 Hz, High → 4000 Hz
  Future<void> _initEqualizer() async {
    // _initEqualizer() is only called when _equalizer != null.
    final eq = _equalizer;
    if (eq == null) return;
    try {
      await eq.setEnabled(true);

      // This future completes when the native side reports the band layout.
      final params = await eq.parameters;

      if (params.bands.isEmpty) {
        debugPrint('AudioPlayerService: EQ reports 0 bands — giving up.');
        return;
      }

      _eqParams = params;
      // centerFrequency from just_audio is in Hz.
      _lowBandIndex  = _closestBandIndex(params.bands, 250.0);
      _midBandIndex  = _closestBandIndex(params.bands, 1000.0);
      _highBandIndex = _closestBandIndex(params.bands, 4000.0);

      _equalizerReady = true;
      _safeNotifyListeners();

      debugPrint(
        'AudioPlayerService: EQ ready. ${params.bands.length} bands | '
        'gain range: ${params.minDecibels}..${params.maxDecibels} dB | '
        'Low→${params.bands[_lowBandIndex].centerFrequency} Hz, '
        'Mid→${params.bands[_midBandIndex].centerFrequency} Hz, '
        'High→${params.bands[_highBandIndex].centerFrequency} Hz',
      );
    } catch (e) {
      // EQ init failed (e.g., emulator with no audiofx support). We log the
      // error and leave _equalizerReady = false so the UI disables EQ controls.
      debugPrint('AudioPlayerService: equalizer init failed: $e');
    }
  }

  /// Returns the index of the band whose [centerFrequency] (Hz) is
  /// nearest to [targetHz].
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

  // ── Playback controls ─────────────────────────────────────────────────────

  /// Loads and starts playing the track at [index].
  Future<void> playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    _currentIndex = index;
    _safeNotifyListeners();
    await _loadCurrentTrack();
    await play();
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

  Future<void> skipToNext() async {
    final next = (_currentIndex + 1) % _tracks.length;
    await _switchTrack(next);
  }

  /// Restarts the current track if more than 3 s have elapsed;
  /// otherwise moves to the previous track.
  Future<void> skipToPrevious() async {
    if (_position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    final prev = (_currentIndex - 1 + _tracks.length) % _tracks.length;
    await _switchTrack(prev);
  }

  Future<void> _switchTrack(int index) async {
    final wasPlaying = _isPlaying;
    _currentIndex = index;
    notifyListeners();
    await _loadCurrentTrack();
    if (wasPlaying) {
      await _player.play();
    }
  }

  // ── Equalizer controls ────────────────────────────────────────────────────

  /// Sets the Low-band gain in dB. Applies immediately while audio is playing.
  Future<void> setLowGain(double gainDb) =>
      _setBandGain(_lowBandIndex, gainDb);

  /// Sets the Mid-band gain in dB.
  Future<void> setMidGain(double gainDb) =>
      _setBandGain(_midBandIndex, gainDb);

  /// Sets the High-band gain in dB.
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

  // ── Disposal ──────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    // Disposing the AudioPlayer automatically detaches all AudioEffects
    // registered in its AudioPipeline, including the AndroidEqualizer.
    await _player.dispose();
    super.dispose();
  }
}
