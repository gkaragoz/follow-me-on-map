import 'dart:ui' show Color;
import 'package:flutter_map/flutter_map.dart';

enum MapLayerType { normal, satellite, hybrid }

class MapTileProviders {
  static TileLayer normalLayer() {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.followme.follow_me_on_map',
      maxZoom: 19,
    );
  }

  static TileLayer satelliteLayer() {
    return TileLayer(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.followme.follow_me_on_map',
      maxZoom: 18,
    );
  }

  static List<TileLayer> hybridLayers() {
    return [
      satelliteLayer(),
      TileLayer(
        urlTemplate:
            'https://stamen-tiles.a.ssl.fastly.net/toner-labels/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.followme.follow_me_on_map',
        maxZoom: 18,
        backgroundColor: const Color(0x00000000),
      ),
    ];
  }
}
