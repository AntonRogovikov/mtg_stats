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
