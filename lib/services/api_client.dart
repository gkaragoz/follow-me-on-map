import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared/shared.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({required this.baseUrl}) : _http = http.Client();

  /// Resolves a path like '/api/sessions' to a full URI.
  /// On web with empty baseUrl, resolves relative to the page origin.
  Uri _uri(String path) {
    if (baseUrl.isNotEmpty) {
      return Uri.parse('$baseUrl$path');
    }
    // On web, resolve relative to current page origin
    if (kIsWeb) {
      return Uri.base.resolve(path);
    }
    return Uri.parse('http://localhost:8080$path');
  }

  /// WebSocket URI for the tracking endpoint.
  Uri _wsUri() {
    if (baseUrl.isNotEmpty) {
      final wsUrl = baseUrl.replaceFirst('http', 'ws');
      return Uri.parse('$wsUrl/ws/tracking');
    }
    if (kIsWeb) {
      final origin = Uri.base;
      final scheme = origin.scheme == 'https' ? 'wss' : 'ws';
      return Uri.parse('$scheme://${origin.host}:${origin.port}/ws/tracking');
    }
    return Uri.parse('ws://localhost:8080/ws/tracking');
  }

  // ── REST API ─────────────────────────────────────────────────────────

  Future<List<TrackingSession>> getSessions() async {
    final response = await _http.get(_uri('/api/sessions'));
    _checkResponse(response);
    final list = jsonDecode(response.body) as List;
    return list
        .map((json) => TrackingSession.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<TrackingSession> getSession(String id) async {
    final response = await _http.get(_uri('/api/sessions/$id'));
    _checkResponse(response);
    return TrackingSession.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<TrackingSession> createSession(TrackingSession session) async {
    final response = await _http.post(
      _uri('/api/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(session.toJson()),
    );
    _checkResponse(response);
    return TrackingSession.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> updateSession(
      String id, Map<String, dynamic> updates) async {
    final response = await _http.put(
      _uri('/api/sessions/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );
    _checkResponse(response);
  }

  Future<void> deleteSession(String id) async {
    final response = await _http.delete(_uri('/api/sessions/$id'));
    if (response.statusCode != 204) {
      _checkResponse(response);
    }
  }

  Future<void> addPoint(String sessionId, LocationPoint point) async {
    final response = await _http.post(
      _uri('/api/sessions/$sessionId/points'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(point.toJson()),
    );
    _checkResponse(response);
  }

  // ── WebSocket ────────────────────────────────────────────────────────

  WebSocketChannel connectTracking() {
    return WebSocketChannel.connect(_wsUri());
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  void dispose() => _http.close();
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
