import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/services/api_config.dart';

/// Результат входа: токен и данные пользователя.
class LoginResult {
  final String token;
  final String userId;
  final String userName;
  final bool isAdmin;

  LoginResult({
    required this.token,
    required this.userId,
    required this.userName,
    required this.isAdmin,
  });
}

/// API входа: POST /api/auth/login.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LoginResult> login(String name, String password) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name.trim(), 'password': password}),
    );
    if (response.statusCode != 200) {
      final body = json.decode(response.body) as Map<String, dynamic>?;
      final msg =
          body?['error'] as String? ?? 'Ошибка входа: ${response.statusCode}';
      throw Exception(msg);
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String? ?? '';
    final user = data['user'] as Map<String, dynamic>?;
    final userId = user?['id']?.toString() ?? '';
    final userName = user?['name'] as String? ?? name;
    final isAdmin = user?['is_admin'] as bool? ?? false;
    if (token.isEmpty) throw Exception('Сервер не вернул токен');
    return LoginResult(
      token: token,
      userId: userId,
      userName: userName,
      isAdmin: isAdmin,
    );
  }
}
