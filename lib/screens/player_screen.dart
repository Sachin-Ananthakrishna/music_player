import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../widgets/equalizer_controls.dart';
import '../widgets/playback_controls.dart';
import '../widgets/progress_slider.dart';

/// Main music player screen for portrait Android phones.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final AudioPlayerService _audioService;

  @override
  void initState() {
    super.initState();
    _audioService = AudioPlayerService();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _pickAndAddMusic() async {
    try {
      final picked = await FilePicker.pickFile(type: FileType.audio);
      if (picked == null) return; // User canceled.

      final path = picked.path;
      if (path == null) {
        _showMessage('Could not access the selected audio file.');
        return;
      }

      final error = await _audioService.addTrackFromFile(path, picked.name);
      if (error != null) {
        _showMessage(error);
      }
    } catch (e) {
      _showMessage('Failed to open file picker.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _audioService,
          builder: (context, _) {
            final currentTrack = _audioService.currentTrack;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentTrack.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentTrack.artist,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProgressSlider(
                    position: _audioService.position,
                    duration: _audioService.duration,
                    onSeek: _audioService.seekTo,
                    onRewind5: () =>
                        _audioService.seekBy(const Duration(seconds: -5)),
                    onForward5: () =>
                        _audioService.seekBy(const Duration(seconds: 5)),
                  ),
                  const SizedBox(height: 12),
                  PlaybackControls(
                    isPlaying: _audioService.isPlaying,
                    onPrevious: _audioService.skipToPrevious,
                    onPlayPause: () {
                      if (_audioService.isPlaying) {
                        _audioService.pause();
                      } else {
                        _audioService.play();
                      }
                    },
                    onNext: _audioService.skipToNext,
                  ),
                  const SizedBox(height: 20),
                  EqualizerControls(
                    isReady: _audioService.equalizerReady,
                    minDb: _audioService.minGainDb,
                    maxDb: _audioService.maxGainDb,
                    lowGain: _audioService.lowGain,
                    midGain: _audioService.midGain,
                    highGain: _audioService.highGain,
                    onLowChanged: _audioService.setLowGain,
                    onMidChanged: _audioService.setMidGain,
                    onHighChanged: _audioService.setHighGain,
                    onReset: _audioService.resetEq,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tracks',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _pickAndAddMusic,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Music'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (int i = 0; i < _audioService.tracks.length; i++)
                          _TrackTile(
                            title: _audioService.tracks[i].title,
                            artist: _audioService.tracks[i].artist,
                            isSelected: i == _audioService.currentIndex,
                            isPlaying: i == _audioService.currentIndex &&
                                _audioService.isPlaying,
                            onTap: () => _audioService.playTrack(i),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final String title;
  final String artist;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;

  const _TrackTile({
    required this.title,
    required this.artist,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.25),
      leading: Icon(
        isPlaying ? Icons.equalizer_rounded : Icons.music_note_rounded,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isSelected
          ? Icon(
              isPlaying ? Icons.volume_up_rounded : Icons.check_rounded,
              color: colorScheme.primary,
              size: 20,
            )
          : null,
      onTap: onTap,
    );
  }
}
