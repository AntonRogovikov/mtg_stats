import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/services/auth_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthHttpClient _client401(String error) => AuthHttpClient(
      MockClient((_) async => http.Response('{"error":"$error"}', 401,
          headers: {'content-type': 'application/json; charset=utf-8'})),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.clearJwt();
  });

  test('401 на запросе с JWT: сессия сброшена, UI уведомлен', () async {
    await ApiConfig.setJwt('expired.jwt', userId: '1', userName: 'A', isAdmin: true);
    final before = ApiConfig.sessionExpired.value;

    await expectLater(
      _client401('Токен истёк. Войдите снова.')
          .get(Uri.parse('http://x/api/users'), headers: ApiConfig.authHeaders),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(ApiConfig.isLoggedIn, isFalse);
    expect(ApiConfig.isAdmin, isFalse);
    expect(ApiConfig.sessionExpired.value, before + 1);
  });

  test('повторный 401 после сброса не дублирует уведомление', () async {
    await ApiConfig.setJwt('expired.jwt');
    final client = _client401('Неверный токен');
    final headers = ApiConfig.authHeaders;
    final before = ApiConfig.sessionExpired.value;

    for (var i = 0; i < 3; i++) {
      await expectLater(client.get(Uri.parse('http://x/api/games'), headers: headers),
          throwsA(isA<UnauthorizedException>()));
    }
    expect(ApiConfig.sessionExpired.value, before + 1);
  });

  test('401 на логине (без Authorization) отдается как есть', () async {
    final before = ApiConfig.sessionExpired.value;
    final response = await _client401('Неверное имя или пароль')
        .post(Uri.parse('http://x/api/auth/login'), body: '{}');
    expect(response.statusCode, 401);
    expect(response.body, contains('Неверное имя или пароль'));
    expect(ApiConfig.sessionExpired.value, before);
  });

  test('провайдер с UnauthorizedException не уходит в бесконечную загрузку', () async {
    var calls = 0;
    final provider = FutureProvider<int>((ref) async {
      calls++;
      throw const UnauthorizedException('Сессия истекла. Войдите снова.');
    });
    final container = ProviderContainer(retry: apiProviderRetry);
    addTearDown(container.dispose);
    container.listen(provider, (_, __) {}, fireImmediately: true);

    await Future<void>.delayed(const Duration(seconds: 2));
    final state = container.read(provider);
    expect(state.hasError, isTrue);
    expect(state.isLoading, isFalse);
    expect(calls, 1);
  });
}
