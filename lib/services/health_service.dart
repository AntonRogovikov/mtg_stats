import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/services/api_config.dart';

/// Результат проверки состояния сервера.
class HealthResult {
  final bool ok;
  final String status;
  final String? database;
  final String? mode;
  final String? error;

  HealthResult({
    required this.ok,
    required this.status,
    this.database,
    this.mode,
    this.error,
  });
}

/// Проверка доступности бэкенда: GET /health.
class HealthService {
  Future<HealthResult> check() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return HealthResult(
          ok: false,
          status: 'unhealthy',
          error: 'Сервер вернул ${response.statusCode}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>?;
      final status = data?['status'] as String? ?? 'unknown';
      final db = data?['database'] as String?;
      final mode = data?['mode'] as String?;

      return HealthResult(
        ok: status == 'healthy',
        status: status,
        database: db,
        mode: mode,
      );
    } catch (e) {
      return HealthResult(
        ok: false,
        status: 'error',
        error: e.toString(),
      );
    }
  }
}
