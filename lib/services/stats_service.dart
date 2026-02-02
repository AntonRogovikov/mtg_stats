import 'dart:convert';

import 'package:http/http.dart' as http;

/// Статистика игрока: игры, победы, % побед, первый ход, время хода, лучшая колода.
class PlayerStats {
  final String playerName;
  final int gamesCount;
  final int winsCount;
  final double winPercent;
  final int firstMoveWins;
  final int firstMoveGames;
  final double firstMoveWinPercent;
  final int avgTurnDurationSec;
  final int maxTurnDurationSec;
  final String bestDeckName;
  final int bestDeckWins;
  final int bestDeckGames;

  PlayerStats({
    required this.playerName,
    required this.gamesCount,
    required this.winsCount,
    required this.winPercent,
    required this.firstMoveWins,
    required this.firstMoveGames,
    required this.firstMoveWinPercent,
    required this.avgTurnDurationSec,
    required this.maxTurnDurationSec,
    required this.bestDeckName,
    required this.bestDeckWins,
    required this.bestDeckGames,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      playerName: json['player_name'] as String? ?? '',
      gamesCount: json['games_count'] as int? ?? 0,
      winsCount: json['wins_count'] as int? ?? 0,
      winPercent: (json['win_percent'] as num?)?.toDouble() ?? 0,
      firstMoveWins: json['first_move_wins'] as int? ?? 0,
      firstMoveGames: json['first_move_games'] as int? ?? 0,
      firstMoveWinPercent:
          (json['first_move_win_percent'] as num?)?.toDouble() ?? 0,
      avgTurnDurationSec: json['avg_turn_duration_sec'] as int? ?? 0,
      maxTurnDurationSec: json['max_turn_duration_sec'] as int? ?? 0,
      bestDeckName: json['best_deck_name'] as String? ?? '',
      bestDeckWins: json['best_deck_wins'] as int? ?? 0,
      bestDeckGames: json['best_deck_games'] as int? ?? 0,
    );
  }
}

/// Статистика колоды: игры, победы, % побед.
class DeckStats {
  final int deckId;
  final String deckName;
  final int gamesCount;
  final int winsCount;
  final double winPercent;

  DeckStats({
    required this.deckId,
    required this.deckName,
    required this.gamesCount,
    required this.winsCount,
    required this.winPercent,
  });

  factory DeckStats.fromJson(Map<String, dynamic> json) {
    return DeckStats(
      deckId: json['deck_id'] as int? ?? 0,
      deckName: json['deck_name'] as String? ?? '',
      gamesCount: json['games_count'] as int? ?? 0,
      winsCount: json['wins_count'] as int? ?? 0,
      winPercent: (json['win_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// API статистики: игроки и колоды.
class StatsService {
  static const String baseUrl =
      'https://mtg-stats-backend-production-1a71.up.railway.app';

  Future<List<PlayerStats>> getPlayerStats() async {
    final response = await http.get(Uri.parse('$baseUrl/api/stats/players'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load player stats: ${response.statusCode}');
    }
    final list = json.decode(response.body) as List<dynamic>;
    return list
        .map((e) => PlayerStats.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DeckStats>> getDeckStats() async {
    final response = await http.get(Uri.parse('$baseUrl/api/stats/decks'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load deck stats: ${response.statusCode}');
    }
    final list = json.decode(response.body) as List<dynamic>;
    return list
        .map((e) => DeckStats.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
