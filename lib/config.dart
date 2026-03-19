import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _envUrl = String.fromEnvironment('API_URL');

  /// Base URL for API calls. Empty string means same origin (relative URLs).
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    // On web with no explicit URL, use same origin (relative paths)
    if (kIsWeb) return '';
    // On native, default to localhost
    return 'http://localhost:8080';
  }

  /// WebSocket URL derived from baseUrl.
  static String get wsUrl {
    if (baseUrl.isEmpty) {
      // Same origin — browser will resolve relative to current page
      // Use protocol-relative WebSocket URL
      return '';
    }
    return baseUrl.replaceFirst('http', 'ws');
  }
}
