import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sessions_provider.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key});

  static const List<double> speedOptions = [1.0, 2.0, 4.0, 8.0];

  String _formatTimestamp(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionsProvider>(
      builder: (context, sessions, _) {
        final total = sessions.totalPoints;
        if (total == 0) return const SizedBox.shrink();

        final currentPoint = sessions.currentPlaybackPoint;

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Slider
                Row(
                  children: [
                    Text(
                      '${sessions.playbackIndex + 1}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Expanded(
                      child: Slider(
                        value: sessions.playbackIndex.toDouble(),
                        min: 0,
                        max: (total - 1).toDouble(),
                        divisions: total > 1 ? total - 1 : 1,
                        onChanged: (value) {
                          sessions.seekTo(value.round());
                        },
                      ),
                    ),
                    Text(
                      '$total',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                // Point info
                if (currentPoint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(currentPoint.timestamp),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.speed, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${(currentPoint.speed * 3.6).toStringAsFixed(1)} km/h (${currentPoint.speed.toStringAsFixed(1)} m/s)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.height, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${currentPoint.altitude.toStringAsFixed(0)} m',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                // Transport controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Speed selector
                    SegmentedButton<double>(
                      segments: speedOptions.map((speed) {
                        return ButtonSegment(
                          value: speed,
                          label: Text('${speed.toStringAsFixed(0)}x'),
                        );
                      }).toList(),
                      selected: {sessions.playbackSpeed},
                      onSelectionChanged: (selection) {
                        sessions.setPlaybackSpeed(selection.first);
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: WidgetStatePropertyAll(
                          Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Previous
                    IconButton(
                      onPressed: sessions.playbackIndex > 0
                          ? sessions.stepBackward
                          : null,
                      icon: const Icon(Icons.skip_previous),
                      tooltip: 'Previous point',
                    ),
                    // Play/Pause
                    IconButton.filled(
                      onPressed: sessions.togglePlayback,
                      icon: Icon(
                        sessions.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      tooltip:
                          sessions.isPlaying ? 'Pause' : 'Play',
                    ),
                    // Next
                    IconButton(
                      onPressed: sessions.playbackIndex < total - 1
                          ? sessions.stepForward
                          : null,
                      icon: const Icon(Icons.skip_next),
                      tooltip: 'Next point',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
