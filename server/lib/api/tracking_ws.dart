import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared/shared.dart';
import '../db/database.dart';

class TrackingWebSocket {
  final Database db;
  final Set<WebSocketChannel> _clients = {};

  TrackingWebSocket(this.db);

  void handleConnection(WebSocketChannel channel) {
    _clients.add(channel);
    print('[WS] Client connected (${_clients.length} total)');

    channel.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          _handleMessage(channel, data);
        } catch (e) {
          print('[WS] Error handling message: $e');
        }
      },
      onDone: () {
        _clients.remove(channel);
        print('[WS] Client disconnected (${_clients.length} remaining)');
      },
      onError: (error) {
        _clients.remove(channel);
        print('[WS] Client error: $error');
      },
    );
  }

  void _handleMessage(
      WebSocketChannel sender, Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'start_session':
        final sessionJson = data['session'] as Map<String, dynamic>;
        final session = TrackingSession.fromJson(sessionJson);
        db.createSession(session);
        _broadcast(sender, {
          'type': 'session_started',
          'session': session.toJsonSummary(),
        });
        print('[WS] Session started: ${session.id}');

      case 'location':
        final sessionId = data['sessionId'] as String;
        final pointJson = data['point'] as Map<String, dynamic>;
        final point = LocationPoint.fromJson(pointJson);
        db.addPoint(sessionId, point);
        _broadcast(sender, {
          'type': 'location_update',
          'sessionId': sessionId,
          'point': point.toJson(),
        });

      case 'stop_session':
        final sessionId = data['sessionId'] as String;
        final endTime = data['endTime'] as String?;
        final totalDistance = data['totalDistanceMeters'] as num?;
        db.updateSession(sessionId, {
          'endTime': endTime ?? DateTime.now().toIso8601String(),
          if (totalDistance != null)
            'totalDistanceMeters': totalDistance.toDouble(),
        });
        _broadcast(sender, {
          'type': 'session_stopped',
          'sessionId': sessionId,
          'endTime': endTime ?? DateTime.now().toIso8601String(),
        });
        print('[WS] Session stopped: $sessionId');

      default:
        print('[WS] Unknown message type: $type');
    }
  }

  void _broadcast(WebSocketChannel sender, Map<String, dynamic> message) {
    final encoded = jsonEncode(message);
    for (final client in _clients) {
      if (client != sender) {
        client.sink.add(encoded);
      }
    }
  }
}
