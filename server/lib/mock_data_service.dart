import 'dart:math';
import 'package:shared/shared.dart';
import 'db/database.dart';

class MockDataService {
  final Database _db;

  MockDataService(this._db);

  Future<void> seedIfEmpty() async {
    final existing = await _db.getAllSessions();
    if (existing.isNotEmpty) return;

    final sessions = [
      _bosphorusJog(),
      _sultanahmetWalk(),
      _kadikoyWaterfront(),
      _bebekToPark(),
      _shortEveningRun(),
    ];

    for (final session in sessions) {
      await _db.createSession(session);
    }
    print('Seeded ${sessions.length} mock sessions');
  }

  TrackingSession _bosphorusJog() {
    final start = DateTime(2026, 3, 18, 7, 15);
    final waypoints = [
      (41.0480, 29.0270),
      (41.0485, 29.0258),
      (41.0492, 29.0248),
      (41.0500, 29.0240),
      (41.0510, 29.0232),
      (41.0518, 29.0225),
      (41.0528, 29.0218),
      (41.0537, 29.0212),
      (41.0548, 29.0205),
      (41.0556, 29.0198),
      (41.0565, 29.0190),
      (41.0573, 29.0183),
      (41.0582, 29.0177),
      (41.0590, 29.0170),
    ];
    final points = _interpolateRoute(waypoints, start,
        intervalSeconds: 12, speedRange: (2.5, 3.8), altitudeBase: 5.0);
    return _buildSession(
        name: 'Morning Jog - Bosphorus',
        startTime: start,
        durationMinutes: 18,
        tickRateMs: 1000,
        points: points);
  }

  TrackingSession _sultanahmetWalk() {
    final start = DateTime(2026, 3, 16, 14, 30);
    final waypoints = [
      (41.0086, 28.9780),
      (41.0082, 28.9770),
      (41.0076, 28.9762),
      (41.0070, 28.9768),
      (41.0065, 28.9778),
      (41.0060, 28.9790),
      (41.0056, 28.9802),
      (41.0062, 28.9812),
      (41.0068, 28.9820),
      (41.0075, 28.9815),
      (41.0080, 28.9805),
      (41.0084, 28.9792),
    ];
    final points = _interpolateRoute(waypoints, start,
        intervalSeconds: 20, speedRange: (1.0, 1.8), altitudeBase: 40.0);
    return _buildSession(
        name: 'Sultanahmet Walk',
        startTime: start,
        durationMinutes: 25,
        tickRateMs: 2000,
        points: points);
  }

  TrackingSession _kadikoyWaterfront() {
    final start = DateTime(2026, 3, 15, 18, 0);
    final waypoints = [
      (40.9910, 29.0235),
      (40.9905, 29.0248),
      (40.9898, 29.0260),
      (40.9890, 29.0272),
      (40.9882, 29.0285),
      (40.9875, 29.0298),
      (40.9868, 29.0310),
      (40.9860, 29.0322),
      (40.9852, 29.0335),
      (40.9845, 29.0348),
      (40.9838, 29.0360),
      (40.9830, 29.0372),
      (40.9822, 29.0385),
      (40.9815, 29.0398),
      (40.9808, 29.0410),
      (40.9800, 29.0420),
    ];
    final points = _interpolateRoute(waypoints, start,
        intervalSeconds: 15, speedRange: (1.2, 2.0), altitudeBase: 8.0);
    return _buildSession(
        name: 'Kadıköy Waterfront',
        startTime: start,
        durationMinutes: 35,
        tickRateMs: 1000,
        points: points);
  }

  TrackingSession _bebekToPark() {
    final start = DateTime(2026, 3, 14, 10, 0);
    final waypoints = [
      (41.0770, 29.0440),
      (41.0778, 29.0432),
      (41.0785, 29.0420),
      (41.0793, 29.0408),
      (41.0800, 29.0395),
      (41.0808, 29.0382),
      (41.0815, 29.0370),
      (41.0822, 29.0358),
      (41.0828, 29.0345),
      (41.0835, 29.0335),
      (41.0842, 29.0325),
      (41.0850, 29.0315),
    ];
    final points = _interpolateRoute(waypoints, start,
        intervalSeconds: 18, speedRange: (1.5, 2.5), altitudeBase: 15.0);
    return _buildSession(
        name: 'Bebek → Rumeli Hisarı',
        startTime: start,
        durationMinutes: 22,
        tickRateMs: 2000,
        points: points);
  }

