import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/location_point.dart';
import '../models/tracking_session.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

class TrackingProvider extends ChangeNotifier {
  final LocationService _locationService;
  final StorageService _storageService;

  TrackingSession? _activeSession;
  StreamSubscription<LocationPoint>? _locationSubscription;
  LocationPoint? _currentLocation;
  int _tickRateMs = 1000;
  bool _isFollowing = true;

  TrackingProvider({
    required LocationService locationService,
    required StorageService storageService,
  })  : _locationService = locationService,
        _storageService = storageService;

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
    // If currently tracking, restart with new tick rate
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
      name: 'Session ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      startTime: now,
      tickRateMs: _tickRateMs,
    );

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
    const earthRadius = 6371000.0; // meters
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
    await _storageService.saveSession(_activeSession!);

    _activeSession = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
