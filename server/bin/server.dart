import 'dart:io';
import 'package:args/args.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:server/server_app.dart';
import 'package:server/db/database.dart';
import 'package:server/mock_data_service.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p',
        defaultsTo: Platform.environment['PORT'] ?? '8080')
    ..addOption('db', defaultsTo: 'data/tracking.db')
    ..addOption('static', defaultsTo: 'public');

  final results = parser.parse(args);
  final port = int.parse(results['port'] as String);
  final dbPath = results['db'] as String;
  final staticPath = results['static'] as String;

  // Ensure data directory exists
  final dbDir = Directory(dbPath).parent;
  if (!dbDir.existsSync()) {
    dbDir.createSync(recursive: true);
  }

  final db = Database(dbPath);
  db.init();
  print('Database initialized at $dbPath');

  // Seed mock data on first run
  MockDataService(db).seedIfEmpty();

  final handler = buildHandler(
    db: db,
    staticFilesPath: staticPath,
  );

  final server = await shelf_io.serve(handler, '0.0.0.0', port);
  print('Server running on http://${server.address.host}:${server.port}');
  print('API: http://localhost:$port/api/sessions');
  print('WebSocket: ws://localhost:$port/ws/tracking');

  // Handle shutdown
  ProcessSignal.sigint.watch().listen((_) {
    print('\nShutting down...');
    db.close();
    server.close();
    exit(0);
  });
}
