import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/models/user.dart';
import 'package:mtg_stats/services/api_config.dart';

/// API пользователей: список, CRUD.
class UserService {
  UserService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<User>> getUsers() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Не удалось загрузить пользователей: ${response.statusCode}');
    }
    final list = json.decode(response.body) as List<dynamic>;
    return list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<User> getUser(String id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$id'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode == 404) {
      throw Exception('Пользователь не найден');
    }
    if (response.statusCode != 200) {
      throw Exception(
          'Не удалось загрузить пользователя: ${response.statusCode}');
    }
    return User.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<User> createUser(String name,
      {String? password, bool? isAdmin}) async {
    final body = <String, dynamic>{'name': name.trim()};
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (isAdmin != null) body['is_admin'] = isAdmin;
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/users'),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 409) {
      throw Exception('Пользователь с таким именем уже существует');
    }
    if (response.statusCode != 201) {
      final data = json.decode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['error'] as String? ??
          'Ошибка создания: ${response.statusCode}');
    }
    return User.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<User> updateUser(String id, String name,
      {String? password, bool? isAdmin}) async {
    final body = <String, dynamic>{'name': name.trim()};
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (isAdmin != null) body['is_admin'] = isAdmin;
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$id'),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 409) {
      throw Exception('Пользователь с таким именем уже существует');
    }
    if (response.statusCode != 200) {
      final data = json.decode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['error'] as String? ??
          'Ошибка обновления: ${response.statusCode}');
    }
    return User.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteUser(String id) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$id'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode == 404) {
      throw Exception('Пользователь не найден');
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      final data = json.decode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['error'] as String? ??
          'Ошибка удаления: ${response.statusCode}');
    }
  }
}
