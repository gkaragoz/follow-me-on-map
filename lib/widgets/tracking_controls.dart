import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracking_provider.dart';

class TrackingControls extends StatelessWidget {
  const TrackingControls({super.key});

  static const List<int> tickRateOptions = [500, 1000, 2000, 5000, 10000];

  String _formatTickRate(int ms) {
    if (ms < 1000) return '${ms}ms';
    return '${ms ~/ 1000}s';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(
      builder: (context, tracking, _) {
        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tick rate selector
                Row(
                  children: [
                    const Icon(Icons.speed, size: 20),
                    const SizedBox(width: 8),
                    const Text('GPS Rate:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int>(
                        value: tracking.tickRateMs,
                        isExpanded: true,
                        items: tickRateOptions.map((rate) {
                          return DropdownMenuItem(
                            value: rate,
                            child: Text(_formatTickRate(rate)),
                          );
                        }).toList(),
                        onChanged: tracking.isTracking
                            ? null
                            : (value) {
                                if (value != null) {
                                  tracking.setTickRate(value);
                                }
                              },
                      ),
                    ),
                  ],
                ),
                // Session info (when tracking)
                if (tracking.isTracking) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _InfoChip(
                        icon: Icons.timeline,
                        label: '${tracking.trackPoints.length} pts',
                      ),
                      _InfoChip(
                        icon: Icons.straighten,
                        label: _formatDistance(
                          tracking.activeSession?.totalDistanceMeters ?? 0,
                        ),
                      ),
                      _InfoChip(
                        icon: Icons.timer,
                        label: _formatDuration(
                          tracking.activeSession?.duration ?? Duration.zero,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // Start/Stop button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (tracking.isTracking) {
                        tracking.stopSession();
                      } else {
                        tracking.startSession();
                      }
                    },
                    icon: Icon(
                      tracking.isTracking ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(
                      tracking.isTracking ? 'Stop Session' : 'Start Session',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          tracking.isTracking ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
