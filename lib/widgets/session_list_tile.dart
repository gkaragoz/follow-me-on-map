import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tracking_session.dart';

class SessionListTile extends StatelessWidget {
  final TrackingSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const SessionListTile({
    super.key,
    required this.session,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
  });

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
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.route),
        ),
        title: Text(session.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(session.startTime)),
            Row(
              children: [
                Text(_formatDuration(session.duration)),
                const SizedBox(width: 12),
                Text(_formatDistance(session.totalDistanceMeters)),
                const SizedBox(width: 12),
                Text('${session.pointCount ?? session.points.length} pts'),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.share),
          onPressed: onShare,
        ),
        onTap: onTap,
      ),
    );
  }
}
