import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/mock_data_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  // Seed mock sessions so the app has data to inspect on first launch
  await MockDataService(storageService).seedIfEmpty();

  runApp(App(storageService: storageService));
}
