import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/location_point.dart';
import '../models/tracking_session.dart';
import '../services/location_service.dart';
import '../services/api_client.dart';

/// Represents another connected client's live position.
class PeerLocation {
  final String clientId;
  LocationPoint point;

  PeerLocation({required this.clientId, required this.point});
}

class TrackingProvider extends ChangeNotifier {
  final LocationService _locationService;
  final ApiClient _apiClient;

  // Own tracking state
  TrackingSession? _activeSession;
  StreamSubscription<LocationPoint>? _locationSubscription;
  LocationPoint? _currentLocation;
  int _tickRateMs = 1000;
  bool _isFollowing = true;
  bool _isConnected = false;
  late final String _clientId;

  // Peer tracking
  final Map<String, PeerLocation> _peers = {};

  // Session rotation
  static const _maxSessionDuration = Duration(hours: 1);

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  TrackingProvider({
    required LocationService locationService,
    required ApiClient apiClient,
  })  : _locationService = locationService,
        _apiClient = apiClient,
        _clientId = const Uuid().v4().substring(0, 8);

  TrackingSession? get activeSession => _activeSession;
  LocationPoint? get currentLocation => _currentLocation;
  int get tickRateMs => _tickRateMs;
  bool get isTracking => _activeSession != null;
  bool get isFollowing => _isFollowing;
  bool get isConnected => _isConnected;
  String get clientId => _clientId;
  List<LocationPoint> get trackPoints => _activeSession?.points ?? [];
  Map<String, PeerLocation> get peers => Map.unmodifiable(_peers);

  set isFollowing(bool value) {
    _isFollowing = value;
    notifyListeners();
  }

  /// Initialize location and auto-start tracking.
  Future<bool> initLocation() async {
    final hasPermission = await _locationService.checkAndRequestPermission();
    if (hasPermission) {
      _currentLocation = await _locationService.getCurrentPosition();
      notifyListeners();
      // Auto-start tracking
      _connectAndTrack();
    }
    return hasPermission;
  }

  /// Connect to server and start streaming location automatically.
  Future<void> _connectAndTrack() async {
    _connectWebSocket();

    final now = DateTime.now();
    _activeSession = TrackingSession(
      id: '$_clientId-${now.millisecondsSinceEpoch.toRadixString(16)}',
      name:
          'Auto ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      startTime: now,
      tickRateMs: _tickRateMs,
    );

    _sendWsMessage({
      'type': 'start_session',
      'session': _activeSession!.toJson(),
    });

    _startListening();
    notifyListeners();
  }

  void _startListening() {
    _locationService.startTracking(tickRateMs: _tickRateMs);
    _locationSubscription = _locationService.locationStream.listen((point) {
      _currentLocation = point;
      if (_activeSession != null) {
        // Check for 1-hour rotation
        if (point.timestamp.difference(_activeSession!.startTime) >=
            _maxSessionDuration) {
          _rotateSession(point.timestamp);
        }

        _activeSession!.points.add(point);
        _updateDistance();

        _sendWsMessage({
          'type': 'location',
          'point': point.toJson(),
        });
      }
      notifyListeners();
    });
  }

  void _rotateSession(DateTime now) {
    // Close current session
    _activeSession!.endTime = now;
    _sendWsMessage({
      'type': 'stop_session',
      'sessionId': _activeSession!.id,
      'endTime': now.toIso8601String(),
      'totalDistanceMeters': _activeSession!.totalDistanceMeters,
    });

    // Start new session
    _activeSession = TrackingSession(
      id: '$_clientId-${now.millisecondsSinceEpoch.toRadixString(16)}',
      name:
          'Auto ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      startTime: now,
      tickRateMs: _tickRateMs,
    );

    _sendWsMessage({
      'type': 'start_session',
      'session': _activeSession!.toJson(),
    });

    debugPrint('[Tracking] Session rotated at $now');
  }

  void _updateDistance() {
    final points = _activeSession!.points;
    if (points.length < 2) return;

    final last = points[points.length - 1];
    final prev = points[points.length - 2];
    _activeSession!.totalDistanceMeters += _calculateDistance(
      prev.latitude,
      prev.longitude,
      last.latitude,
      last.longitude,
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  // ── WebSocket ────────────────────────────────────────────────────────

  void _connectWebSocket() {
    try {
      _wsChannel = _apiClient.connectTracking();
      _isConnected = true;

      // Register this client
      _sendWsMessage({
        'type': 'register',
        'clientId': _clientId,
      });

      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          try {
            final data =
                jsonDecode(message as String) as Map<String, dynamic>;
            _handleWsMessage(data);
          } catch (e) {
            debugPrint('[WS] Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('[WS] Error: $error');
          _isConnected = false;
          notifyListeners();
        },
        onDone: () {
          debugPrint('[WS] Connection closed');
          _isConnected = false;
          notifyListeners();
        },
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[WS] Failed to connect: $e');
      _isConnected = false;
    }
  }

  void _handleWsMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'location_update':
        final peerId = data['clientId'] as String;
        final pointJson = data['point'] as Map<String, dynamic>;
        final point = LocationPoint.fromJson(pointJson);
        _peers[peerId] = PeerLocation(clientId: peerId, point: point);
        notifyListeners();

      case 'peers_snapshot':
        final peersJson = data['peers'] as List<dynamic>;
        for (final peer in peersJson) {
          final peerMap = peer as Map<String, dynamic>;
          final peerId = peerMap['clientId'] as String;
          final point =
              LocationPoint.fromJson(peerMap['point'] as Map<String, dynamic>);
          _peers[peerId] = PeerLocation(clientId: peerId, point: point);
        }
        notifyListeners();

      case 'client_connected':
        debugPrint('[WS] Peer connected: ${data['clientId']}');

      case 'client_disconnected':
        final peerId = data['clientId'] as String;
        _peers.remove(peerId);
        notifyListeners();

      case 'session_rotated':
        debugPrint('[WS] Peer session rotated: ${data['clientId']}');

      default:
        debugPrint('[WS] Received: $type');
    }
  }

  void _sendWsMessage(Map<String, dynamic> message) {
    try {
      _wsChannel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[WS] Failed to send message: $e');
    }
  }

  void _disconnectWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnected = false;
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationService.dispose();
    _disconnectWebSocket();
    super.dispose();
  }
}
