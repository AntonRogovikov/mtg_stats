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

/// Агрегат по колоде в одном периоде мета-дашборда.
class MetaDeckStat {
  final int deckId;
  final String deckName;
  final int gamesCount;
  final int winsCount;
  final double winRate;
  final double metaShare;

  const MetaDeckStat({
    required this.deckId,
    required this.deckName,
    required this.gamesCount,
    required this.winsCount,
    required this.winRate,
    required this.metaShare,
  });

  factory MetaDeckStat.fromJson(Map<String, dynamic> json) {
    return MetaDeckStat(
      deckId: json['deck_id'] as int? ?? 0,
      deckName: json['deck_name'] as String? ?? '',
      gamesCount: json['games_count'] as int? ?? 0,
      winsCount: json['wins_count'] as int? ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      metaShare: (json['meta_share'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Период агрегирования мета-дашборда.
class MetaPeriodStats {
  final String period;
  final int totalGames;
  final List<MetaDeckStat> decks;

  const MetaPeriodStats({
    required this.period,
    required this.totalGames,
    required this.decks,
  });

  factory MetaPeriodStats.fromJson(Map<String, dynamic> json) {
    final decks = (json['decks'] as List<dynamic>? ?? const [])
        .map((e) => MetaDeckStat.fromJson(e as Map<String, dynamic>))
        .toList();
    return MetaPeriodStats(
      period: json['period'] as String? ?? '',
      totalGames: json['total_games'] as int? ?? 0,
      decks: decks,
    );
  }
}

/// Полный ответ мета-дашборда.
class MetaDashboardData {
  final String groupBy;
  final String? fromDate;
  final String? toDate;
  final int totalGames;
  final int uniqueDecks;
  final List<MetaDeckStat> topPlayedDecks;
  final List<MetaDeckStat> topWinRateDecks;
  final List<MetaPeriodStats> periods;

  const MetaDashboardData({
    required this.groupBy,
    required this.fromDate,
    required this.toDate,
    required this.totalGames,
    required this.uniqueDecks,
    required this.topPlayedDecks,
    required this.topWinRateDecks,
    required this.periods,
  });

  factory MetaDashboardData.fromJson(Map<String, dynamic> json) {
    final topPlayed = (json['top_played_decks'] as List<dynamic>? ?? const [])
        .map((e) => MetaDeckStat.fromJson(e as Map<String, dynamic>))
        .toList();
    final topWinRate = (json['top_win_rate_decks'] as List<dynamic>? ?? const [])
        .map((e) => MetaDeckStat.fromJson(e as Map<String, dynamic>))
        .toList();
    final periods = (json['periods'] as List<dynamic>? ?? const [])
        .map((e) => MetaPeriodStats.fromJson(e as Map<String, dynamic>))
        .toList();
    return MetaDashboardData(
      groupBy: json['group_by'] as String? ?? 'week',
      fromDate: json['from_date'] as String?,
      toDate: json['to_date'] as String?,
      totalGames: json['total_games'] as int? ?? 0,
      uniqueDecks: json['unique_decks'] as int? ?? 0,
      topPlayedDecks: topPlayed,
      topWinRateDecks: topWinRate,
      periods: periods,
    );
  }
}
