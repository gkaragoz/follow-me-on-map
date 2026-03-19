import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared/shared.dart';

class Database {
  final String _connectionString;
  late Db _db;
  late DbCollection _sessions;

  Database(this._connectionString);

  Future<void> init() async {
    _db = await Db.create(_connectionString);
    await _db.open();
    _sessions = _db.collection('sessions');
    await _sessions.createIndex(keys: {'startTime': -1});
    print('Connected to MongoDB');
  }

  Future<List<(TrackingSession, int)>> getAllSessions() async {
    final docs = await _sessions.find(
      where.sortBy('startTime', descending: true),
    ).toList();
    return docs.map((doc) {
      final session = _docToSession(doc, includePoints: false);
      final pointCount = (doc['points'] as List?)?.length ?? 0;
      return (session, pointCount);
    }).toList();
  }

  Future<TrackingSession?> getSession(String id) async {
    final doc = await _sessions.findOne(where.eq('_id', id));
    if (doc == null) return null;
    return _docToSession(doc, includePoints: true);
  }

  Future<TrackingSession> createSession(TrackingSession session) async {
    await _sessions.insertOne({
      '_id': session.id,
      'name': session.name,
      'startTime': session.startTime.toIso8601String(),
      'endTime': session.endTime?.toIso8601String(),
      'tickRateMs': session.tickRateMs,
      'totalDistanceMeters': session.totalDistanceMeters,
      'points': session.points.map(_pointToDoc).toList(),
    });
    return session;
  }

  Future<void> updateSession(String id, Map<String, dynamic> updates) async {
    final setFields = <String, dynamic>{};
    if (updates.containsKey('name')) {
      setFields['name'] = updates['name'];
    }
    if (updates.containsKey('endTime')) {
      setFields['endTime'] = updates['endTime'];
    }
    if (updates.containsKey('totalDistanceMeters')) {
      setFields['totalDistanceMeters'] = updates['totalDistanceMeters'];
    }
    if (setFields.isEmpty) return;
    await _sessions.updateOne(
      where.eq('_id', id),
      {r'$set': setFields},
    );
  }

  Future<void> deleteSession(String id) async {
    await _sessions.deleteOne(where.eq('_id', id));
  }

  Future<int> addPoint(String sessionId, LocationPoint point) async {
    await _sessions.updateOne(
      where.eq('_id', sessionId),
      {
        r'$push': {'points': _pointToDoc(point)},
      },
    );
    return 0;
  }

  Future<void> close() async {
    await _db.close();
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  TrackingSession _docToSession(Map<String, dynamic> doc,
      {required bool includePoints}) {
    final points = <LocationPoint>[];
    if (includePoints && doc['points'] != null) {
      for (final p in doc['points'] as List) {
        points.add(_docToPoint(p as Map<String, dynamic>));
      }
    }
    return TrackingSession(
      id: doc['_id'] as String,
      name: doc['name'] as String,
      startTime: DateTime.parse(doc['startTime'] as String),
      endTime: doc['endTime'] != null
          ? DateTime.parse(doc['endTime'] as String)
          : null,
      tickRateMs: doc['tickRateMs'] as int? ?? 1000,
      totalDistanceMeters:
          (doc['totalDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      points: points,
    );
  }

  LocationPoint _docToPoint(Map<String, dynamic> doc) {
    return LocationPoint(
      latitude: (doc['latitude'] as num).toDouble(),
      longitude: (doc['longitude'] as num).toDouble(),
      altitude: (doc['altitude'] as num).toDouble(),
      speed: (doc['speed'] as num).toDouble(),
      accuracy: (doc['accuracy'] as num).toDouble(),
      timestamp: DateTime.parse(doc['timestamp'] as String),
    );
  }

  Map<String, dynamic> _pointToDoc(LocationPoint point) {
    return {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'altitude': point.altitude,
      'speed': point.speed,
      'accuracy': point.accuracy,
      'timestamp': point.timestamp.toIso8601String(),
    };
  }
}
