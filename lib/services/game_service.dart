import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/services/api_config.dart';

/// API партий: создание, активная игра, обновление ходов, завершение.
class GameService {
  Future<Game> createGame(Game game) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/games');
    final response = await http.post(
      uri,
      body: json.encode(game.toCreateRequest()),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 201) {
      final body = response.body.isNotEmpty ? response.body : 'empty';
      throw Exception(
          'Failed to create game: ${response.statusCode} $uri body: $body');
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Game?> getActiveGame() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/games/active'));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to get active game: ${response.statusCode}');
    }
    return Game.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  Future<void> updateActiveGame(Game game, int currentTurnTeam,
      DateTime? currentTurnStart, List<GameTurn> turns) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/games/active'),
      body: json.encode({
        'current_turn_team': currentTurnTeam,
        'current_turn_start': currentTurnStart?.toIso8601String(),
        'turns': turns.map((e) => e.toJson()).toList(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update active game: ${response.statusCode}');
    }
  }

  Future<Game> finishGame(String gameId, int winningTeam) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/games/active/finish'),
      body: json.encode({'winning_team': winningTeam}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to finish game: ${response.statusCode}');
    }
    return Game.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }
}
