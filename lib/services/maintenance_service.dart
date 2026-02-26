import 'package:http/http.dart' as http;
import 'package:mtg_stats/services/api_config.dart';

/// Сервис обслуживания данных: экспорт, импорт, очистка таблиц.
class MaintenanceService {
  MaintenanceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Скачивает архив с бэкапом всех данных (пользователи, колоды, игры, изображения).
  ///
  /// [includePasswords] — при true в архив включаются хеши паролей (полное восстановление).
  /// По умолчанию — без паролей (безопасный экспорт).
  Future<List<int>> downloadBackup({bool includePasswords = false}) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}/api/export/all');
    if (includePasswords) {
      uri = uri.replace(queryParameters: {'include_passwords': 'true'});
    }
    final response = await _client.get(
      uri,
      headers: {...ApiConfig.authHeaders, 'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Не удалось экспортировать данные: ${response.statusCode} $uri',
      );
    }
    return response.bodyBytes;
  }

  /// Отправляет gzip-архив на сервер для полной замены данных.
  ///
  /// [bytes] — содержимое файла mtg_stats_export.json.gz, отправляется как тело запроса.
  Future<void> importBackupArchive(List<int> bytes) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/import/all');
    final response = await _client.post(
      uri,
      headers: {
        ...ApiConfig.authHeaders,
        'Content-Type': 'application/gzip',
        'Accept': 'application/json',
      },
      body: bytes,
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Не удалось импортировать данные: ${response.statusCode} $uri body: ${response.body}',
      );
    }
  }

  /// Полная очистка игр и ходов.
  Future<void> clearGames() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/games');
    final response = await _client.delete(uri, headers: ApiConfig.authHeaders);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Не удалось очистить игры: ${response.statusCode} $uri',
      );
    }
  }
}
