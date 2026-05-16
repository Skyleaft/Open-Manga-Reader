import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:5126',
  );

  static String _baseUrl = _defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static set baseUrl(String value) {
    String sanitized = value.trim();
    while (sanitized.endsWith('/') && sanitized.length > 8) { // Keep at least https://
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    _baseUrl = sanitized;
  }

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('api_base_url');
      if (savedUrl != null) {
        baseUrl = savedUrl;
      }
    } catch (e) {
      // Fallback
    }
  }

  static Future<void> updateBaseUrl(String newUrl) async {
    baseUrl = newUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', _baseUrl);
    } catch (e) {
      // Ignored
    }
  }
}
