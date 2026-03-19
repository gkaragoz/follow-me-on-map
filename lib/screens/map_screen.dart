import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracking_provider.dart';
import '../providers/sessions_provider.dart';
import '../utils/map_tile_providers.dart';
import '../widgets/map_view.dart';
import '../widgets/map_layer_switcher.dart';
import '../widgets/tracking_controls.dart';
import '../widgets/playback_controls.dart';
import 'sessions_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLayerType _currentLayer = MapLayerType.normal;

  @override
  void initState() {
    super.initState();
    // Initialize location on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackingProvider>().initLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsProvider = context.watch<SessionsProvider>();
    final viewingSession = sessionsProvider.viewingSession;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          MapView(layerType: _currentLayer),

          // Viewing session banner
          if (viewingSession != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    top: 4,
                    bottom: 4,
                    right: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility, size: 20,
                          color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Viewing: ${viewingSession.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          sessionsProvider.viewSession(null);
                        },
                        icon: const Icon(Icons.close),
                        tooltip: 'Close session preview',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Layer switcher (bottom-right)
          Positioned(
            right: 12,
            bottom: 220,
            child: MapLayerSwitcher(
              currentLayer: _currentLayer,
              onLayerChanged: (layer) {
                setState(() => _currentLayer = layer);
              },
            ),
          ),

          // Center on location button
          Positioned(
            right: 12,
            bottom: 280,
            child: FloatingActionButton.small(
              heroTag: 'center',
              onPressed: () {
                final tracking = context.read<TrackingProvider>();
                tracking.isFollowing = true;
              },
              child: Consumer<TrackingProvider>(
                builder: (context, tracking, _) {
                  return Icon(
                    tracking.isFollowing
                        ? Icons.my_location
                        : Icons.location_searching,
                  );
                },
              ),
            ),
          ),

          // Sessions button
          Positioned(
            left: 12,
            bottom: 220,
            child: FloatingActionButton.small(
              heroTag: 'sessions',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SessionsScreen(),
                  ),
                );
              },
              child: const Icon(Icons.list),
            ),
          ),

          // Tracking controls or playback controls (bottom)
          if (viewingSession == null)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TrackingControls(),
            )
          else
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PlaybackControls(),
            ),
        ],
      ),
    );
  }
}
