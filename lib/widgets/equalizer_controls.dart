import 'package:flutter/material.dart';

/// Real-time 3-band equalizer section (Low, Mid, High) with a Reset button.
class EqualizerControls extends StatelessWidget {
  final bool isReady;
  final double minDb;
  final double maxDb;
  final double lowGain;
  final double midGain;
  final double highGain;
  final ValueChanged<double> onLowChanged;
  final ValueChanged<double> onMidChanged;
  final ValueChanged<double> onHighChanged;
  final VoidCallback onReset;

  const EqualizerControls({
    super.key,
    required this.isReady,
    required this.minDb,
    required this.maxDb,
    required this.lowGain,
    required this.midGain,
    required this.highGain,
    required this.onLowChanged,
    required this.onMidChanged,
    required this.onHighChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Equalizer',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: isReady ? onReset : null,
                  child: const Text('Reset'),
                ),
              ],
            ),
            if (!isReady)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Equalizer unavailable on this device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _BandSliderRow(
              label: 'Low',
              value: lowGain,
              minDb: minDb,
              maxDb: maxDb,
              enabled: isReady,
              onChanged: onLowChanged,
            ),
            _BandSliderRow(
              label: 'Mid',
              value: midGain,
              minDb: minDb,
              maxDb: maxDb,
              enabled: isReady,
              onChanged: onMidChanged,
            ),
            _BandSliderRow(
              label: 'High',
              value: highGain,
              minDb: minDb,
              maxDb: maxDb,
              enabled: isReady,
              onChanged: onHighChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _BandSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double minDb;
  final double maxDb;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _BandSliderRow({
    required this.label,
    required this.value,
    required this.minDb,
    required this.maxDb,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeMin = minDb < maxDb ? minDb : -15.0;
    final safeMax = minDb < maxDb ? maxDb : 15.0;
    final clampedValue = value.clamp(safeMin, safeMax);

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            min: safeMin,
            max: safeMax,
            value: clampedValue,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            _formatDb(clampedValue),
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDb(double db) {
    final prefix = db > 0.05 ? '+' : '';
    return '$prefix${db.toStringAsFixed(1)} dB';
  }
}
