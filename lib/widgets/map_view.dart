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
  String? _lastViewedSessionId;

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

  void _fitSessionBounds(List<LocationPoint> points) {
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(
      points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
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

    // Fit map to session bounds when a new session is selected
    if (viewingSession != null &&
        viewingSession.id != _lastViewedSessionId &&
        viewingSession.points.isNotEmpty) {
      _lastViewedSessionId = viewingSession.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitSessionBounds(viewingSession.points);
      });
    } else if (viewingSession == null) {
      _lastViewedSessionId = null;
    }

    // Auto-center on current playback point during playback
    if (viewingSession != null && sessionsProvider.isPlaying) {
      final playbackPoint = sessionsProvider.currentPlaybackPoint;
      if (playbackPoint != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _centerOnLocation(playbackPoint);
        });
      }
    }

    // Determine which points to show on the map
    final List<LatLng> polylinePoints;
    if (viewingSession != null) {
      final points = viewingSession.points;
      final end = (sessionsProvider.playbackIndex + 1).clamp(0, points.length);
      polylinePoints = List<LatLng>.generate(
        end,
        (i) => LatLng(points[i].latitude, points[i].longitude),
      );
    } else {
      final points = List.of(tracking.trackPoints);
      polylinePoints = List<LatLng>.generate(
        points.length,
        (i) => LatLng(points[i].latitude, points[i].longitude),
      );
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
        // Current location marker + peer markers
        if (viewingSession == null)
          MarkerLayer(
            markers: [
              // Own location
              if (tracking.currentLocation != null)
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
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              // Peer locations
              ...tracking.peers.values.map((peer) => Marker(
                    point: LatLng(
                      peer.point.latitude,
                      peer.point.longitude,
                    ),
                    width: 32,
                    height: 40,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            peer.clientId.substring(0, 4),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        // Markers for viewed session (start flag, end flag, playback position)
        if (viewingSession != null && viewingSession.points.isNotEmpty) ...[
          MarkerLayer(
            markers: [
              // Start flag
              Marker(
                point: LatLng(
                  viewingSession.points.first.latitude,
                  viewingSession.points.first.longitude,
                ),
                width: 30,
                height: 30,
                child: const Icon(Icons.flag, color: Colors.green, size: 30),
              ),
              // End flag (dimmed)
              if (viewingSession.points.length > 1)
                Marker(
                  point: LatLng(
                    viewingSession.points.last.latitude,
                    viewingSession.points.last.longitude,
                  ),
                  width: 30,
                  height: 30,
                  child: Icon(Icons.flag,
                      color: Colors.red.withValues(alpha: 0.4), size: 30),
                ),
              // Current playback position
              if (sessionsProvider.currentPlaybackPoint != null)
                Marker(
                  point: LatLng(
                    sessionsProvider.currentPlaybackPoint!.latitude,
                    sessionsProvider.currentPlaybackPoint!.longitude,
                  ),
                  width: 24,
                  height: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
