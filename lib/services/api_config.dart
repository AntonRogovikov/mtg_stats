import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrlFromEnvironment =
    String.fromEnvironment('BASE_URL', defaultValue: '');

/// Конфигурация URL бэкенда (dart-define, SharedPreferences или значение по умолчанию).
class ApiConfig {
  static const String _keyBaseUrl = 'backend_base_url';
  //static const String defaultBaseUrl =  'http://localhost:8080'; // для локальной разработки
  static const String defaultBaseUrl = 'https://mtg-stats-backend-production-1a71.up.railway.app';
  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl {
    if (_baseUrlFromEnvironment.isNotEmpty) {
      return _normalize(_baseUrlFromEnvironment);
    }
    return _baseUrl;
  }

  static String _normalize(String url) {
    final s = url.trim();
    if (s.isEmpty) return defaultBaseUrl;
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyBaseUrl);
      if (saved != null && saved.isNotEmpty) {
        _baseUrl = _normalize(saved);
      }
    } catch (_) {}
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().isEmpty ? defaultBaseUrl : _normalize(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_baseUrl == defaultBaseUrl) {
        await prefs.remove(_keyBaseUrl);
      } else {
        await prefs.setString(_keyBaseUrl, _baseUrl);
      }
    } catch (_) {}
  }
}
