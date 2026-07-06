/// Статистика игрока по играм и победам.
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
  final int? currentWinStreak;
  final int? currentLossStreak;
  final int? maxWinStreak;
  final int? maxLossStreak;

  const PlayerStats({
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
    this.currentWinStreak,
    this.currentLossStreak,
    this.maxWinStreak,
    this.maxLossStreak,
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
      currentWinStreak: json['current_win_streak'] as int?,
      currentLossStreak: json['current_loss_streak'] as int?,
      maxWinStreak: json['max_win_streak'] as int?,
      maxLossStreak: json['max_loss_streak'] as int?,
    );
  }
}

/// Статистика колоды по играм и победам.
class DeckStats {
  final int deckId;
  final String deckName;
  final int gamesCount;
  final int winsCount;
  final double winPercent;

  const DeckStats({
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

/// Статистика матчапа между парой колод.
class DeckMatchupStats {
  final int deck1Id;
  final String deck1Name;
  final int deck2Id;
  final String deck2Name;
  final int gamesCount;
  final int deck1Wins;
  final int deck2Wins;
  final double deck1WinRate;
  final double deck2WinRate;

  const DeckMatchupStats({
    required this.deck1Id,
    required this.deck1Name,
    required this.deck2Id,
    required this.deck2Name,
    required this.gamesCount,
    required this.deck1Wins,
    required this.deck2Wins,
    required this.deck1WinRate,
    required this.deck2WinRate,
  });

  factory DeckMatchupStats.fromJson(Map<String, dynamic> json) {
    return DeckMatchupStats(
      deck1Id: json['deck1_id'] as int? ?? 0,
      deck1Name: json['deck1_name'] as String? ?? '',
      deck2Id: json['deck2_id'] as int? ?? 0,
      deck2Name: json['deck2_name'] as String? ?? '',
      gamesCount: json['games_count'] as int? ?? 0,
      deck1Wins: json['deck1_wins'] as int? ?? 0,
      deck2Wins: json['deck2_wins'] as int? ?? 0,
      deck1WinRate: (json['deck1_win_rate'] as num?)?.toDouble() ?? 0,
      deck2WinRate: (json['deck2_win_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

// Модели мета-дашборда (MetaDeckStat, MetaPeriodStats, MetaDashboardData)
// удалены вместе со страницами мета-среза/матчапов/синергии — см. историю git.
