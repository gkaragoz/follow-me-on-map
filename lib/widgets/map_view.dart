import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/location_point.dart';
import '../providers/tracking_provider.dart';
import '../providers/sessions_provider.dart';
import '../utils/map_tile_providers.dart';

class MapView extends StatefulWidget {
  final MapLayerType layerType;

  const MapView({super.key, required this.layerType});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Force rebuild when layer type changes
    if (oldWidget.layerType != widget.layerType) {
      setState(() {});
    }
  }

  void _centerOnLocation(LocationPoint? location) {
    if (location != null) {
      _mapController.move(
        LatLng(location.latitude, location.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  List<TileLayer> _buildTileLayers() {
    switch (widget.layerType) {
      case MapLayerType.normal:
        return [MapTileProviders.normalLayer()];
      case MapLayerType.satellite:
        return [MapTileProviders.satelliteLayer()];
      case MapLayerType.hybrid:
        return MapTileProviders.hybridLayers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingProvider>();
    final sessionsProvider = context.watch<SessionsProvider>();
    final viewingSession = sessionsProvider.viewingSession;

    // Auto-center on current location when following
    if (tracking.isFollowing && tracking.currentLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnLocation(tracking.currentLocation);
      });
    }

    // Determine which points to show on the map
    final List<LatLng> polylinePoints;
    if (viewingSession != null) {
      polylinePoints = viewingSession.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    } else {
      polylinePoints = tracking.trackPoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    }

    // Default center (will be overridden when location is available)
    final center = tracking.currentLocation != null
        ? LatLng(
            tracking.currentLocation!.latitude,
            tracking.currentLocation!.longitude,
          )
        : viewingSession != null && viewingSession.points.isNotEmpty
            ? LatLng(
                viewingSession.points.first.latitude,
                viewingSession.points.first.longitude,
              )
            : const LatLng(41.0082, 28.9784); // Default: Istanbul

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && tracking.isFollowing) {
            tracking.isFollowing = false;
          }
        },
      ),
      children: [
        // Tile layers
        ..._buildTileLayers(),
        // Path polyline
        if (polylinePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                color: viewingSession != null ? Colors.blue : Colors.red,
                strokeWidth: 4,
              ),
            ],
          ),
        // Current location marker
        if (tracking.currentLocation != null && viewingSession == null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  tracking.currentLocation!.latitude,
                  tracking.currentLocation!.longitude,
                ),
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        // Start/end markers for viewed session
        if (viewingSession != null && viewingSession.points.isNotEmpty) ...[
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  viewingSession.points.first.latitude,
                  viewingSession.points.first.longitude,
                ),
                width: 30,
                height: 30,
                child: const Icon(Icons.flag, color: Colors.green, size: 30),
              ),
              if (viewingSession.points.length > 1)
                Marker(
                  point: LatLng(
                    viewingSession.points.last.latitude,
                    viewingSession.points.last.longitude,
                  ),
                  width: 30,
                  height: 30,
                  child: const Icon(Icons.flag, color: Colors.red, size: 30),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
