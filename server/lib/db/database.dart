import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:shared/shared.dart';

class Database {
  final sql.Database _db;

  Database(String path) : _db = sql.sqlite3.open(path);

  void init() {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        tick_rate_ms INTEGER NOT NULL DEFAULT 1000,
        total_distance_meters REAL NOT NULL DEFAULT 0.0
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS location_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL NOT NULL,
        speed REAL NOT NULL,
        accuracy REAL NOT NULL,
        timestamp TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_points_session
      ON location_points(session_id, sort_order)
    ''');
  }

  List<(TrackingSession, int)> getAllSessions() {
    final result = _db.select('''
      SELECT s.*, COUNT(lp.id) as point_count
      FROM sessions s
      LEFT JOIN location_points lp ON lp.session_id = s.id
      GROUP BY s.id
      ORDER BY s.start_time DESC
    ''');
    return result.map((row) {
      final session = _rowToSession(row);
      final pointCount = row['point_count'] as int;
      return (session, pointCount);
    }).toList();
  }

  TrackingSession? getSession(String id) {
    final result = _db.select(
      'SELECT * FROM sessions WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;

    final session = _rowToSession(result.first);
    final points = _db.select(
      'SELECT * FROM location_points WHERE session_id = ? ORDER BY sort_order',
      [id],
    );
    for (final row in points) {
      session.points.add(_rowToPoint(row));
    }
    return session;
  }

  TrackingSession createSession(TrackingSession session) {
    _db.execute(
      '''INSERT INTO sessions (id, name, start_time, end_time, tick_rate_ms, total_distance_meters)
         VALUES (?, ?, ?, ?, ?, ?)''',
      [
        session.id,
        session.name,
        session.startTime.toIso8601String(),
        session.endTime?.toIso8601String(),
        session.tickRateMs,
        session.totalDistanceMeters,
      ],
    );

    for (var i = 0; i < session.points.length; i++) {
      _insertPoint(session.id, session.points[i], i);
    }

    return session;
  }

  void updateSession(String id, Map<String, dynamic> updates) {
    final sets = <String>[];
    final values = <Object?>[];

    if (updates.containsKey('name')) {
      sets.add('name = ?');
      values.add(updates['name']);
    }
    if (updates.containsKey('endTime')) {
      sets.add('end_time = ?');
      values.add(updates['endTime']);
    }
    if (updates.containsKey('totalDistanceMeters')) {
      sets.add('total_distance_meters = ?');
      values.add(updates['totalDistanceMeters']);
    }

    if (sets.isEmpty) return;
    values.add(id);
    _db.execute(
      'UPDATE sessions SET ${sets.join(', ')} WHERE id = ?',
      values,
    );
  }

  void deleteSession(String id) {
    _db.execute('DELETE FROM sessions WHERE id = ?', [id]);
  }

  int addPoint(String sessionId, LocationPoint point) {
    final countResult = _db.select(
      'SELECT COUNT(*) as cnt FROM location_points WHERE session_id = ?',
      [sessionId],
    );
    final sortOrder = countResult.first['cnt'] as int;
    _insertPoint(sessionId, point, sortOrder);
    return sortOrder;
  }

  void _insertPoint(String sessionId, LocationPoint point, int sortOrder) {
    _db.execute(
      '''INSERT INTO location_points
         (session_id, latitude, longitude, altitude, speed, accuracy, timestamp, sort_order)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        sessionId,
        point.latitude,
        point.longitude,
        point.altitude,
        point.speed,
        point.accuracy,
        point.timestamp.toIso8601String(),
        sortOrder,
      ],
    );
  }

  TrackingSession _rowToSession(sql.Row row) {
    return TrackingSession(
      id: row['id'] as String,
      name: row['name'] as String,
      startTime: DateTime.parse(row['start_time'] as String),
      endTime: row['end_time'] != null
          ? DateTime.parse(row['end_time'] as String)
          : null,
      tickRateMs: row['tick_rate_ms'] as int,
      totalDistanceMeters: (row['total_distance_meters'] as num).toDouble(),
    );
  }

  LocationPoint _rowToPoint(sql.Row row) {
    return LocationPoint(
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      altitude: (row['altitude'] as num).toDouble(),
      speed: (row['speed'] as num).toDouble(),
      accuracy: (row['accuracy'] as num).toDouble(),
      timestamp: DateTime.parse(row['timestamp'] as String),
    );
  }

  void close() => _db.dispose();
}
