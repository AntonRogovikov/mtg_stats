import 'package:http/http.dart' as http;
import 'package:mtg_stats/services/api_config.dart';

/// Сервис обслуживания данных: экспорт, импорт, очистка таблиц.
class MaintenanceService {
  /// Скачивает архив с бэкапом всех данных (пользователи, колоды, игры, изображения).
  ///
  /// Возвращает сырые байты ответа.
  Future<List<int>> downloadBackup() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/export/all');
    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
      },
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
    final response = await http.post(
      uri,
      headers: const {
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
    final response = await http.delete(uri);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Не удалось очистить игры: ${response.statusCode} $uri',
      );
    }
  }
}


