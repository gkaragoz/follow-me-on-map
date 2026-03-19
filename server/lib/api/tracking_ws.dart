import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared/shared.dart';
import '../db/database.dart';

class _ConnectedClient {
  final WebSocketChannel channel;
  final String clientId;
  String? activeSessionId;
  DateTime? sessionStartTime;
  LocationPoint? lastLocation;

  _ConnectedClient({
    required this.channel,
    required this.clientId,
  });
}

class TrackingWebSocket {
  final Database db;
  final Map<WebSocketChannel, _ConnectedClient> _clients = {};
  static const _maxSessionDuration = Duration(hours: 1);

  TrackingWebSocket(this.db);

  void handleConnection(WebSocketChannel channel) {
    print('[WS] Client connected (${_clients.length + 1} total)');

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
        _handleDisconnect(channel);
      },
      onError: (error) {
        _handleDisconnect(channel);
        print('[WS] Client error: $error');
      },
    );
  }

  void _handleDisconnect(WebSocketChannel channel) {
    final client = _clients[channel];
    if (client != null) {
      // Close active session
      if (client.activeSessionId != null) {
        db.updateSession(client.activeSessionId!, {
          'endTime': DateTime.now().toIso8601String(),
        });
        _broadcast(channel, {
          'type': 'session_stopped',
          'sessionId': client.activeSessionId,
          'clientId': client.clientId,
        });
      }
      // Notify others that this client left
      _broadcast(channel, {
        'type': 'client_disconnected',
        'clientId': client.clientId,
      });
    }
    _clients.remove(channel);
    print('[WS] Client disconnected (${_clients.length} remaining)');
  }

  void _handleMessage(
      WebSocketChannel channel, Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'register':
        final clientId = data['clientId'] as String;
        _clients[channel] = _ConnectedClient(
          channel: channel,
          clientId: clientId,
        );
        // Send current peers' locations to the new client
        final peers = <Map<String, dynamic>>[];
        for (final entry in _clients.entries) {
          final peer = entry.value;
          if (entry.key != channel && peer.lastLocation != null) {
            peers.add({
              'clientId': peer.clientId,
              'point': peer.lastLocation!.toJson(),
            });
          }
        }
        channel.sink.add(jsonEncode({
          'type': 'peers_snapshot',
          'peers': peers,
        }));
        // Notify others
        _broadcast(channel, {
          'type': 'client_connected',
          'clientId': clientId,
        });
        print('[WS] Client registered: $clientId');

      case 'location':
        final client = _clients[channel];
        if (client == null) return;

        final pointJson = data['point'] as Map<String, dynamic>;
        final point = LocationPoint.fromJson(pointJson);
        client.lastLocation = point;

        // Auto-create session if needed, or rotate if 1 hour exceeded
        _ensureSession(client, point.timestamp);

        // Save point to session
        if (client.activeSessionId != null) {
          db.addPoint(client.activeSessionId!, point);
        }

        // Broadcast to other clients
        _broadcast(channel, {
          'type': 'location_update',
          'clientId': client.clientId,
          'point': point.toJson(),
        });

      case 'start_session':
        final sessionJson = data['session'] as Map<String, dynamic>;
        final session = TrackingSession.fromJson(sessionJson);
        db.createSession(session);
        final client = _clients[channel];
        if (client != null) {
          client.activeSessionId = session.id;
          client.sessionStartTime = session.startTime;
        }
        _broadcast(channel, {
          'type': 'session_started',
          'session': session.toJsonSummary(),
          'clientId': client?.clientId,
        });
        print('[WS] Session started: ${session.id}');

      case 'stop_session':
        final sessionId = data['sessionId'] as String;
        final endTime = data['endTime'] as String?;
        final totalDistance = data['totalDistanceMeters'] as num?;
        db.updateSession(sessionId, {
          'endTime': endTime ?? DateTime.now().toIso8601String(),
          if (totalDistance != null)
            'totalDistanceMeters': totalDistance.toDouble(),
        });
        final client = _clients[channel];
        if (client != null) {
          client.activeSessionId = null;
          client.sessionStartTime = null;
        }
        _broadcast(channel, {
          'type': 'session_stopped',
          'sessionId': sessionId,
          'clientId': client?.clientId,
        });
        print('[WS] Session stopped: $sessionId');

      default:
        print('[WS] Unknown message type: $type');
    }
  }

  void _ensureSession(_ConnectedClient client, DateTime pointTime) {
    // Check if current session has exceeded 1 hour
    if (client.activeSessionId != null && client.sessionStartTime != null) {
      if (pointTime.difference(client.sessionStartTime!) >= _maxSessionDuration) {
        // Close current session
        db.updateSession(client.activeSessionId!, {
          'endTime': pointTime.toIso8601String(),
        });
        _broadcast(client.channel, {
          'type': 'session_rotated',
          'oldSessionId': client.activeSessionId,
          'clientId': client.clientId,
        });
        print('[WS] Session rotated for ${client.clientId}: ${client.activeSessionId}');
        client.activeSessionId = null;
        client.sessionStartTime = null;
      }
    }

    // Create new session if none active
    if (client.activeSessionId == null) {
      final now = pointTime;
      final sessionId =
          '${client.clientId}-${now.millisecondsSinceEpoch.toRadixString(16)}';
      final session = TrackingSession(
        id: sessionId,
        name:
            'Auto ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
        startTime: now,
        tickRateMs: 1000,
      );
      db.createSession(session);
      client.activeSessionId = sessionId;
      client.sessionStartTime = now;
      _broadcast(client.channel, {
        'type': 'session_started',
        'session': session.toJsonSummary(),
        'clientId': client.clientId,
      });
      print('[WS] Auto-session created for ${client.clientId}: $sessionId');
    }
  }

  void _broadcast(WebSocketChannel sender, Map<String, dynamic> message) {
    final encoded = jsonEncode(message);
    for (final entry in _clients.entries) {
      if (entry.key != sender) {
        entry.value.channel.sink.add(encoded);
      }
    }
  }
}
