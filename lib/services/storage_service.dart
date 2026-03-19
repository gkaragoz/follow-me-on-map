import '../models/tracking_session.dart';
import 'api_client.dart';

class StorageService {
  final ApiClient _apiClient;

  StorageService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<TrackingSession>> getAllSessions() async {
    return await _apiClient.getSessions();
  }

  Future<void> saveSession(TrackingSession session) async {
    try {
      await _apiClient.getSession(session.id);
      // Session exists, update it
      await _apiClient.updateSession(session.id, {
        'name': session.name,
        'endTime': session.endTime?.toIso8601String(),
        'totalDistanceMeters': session.totalDistanceMeters,
      });
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // Session doesn't exist, create it
        await _apiClient.createSession(session);
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteSession(String id) async {
    await _apiClient.deleteSession(id);
  }

  Future<TrackingSession?> getSession(String id) async {
    try {
      return await _apiClient.getSession(id);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
