/// A single playable audio track bundled with the app.
class Track {
  /// Display title of the track.
  final String title;

  /// Artist name, or a default label when no metadata is available.
  final String artist;

  /// Asset path to the audio file (e.g. 'assets/audio/track1.mp3').
  final String assetPath;

  const Track({
    required this.title,
    required this.artist,
    required this.assetPath,
  });
}
