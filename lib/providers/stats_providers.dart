import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/services/stats_service.dart';

final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService();
});

class StatsData {
  final List<PlayerStats> playerStats;
  final List<DeckStats> deckStats;

  const StatsData({
    required this.playerStats,
    required this.deckStats,
  });
}

class MetaDashboardQuery {
  final String groupBy;
  final DateTime? from;
  final DateTime? to;

  const MetaDashboardQuery({
    this.groupBy = 'week',
    this.from,
    this.to,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MetaDashboardQuery &&
        other.groupBy == groupBy &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(groupBy, from, to);
}

final statsDataProvider = FutureProvider<StatsData>((ref) async {
  final statsService = ref.watch(statsServiceProvider);
  final results = await Future.wait([
    statsService.getPlayerStats(),
    statsService.getDeckStats(),
  ]);

  final playerStats = List<PlayerStats>.from(results[0] as List<PlayerStats>)
    ..sort((a, b) {
      final cmp = b.winPercent.compareTo(a.winPercent);
      if (cmp != 0) return cmp;
      return b.winsCount.compareTo(a.winsCount);
    });

  final deckStats = List<DeckStats>.from(results[1] as List<DeckStats>)
    ..sort((a, b) {
      final cmp = b.winPercent.compareTo(a.winPercent);
      if (cmp != 0) return cmp;
      return b.winsCount.compareTo(a.winsCount);
    });

  return StatsData(
    playerStats: playerStats,
    deckStats: deckStats,
  );
});

final deckMatchupsProvider = FutureProvider<List<DeckMatchupStats>>((ref) async {
  final statsService = ref.watch(statsServiceProvider);
  final matchups = await statsService.getDeckMatchups();
  matchups.sort((a, b) {
    final byDeck1 = a.deck1Name.compareTo(b.deck1Name);
    if (byDeck1 != 0) return byDeck1;
    return a.deck2Name.compareTo(b.deck2Name);
  });
  return matchups;
});

final metaDashboardProvider =
    FutureProvider.family<MetaDashboardData, MetaDashboardQuery>((ref, query) async {
  final statsService = ref.watch(statsServiceProvider);
  return statsService.getMetaDashboard(
    groupBy: query.groupBy,
    from: query.from,
    to: query.to,
  );
});
