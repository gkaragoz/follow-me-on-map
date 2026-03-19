import 'package:flutter/material.dart';
import 'config.dart';
import 'services/api_client.dart';
import 'services/storage_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient(baseUrl: AppConfig.baseUrl);
  final storageService = StorageService(apiClient: apiClient);

  runApp(App(
    apiClient: apiClient,
    storageService: storageService,
  ));
}
