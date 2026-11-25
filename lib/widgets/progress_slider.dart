import 'package:flutter/material.dart';

/// Displays a seekable playback slider with elapsed time, total duration, and 5-second rewind/forward buttons.
/// Tracks drag state locally so incoming position updates do not cause the slider thumb or elapsed label to jump while the user is scrubbing.
class ProgressSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onRewind5;
  final VoidCallback onForward5;

  const ProgressSlider({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onRewind5,
    required this.onForward5,
  });

  @override
  State<ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<ProgressSlider> {
  bool _isDragging = false;
  double _dragValueMs = 0.0;

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds.toDouble();
    final hasDuration = totalMs > 0;
    final maxMs = hasDuration ? totalMs : 1.0;

    final currentMs = _isDragging
        ? _dragValueMs.clamp(0.0, maxMs)
        : widget.position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    final displayedPosition = _isDragging
        ? Duration(milliseconds: currentMs.round())
        : widget.position;

    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            min: 0.0,
            max: maxMs,
            value: currentMs,
            onChanged: hasDuration
                ? (value) {
                    setState(() {
                      _isDragging = true;
                      _dragValueMs = value;
                    });
                  }
                : null,
            onChangeEnd: hasDuration
                ? (value) {
                    widget.onSeek(Duration(milliseconds: value.round()));
                    setState(() {
                      _isDragging = false;
                    });
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(displayedPosition), style: textStyle),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: hasDuration ? widget.onRewind5 : null,
                    icon: const Icon(Icons.replay_5_rounded),
                    iconSize: 24,
                    tooltip: 'Rewind 5 seconds',
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: hasDuration ? widget.onForward5 : null,
                    icon: const Icon(Icons.forward_5_rounded),
                    iconSize: 24,
                    tooltip: 'Forward 5 seconds',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(_formatDuration(widget.duration), style: textStyle),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
