import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_static/shelf_static.dart';
import 'api/sessions_api.dart';
import 'api/tracking_ws.dart';
import 'db/database.dart';

Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Handler buildHandler({
  required Database db,
  String? staticFilesPath,
}) {
  final sessionsApi = SessionsApi(db);
  final trackingWs = TrackingWebSocket(db);

  final wsHandler = webSocketHandler(
    (channel) => trackingWs.handleConnection(channel),
  );

  final router = Router();

  // API routes
  router.mount('/api/', sessionsApi.router.call);

  // WebSocket route
  router.get('/ws/tracking', wsHandler);

  // Health check
  router.get('/health', (Request request) {
    return Response.ok('ok');
  });

  Handler handler = const Pipeline()
      .addMiddleware(corsMiddleware())
      .addMiddleware(logRequests())
      .addHandler(router.call);

  // Optionally serve static files (Flutter web build)
  if (staticFilesPath != null && Directory(staticFilesPath).existsSync()) {
    final staticHandler = createStaticHandler(
      staticFilesPath,
      defaultDocument: 'index.html',
    );

    // Cascade: try API/WS first, fall back to static files
    final originalHandler = handler;
    handler = (Request request) async {
      final response = await originalHandler(request);
      if (response.statusCode == 404) {
        return staticHandler(request);
      }
      return response;
    };
  }

  return handler;
}
