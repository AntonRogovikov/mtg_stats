import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrlFromEnvironment =
    String.fromEnvironment('BASE_URL', defaultValue: '');
const String _apiTokenFromEnvironment =
    String.fromEnvironment('API_TOKEN', defaultValue: '');

/// Конфигурация URL бэкенда и API-токена (dart-define, SharedPreferences или значения по умолчанию).
class ApiConfig {
  static const String _keyBaseUrl = 'backend_base_url';
  static const String _keyApiToken = 'api_token';
  static const String _keyJwt = 'jwt_token';
  static const String _keyUserId = 'current_user_id';
  static const String _keyUserName = 'current_user_name';
  static const String _keyUserAdmin = 'current_user_is_admin';
  static const String defaultBaseUrl =  'http://localhost:8080'; // для локальной разработки
  //static const String defaultBaseUrl = 'https://mtg-stats-backend-production-1a71.up.railway.app';
  //static const String defaultBaseUrl = 'https://antonrogovikov.duckdns.org';
  static String _baseUrl = defaultBaseUrl;
  static String _apiToken = 'a376721b-0174-4189-b3b3-0bc85efa880d';
  static String _jwtToken = '';
  static String _currentUserId = '';
  static String _currentUserName = '';
  static bool _currentUserIsAdmin = false;

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

  /// Заголовки для запросов к /api/* — JWT приоритетнее API_TOKEN.
  static Map<String, String> get authHeaders {
    final token = _jwtToken.isNotEmpty ? _jwtToken : apiToken;
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  static bool get isLoggedIn => _jwtToken.isNotEmpty;
  static String get currentUserId => _currentUserId;
  static String get currentUserName => _currentUserName;
  static bool get isAdmin => _currentUserIsAdmin;

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
      final savedJwt = prefs.getString(_keyJwt);
      if (savedJwt != null && savedJwt.isNotEmpty) {
        _jwtToken = savedJwt;
      }
      _currentUserId = prefs.getString(_keyUserId) ?? '';
      _currentUserName = prefs.getString(_keyUserName) ?? '';
      _currentUserIsAdmin = prefs.getBool(_keyUserAdmin) ?? false;
    } catch (_) {}
  }

  static Future<void> setJwt(String token, {String? userId, String? userName, bool? isAdmin}) async {
    _jwtToken = token.trim();
    if (userId != null) _currentUserId = userId;
    if (userName != null) _currentUserName = userName;
    if (isAdmin != null) _currentUserIsAdmin = isAdmin;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_jwtToken.isEmpty) {
        await prefs.remove(_keyJwt);
        await prefs.remove(_keyUserId);
        await prefs.remove(_keyUserName);
        await prefs.remove(_keyUserAdmin);
      } else {
        await prefs.setString(_keyJwt, _jwtToken);
        await prefs.setString(_keyUserId, _currentUserId);
        await prefs.setString(_keyUserName, _currentUserName);
        await prefs.setBool(_keyUserAdmin, _currentUserIsAdmin);
      }
    } catch (_) {}
  }

  static Future<void> clearJwt() async {
    _jwtToken = '';
    _currentUserId = '';
    _currentUserName = '';
    _currentUserIsAdmin = false;
    try {
      final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyJwt);
        await prefs.remove(_keyUserId);
        await prefs.remove(_keyUserName);
        await prefs.remove(_keyUserAdmin);
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
