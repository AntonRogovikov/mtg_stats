import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrlFromEnvironment =
    String.fromEnvironment('BASE_URL', defaultValue: '');
const String _apiTokenFromEnvironment =
    String.fromEnvironment('API_TOKEN', defaultValue: '');

/// Конфигурация URL бэкенда и API-токена (dart-define, SharedPreferences или значения по умолчанию).
class ApiConfig {
  static const String _keyBaseUrl = 'backend_base_url';
  static const String _keyApiToken = 'api_token';
  //static const String defaultBaseUrl =  'http://localhost:8080'; // для локальной разработки
  //static const String defaultBaseUrl = 'https://mtg-stats-backend-production-1a71.up.railway.app';
  static const String defaultBaseUrl = 'https://antonrogovikov.duckdns.org';
  static String _baseUrl = defaultBaseUrl;
  static String _apiToken = 'a376721b-0174-4189-b3b3-0bc85efa880d';

  static String get baseUrl {
    if (_baseUrlFromEnvironment.isNotEmpty) {
      return _normalize(_baseUrlFromEnvironment);
    }
    return _baseUrl;
  }

  static String get apiToken {
    if (_apiTokenFromEnvironment.isNotEmpty) {
      return _apiTokenFromEnvironment.trim();
    }
    return _apiToken;
  }

  /// Заголовки для запросов к /api/* — добавляет Authorization: Bearer если токен задан.
  static Map<String, String> get authHeaders {
    final token = apiToken;
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  static String _normalize(String url) {
    final s = url.trim();
    if (s.isEmpty) return defaultBaseUrl;
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_keyBaseUrl);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _baseUrl = _normalize(savedUrl);
      }
      final savedToken = prefs.getString(_keyApiToken);
      if (savedToken != null) {
        _apiToken = savedToken.trim();
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

  static Future<void> setApiToken(String token) async {
    _apiToken = token.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_apiToken.isEmpty) {
        await prefs.remove(_keyApiToken);
      } else {
        await prefs.setString(_keyApiToken, _apiToken);
      }
    } catch (_) {}
  }
}
