import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shared/shared.dart';
import '../db/database.dart';

class SessionsApi {
  final Database db;

  SessionsApi(this.db);

  Router get router {
    final router = Router();

    router.get('/sessions', _listSessions);
    router.get('/sessions/<id>', _getSession);
    router.post('/sessions', _createSession);
    router.put('/sessions/<id>', _updateSession);
    router.delete('/sessions/<id>', _deleteSession);
    router.post('/sessions/<id>/points', _addPoint);

    return router;
  }

  Response _listSessions(Request request) {
    final sessionsWithCounts = db.getAllSessions();
    final json = sessionsWithCounts.map((record) {
      final (session, pointCount) = record;
      final summary = session.toJsonSummary();
      summary['pointCount'] = pointCount;
      return summary;
    }).toList();
    return Response.ok(
      jsonEncode(json),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _getSession(Request request, String id) {
    final session = db.getSession(id);
    if (session == null) {
      return Response.notFound(jsonEncode({'error': 'Session not found'}));
    }
    return Response.ok(
      jsonEncode(session.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _createSession(Request request) async {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final session = TrackingSession.fromJson(json);
    db.createSession(session);
    return Response.ok(
      jsonEncode(session.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _updateSession(Request request, String id) async {
    final existing = db.getSession(id);
    if (existing == null) {
      return Response.notFound(jsonEncode({'error': 'Session not found'}));
    }
    final body = await request.readAsString();
    final updates = jsonDecode(body) as Map<String, dynamic>;
    db.updateSession(id, updates);
    final updated = db.getSession(id);
    return Response.ok(
      jsonEncode(updated!.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _deleteSession(Request request, String id) {
    db.deleteSession(id);
    return Response(204);
  }

  Future<Response> _addPoint(Request request, String id) async {
    final existing = db.getSession(id);
    if (existing == null) {
      return Response.notFound(jsonEncode({'error': 'Session not found'}));
    }
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final point = LocationPoint.fromJson(json);
    db.addPoint(id, point);
    return Response.ok(
      jsonEncode(point.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
