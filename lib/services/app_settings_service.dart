import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/services/api_config.dart';

class AppSettings {
  final String timezone;
  final int timezoneOffsetMinutes;

  const AppSettings({
    required this.timezone,
    required this.timezoneOffsetMinutes,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      timezone: (json['timezone'] as String?)?.trim().isNotEmpty == true
          ? (json['timezone'] as String).trim()
          : 'UTC',
      timezoneOffsetMinutes: json['timezone_offset_minutes'] as int? ?? 0,
    );
  }
}

class AppSettingsService {
  AppSettingsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AppSettings> getSettings() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/settings');
    final response = await _client.get(uri, headers: ApiConfig.authHeaders);
    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить настройки: ${response.statusCode}');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    return AppSettings.fromJson(data);
  }

  Future<AppSettings> updateTimezone(String timezone) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/settings');
    final response = await _client.put(
      uri,
      headers: {
        ...ApiConfig.authHeaders,
        'Content-Type': 'application/json',
      },
      body: json.encode({'timezone': timezone}),
    );
    if (response.statusCode != 200) {
      throw Exception('Не удалось сохранить timezone: ${response.statusCode}');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    return AppSettings.fromJson(data);
  }
}
