import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/tracking_provider.dart';
import 'providers/sessions_provider.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'services/gpx_export_service.dart';
import 'screens/map_screen.dart';

class App extends StatelessWidget {
  final StorageService storageService;

  const App({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TrackingProvider(
            locationService: LocationService(),
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionsProvider(
            storageService: storageService,
            gpxExportService: GpxExportService(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Follow Me On Map',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
        ),
        home: const MapScreen(),
      ),
    );
  }
}
