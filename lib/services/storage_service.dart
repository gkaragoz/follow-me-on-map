import 'package:hive_flutter/hive_flutter.dart';
import '../models/location_point.dart';
import '../models/tracking_session.dart';

class StorageService {
  static const String _sessionsBoxName = 'tracking_sessions';
  late Box<TrackingSession> _sessionsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(LocationPointAdapter());
    Hive.registerAdapter(TrackingSessionAdapter());
    _sessionsBox = await Hive.openBox<TrackingSession>(_sessionsBoxName);
  }

  List<TrackingSession> getAllSessions() {
    final sessions = _sessionsBox.values.toList();
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  Future<void> saveSession(TrackingSession session) async {
    await _sessionsBox.put(session.id, session);
  }

  Future<void> deleteSession(String id) async {
    await _sessionsBox.delete(id);
  }

  TrackingSession? getSession(String id) {
    return _sessionsBox.get(id);
  }
}