  TrackingSession _shortEveningRun() {
    final start = DateTime(2026, 3, 17, 19, 45);
    final waypoints = [
      (41.0440, 28.9950),
      (41.0445, 28.9942),
      (41.0452, 28.9935),
      (41.0458, 28.9928),
      (41.0464, 28.9920),
      (41.0470, 28.9912),
      (41.0465, 28.9905),
      (41.0458, 28.9898),
      (41.0450, 28.9905),
      (41.0444, 28.9915),
      (41.0440, 28.9928),
      (41.0438, 28.9942),
      (41.0440, 28.9950),
    ];
    final points = _interpolateRoute(waypoints, start,
        intervalSeconds: 8, speedRange: (2.8, 4.2), altitudeBase: 65.0);
    return _buildSession(
        name: 'Evening Run - Maçka Park',
        startTime: start,
        durationMinutes: 10,
        tickRateMs: 500,
        points: points);
  }

  TrackingSession _buildSession({
    required String name,
    required DateTime startTime,
    required int durationMinutes,
    required int tickRateMs,
    required List<LocationPoint> points,
  }) {
    final totalDistance = _totalDistance(points);
    // Generate a deterministic UUID-like ID
    final id = '${name.hashCode.abs().toRadixString(16).padLeft(8, '0')}-'
        '${startTime.millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0')}';
    return TrackingSession(
      id: id,
      name: name,
      startTime: startTime,
      endTime: startTime.add(Duration(minutes: durationMinutes)),
      points: points,
      tickRateMs: tickRateMs,
      totalDistanceMeters: totalDistance,
    );
  }

  List<LocationPoint> _interpolateRoute(
    List<(double, double)> waypoints,
    DateTime startTime, {
    required int intervalSeconds,
    required (double, double) speedRange,
    required double altitudeBase,
  }) {
    final rng = Random(waypoints.hashCode);
    final points = <LocationPoint>[];
    var elapsed = 0;

    for (var i = 0; i < waypoints.length - 1; i++) {
      final (lat1, lon1) = waypoints[i];
      final (lat2, lon2) = waypoints[i + 1];

      for (var t = 0.0; t < 1.0; t += 0.33) {
        final lat =
            lat1 + (lat2 - lat1) * t + (rng.nextDouble() - 0.5) * 0.0001;
        final lon =
            lon1 + (lon2 - lon1) * t + (rng.nextDouble() - 0.5) * 0.0001;
        final speed =
            speedRange.$1 + rng.nextDouble() * (speedRange.$2 - speedRange.$1);
        final alt = altitudeBase + (rng.nextDouble() - 0.5) * 6.0;
        final accuracy = 3.0 + rng.nextDouble() * 8.0;

        points.add(LocationPoint(
          latitude: lat,
          longitude: lon,
          altitude: alt,
          speed: speed,
          accuracy: accuracy,
          timestamp: startTime.add(Duration(seconds: elapsed)),
        ));
        elapsed += intervalSeconds;
      }
    }

    final (lastLat, lastLon) = waypoints.last;
    points.add(LocationPoint(
      latitude: lastLat + (rng.nextDouble() - 0.5) * 0.00005,
      longitude: lastLon + (rng.nextDouble() - 0.5) * 0.00005,
      altitude: altitudeBase + (rng.nextDouble() - 0.5) * 4.0,
      speed: speedRange.$1 * 0.5,
      accuracy: 4.0,
      timestamp: startTime.add(Duration(seconds: elapsed)),
    ));

    return points;
  }

  double _totalDistance(List<LocationPoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _haversine(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;
}
