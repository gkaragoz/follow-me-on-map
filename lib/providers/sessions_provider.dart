import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/tracking_session.dart';
import '../models/location_point.dart';
import '../services/storage_service.dart';
import '../services/api_client.dart';
import '../services/gpx_export_service.dart';

class SessionsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final ApiClient _apiClient;
  final GpxExportService _gpxExportService;

  List<TrackingSession> _sessions = [];
  bool _isLoading = false;
  TrackingSession? _viewingSession;

  // Playback state
  int _playbackIndex = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;

  SessionsProvider({
    required StorageService storageService,
    required ApiClient apiClient,
    required GpxExportService gpxExportService,
  })  : _storageService = storageService,
        _apiClient = apiClient,
        _gpxExportService = gpxExportService;

  List<TrackingSession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  TrackingSession? get viewingSession => _viewingSession;

  // Playback getters
  int get playbackIndex => _playbackIndex;
  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _playbackSpeed;
  int get totalPoints => _viewingSession?.points.length ?? 0;

  LocationPoint? get currentPlaybackPoint {
    if (_viewingSession == null || _viewingSession!.points.isEmpty) return null;
    if (_playbackIndex >= _viewingSession!.points.length) return null;
    return _viewingSession!.points[_playbackIndex];
  }

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _sessions = await _storageService.getAllSessions();
    } catch (e) {
      debugPrint('Failed to load sessions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSession(String id) async {
    await _storageService.deleteSession(id);
    if (_viewingSession?.id == id) {
      _viewingSession = null;
      _resetPlayback();
    }
    await loadSessions();
  }

  Future<void> viewSession(TrackingSession? session) async {
    if (session != null) {
      // Fetch full session with points from API
      try {
        _viewingSession = await _apiClient.getSession(session.id);
      } catch (e) {
        debugPrint('Failed to fetch session details: $e');
        _viewingSession = session;
      }
    } else {
      _viewingSession = null;
    }
    _resetPlayback();
    notifyListeners();
  }

  // Playback controls
  void togglePlayback() {
    if (_isPlaying) {
      pausePlayback();
    } else {
      startPlayback();
    }
  }

  void startPlayback() {
    if (totalPoints == 0) return;
    // If at the end, restart from beginning
    if (_playbackIndex >= totalPoints - 1) {
      _playbackIndex = 0;
    }
    _isPlaying = true;
    _startTimer();
    notifyListeners();
  }

  void pausePlayback() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    notifyListeners();
  }

  void stepForward() {
    if (_playbackIndex < totalPoints - 1) {
      _playbackIndex++;
      notifyListeners();
    }
  }

  void stepBackward() {
    if (_playbackIndex > 0) {
      _playbackIndex--;
      notifyListeners();
    }
  }

  void seekTo(int index) {
    if (totalPoints == 0) return;
    _playbackIndex = index.clamp(0, totalPoints - 1);
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    if (_isPlaying) {
      _playbackTimer?.cancel();
      _startTimer();
    }
    notifyListeners();
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    final intervalMs = (500 / _playbackSpeed).round();
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _onPlaybackTick(),
    );
  }

  void _onPlaybackTick() {
    if (_playbackIndex < totalPoints - 1) {
      _playbackIndex++;
      notifyListeners();
    } else {
      pausePlayback();
    }
  }

  void _resetPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isPlaying = false;
    _playbackIndex = 0;
    _playbackSpeed = 1.0;
  }

  Future<void> shareSession(TrackingSession session) async {
    await _gpxExportService.shareSession(session);
  }

  Future<String> exportSession(TrackingSession session) async {
    return await _gpxExportService.exportSession(session);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
