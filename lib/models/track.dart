/// A single playable audio track, either bundled as an asset or picked from the user's device.
class Track {
  /// Display title of the track.
  final String title;

  /// Artist name, or a default label when no metadata is available.
  final String artist;

  /// Asset path (when [isAsset] is true) or local file path on the device.
  final String path;

  /// True for bundled Flutter assets; false for user-selected device files.
  final bool isAsset;

  const Track({
    required this.title,
    required this.artist,
    required this.path,
    this.isAsset = true,
  });
}
