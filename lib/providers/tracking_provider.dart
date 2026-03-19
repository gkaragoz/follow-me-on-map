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

class TrackingProvider extends ChangeNotifier {
  final LocationService _locationService;
  final ApiClient _apiClient;

  TrackingSession? _activeSession;
  StreamSubscription<LocationPoint>? _locationSubscription;
  LocationPoint? _currentLocation;
  int _tickRateMs = 1000;
  bool _isFollowing = true;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  TrackingProvider({
    required LocationService locationService,
    required ApiClient apiClient,
  })  : _locationService = locationService,
        _apiClient = apiClient;

  TrackingSession? get activeSession => _activeSession;
  LocationPoint? get currentLocation => _currentLocation;
  int get tickRateMs => _tickRateMs;
  bool get isTracking => _activeSession != null;
  bool get isFollowing => _isFollowing;
  List<LocationPoint> get trackPoints => _activeSession?.points ?? [];

  set isFollowing(bool value) {
    _isFollowing = value;
    notifyListeners();
  }

  void setTickRate(int ms) {
    _tickRateMs = ms;
    if (isTracking) {
      _locationService.stopTracking();
      _locationSubscription?.cancel();
      _startListening();
    }
    notifyListeners();
  }

  Future<bool> initLocation() async {
    final hasPermission = await _locationService.checkAndRequestPermission();
    if (hasPermission) {
      _currentLocation = await _locationService.getCurrentPosition();
      notifyListeners();
    }
    return hasPermission;
  }

  Future<void> startSession() async {
    final hasPermission = await _locationService.checkAndRequestPermission();
    if (!hasPermission) return;

    final now = DateTime.now();
    _activeSession = TrackingSession(
      id: const Uuid().v4(),
      name:
          'Session ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      startTime: now,
      tickRateMs: _tickRateMs,
    );

    // Connect WebSocket and notify server
    _connectWebSocket();
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
        _activeSession!.points.add(point);
        _updateDistance();

        // Stream point to server via WebSocket
        _sendWsMessage({
          'type': 'location',
          'sessionId': _activeSession!.id,
          'point': point.toJson(),
        });
      }
      notifyListeners();
    });
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

  Future<void> stopSession() async {
    if (_activeSession == null) return;

    _locationService.stopTracking();
    _locationSubscription?.cancel();
    _locationSubscription = null;

    _activeSession!.endTime = DateTime.now();

    // Notify server via WebSocket
    _sendWsMessage({
      'type': 'stop_session',
      'sessionId': _activeSession!.id,
      'endTime': _activeSession!.endTime!.toIso8601String(),
      'totalDistanceMeters': _activeSession!.totalDistanceMeters,
    });

    // Also save via REST as a complete update
    try {
      await _apiClient.updateSession(_activeSession!.id, {
        'endTime': _activeSession!.endTime!.toIso8601String(),
        'totalDistanceMeters': _activeSession!.totalDistanceMeters,
      });
    } catch (e) {
      debugPrint('Failed to update session via REST: $e');
    }

    _disconnectWebSocket();
    _activeSession = null;
    notifyListeners();
  }

  // ── WebSocket ────────────────────────────────────────────────────────

  void _connectWebSocket() {
    try {
      _wsChannel = _apiClient.connectTracking();
      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          // Handle incoming broadcasts (e.g., from other clients)
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            debugPrint('[WS] Received: ${data['type']}');
          } catch (e) {
            debugPrint('[WS] Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('[WS] Error: $error');
        },
        onDone: () {
          debugPrint('[WS] Connection closed');
        },
      );
    } catch (e) {
      debugPrint('[WS] Failed to connect: $e');
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
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationService.dispose();
    _disconnectWebSocket();
    super.dispose();
  }
}
