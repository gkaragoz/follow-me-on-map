import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sessions_provider.dart';
import '../widgets/session_list_tile.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionsProvider>().loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Sessions'),
      ),
      body: Consumer<SessionsProvider>(
        builder: (context, sessionsProvider, _) {
          final sessions = sessionsProvider.sessions;

          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No sessions yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start tracking to create your first session',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return SessionListTile(
                session: session,
                onTap: () {
                  sessionsProvider.viewSession(session);
                  Navigator.pop(context);
                },
                onDelete: () {
                  sessionsProvider.deleteSession(session.id);
                },
                onShare: () {
                  sessionsProvider.shareSession(session);
                },
              );
            },
          );
        },
      ),
    );
  }
}
