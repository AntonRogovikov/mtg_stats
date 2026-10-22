import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mtg_stats/core/api_error.dart';
import 'package:mtg_stats/services/api_config.dart';

/// Сервер отверг токен (401). Провайдеры такую ошибку не ретраят (см. main.dart).
class UnauthorizedException implements Exception {
  const UnauthorizedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Политика ретрая провайдеров (ProviderScope.retry): 401 не ретраим —
/// повтор с тем же токеном бессмыслен, а UI висел бы в "загрузке".
Duration? apiProviderRetry(int retryCount, Object error) {
  if (error is UnauthorizedException) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}

/// http.Client для всех сервисов: ловит 401 на запросах с Authorization.
/// Если был отправлен JWT — сессия сбрасывается (ApiConfig.expireSession),
/// UI показывает "Сессия истекла". Запросы без Authorization (логин) не трогает:
/// там 401 означает неверный пароль.
class AuthHttpClient extends http.BaseClient {
  AuthHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final auth = request.headers['Authorization'];
    if (response.statusCode != 401 || auth == null) return response;

    final body = await response.stream.bytesToString();
    final usedJwt = auth != 'Bearer ${ApiConfig.apiToken}';
    if (usedJwt) {
      // Параллельные запросы могут прийти сюда уже после сброса — уведомляем один раз.
      if (ApiConfig.isLoggedIn) await ApiConfig.expireSession();
      throw const UnauthorizedException('Сессия истекла. Войдите снова.');
    }
    throw UnauthorizedException(ApiError.parse(body, 'Нет доступа (401)'));
  }

  @override
  void close() => _inner.close();
}
