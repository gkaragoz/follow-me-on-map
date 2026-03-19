import 'package:flutter/foundation.dart';
import '../models/tracking_session.dart';
import '../services/storage_service.dart';
import '../services/gpx_export_service.dart';

class SessionsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final GpxExportService _gpxExportService;

  List<TrackingSession> _sessions = [];
  TrackingSession? _viewingSession;

  SessionsProvider({
    required StorageService storageService,
    required GpxExportService gpxExportService,
  })  : _storageService = storageService,
        _gpxExportService = gpxExportService;

  List<TrackingSession> get sessions => _sessions;
  TrackingSession? get viewingSession => _viewingSession;

  void loadSessions() {
    _sessions = _storageService.getAllSessions();
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await _storageService.deleteSession(id);
    if (_viewingSession?.id == id) {
      _viewingSession = null;
    }
    loadSessions();
  }

  void viewSession(TrackingSession? session) {
    _viewingSession = session;
    notifyListeners();
  }

  Future<void> shareSession(TrackingSession session) async {
    await _gpxExportService.shareSession(session);
  }

  Future<String> exportSession(TrackingSession session) async {
    return await _gpxExportService.exportSession(session);
  }
}
