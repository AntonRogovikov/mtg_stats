import 'dart:convert';

/// Парсинг сообщений об ошибках из ответов API.
class ApiError {
  /// Извлекает сообщение об ошибке из JSON-тела ответа.
  /// Поддерживает поля: error, detail, details.
  static String parse(String body, String fallback) {
    if (body.isEmpty) return fallback;
    try {
      final decoded = json.decode(body) as Map<String, dynamic>;
      return (decoded['error'] ?? decoded['detail'] ?? decoded['details']) as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
