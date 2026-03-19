import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/location_point.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<LocationPoint>.broadcast();

  Stream<LocationPoint> get locationStream => _locationController.stream;

  Timer? _tickTimer;
  Position? _latestPosition;

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<LocationPoint?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return _positionToLocationPoint(position);
    } catch (e) {
      return null;
    }
  }

  void startTracking({required int tickRateMs}) {
    stopTracking();

    // Listen to position stream with high accuracy and no distance filter
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      _latestPosition = position;
    });

    // Emit location points at the configured tick rate
    _tickTimer = Timer.periodic(
      Duration(milliseconds: tickRateMs),
      (_) {
        if (_latestPosition != null) {
          _locationController.add(_positionToLocationPoint(_latestPosition!));
        }
      },
    );
  }

  void stopTracking() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _latestPosition = null;
  }

  LocationPoint _positionToLocationPoint(Position position) {
    return LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );
  }

  void dispose() {
    stopTracking();
    _locationController.close();
  }
}
