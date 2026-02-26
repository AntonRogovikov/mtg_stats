import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/services/stats_service.dart';

final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService(client: ref.watch(httpClientProvider));
});

class StatsData {
  final List<PlayerStats> playerStats;
  final List<DeckStats> deckStats;

  const StatsData({
    required this.playerStats,
    required this.deckStats,
  });
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

final deckMatchupsProvider =
    FutureProvider<List<DeckMatchupStats>>((ref) async {
  final statsService = ref.watch(statsServiceProvider);
  final matchups = await statsService.getDeckMatchups();
  matchups.sort((a, b) {
    final byDeck1 = a.deck1Name.compareTo(b.deck1Name);
    if (byDeck1 != 0) return byDeck1;
    return a.deck2Name.compareTo(b.deck2Name);
  });
  return matchups;
});

final metaDashboardProvider = FutureProvider<MetaDashboardData>((ref) async {
  final statsService = ref.watch(statsServiceProvider);
  return statsService.getMetaDashboard();
});
