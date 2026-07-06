import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/services/api_config.dart';

/// API статистики: загрузка статистики игроков и колод.
class StatsService {
  StatsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PlayerStats>> getPlayerStats() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/stats/players'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load player stats: ${response.statusCode}');
    }
    final list = json.decode(response.body) as List<dynamic>;
    return list
        .map((e) => PlayerStats.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DeckStats>> getDeckStats() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/stats/decks'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load deck stats: ${response.statusCode}');
    }
    final list = json.decode(response.body) as List<dynamic>;
    return list
        .map((e) => DeckStats.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
