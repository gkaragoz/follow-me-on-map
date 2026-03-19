import 'package:flutter/material.dart';
import '../utils/map_tile_providers.dart';

class MapLayerSwitcher extends StatelessWidget {
  final MapLayerType currentLayer;
  final ValueChanged<MapLayerType> onLayerChanged;

  const MapLayerSwitcher({
    super.key,
    required this.currentLayer,
    required this.onLayerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: SegmentedButton<MapLayerType>(
          segments: const [
            ButtonSegment(
              value: MapLayerType.normal,
              label: Text('Map'),
              icon: Icon(Icons.map),
            ),
            ButtonSegment(
              value: MapLayerType.satellite,
              label: Text('Sat'),
              icon: Icon(Icons.satellite_alt),
            ),
            ButtonSegment(
              value: MapLayerType.hybrid,
              label: Text('Mix'),
              icon: Icon(Icons.layers),
            ),
          ],
          selected: {currentLayer},
          onSelectionChanged: (selection) {
            onLayerChanged(selection.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
