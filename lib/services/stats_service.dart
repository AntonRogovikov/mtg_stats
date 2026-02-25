import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/services/api_config.dart';

/// API статистики: загрузка статистики игроков и колод.
class StatsService {
  Future<List<PlayerStats>> getPlayerStats() async {
    final response = await http.get(
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
    final response = await http.get(
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

  Future<List<DeckMatchupStats>> getDeckMatchups() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/stats/deck-matchups'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load deck matchups: ${response.statusCode}');
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    final list = body['matchups'] as List<dynamic>? ?? const [];
    return list
        .map((e) => DeckMatchupStats.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MetaDashboardData> getMetaDashboard({
    String groupBy = 'week',
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{'group_by': groupBy};
    if (from != null) {
      query['from'] = from.toIso8601String().split('T').first;
    }
    if (to != null) {
      query['to'] = to.toIso8601String().split('T').first;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/stats/meta-dashboard')
        .replace(queryParameters: query);
    final response = await http.get(
      uri,
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load meta dashboard: ${response.statusCode}');
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    return MetaDashboardData.fromJson(body);
  }
}
