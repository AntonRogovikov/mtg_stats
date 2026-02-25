import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/providers/stats_providers.dart';
import 'package:mtg_stats/services/stats_service.dart';

class _FakeStatsService extends StatsService {
  @override
  Future<List<PlayerStats>> getPlayerStats() async {
    return const [
      PlayerStats(
        playerName: 'P1',
        gamesCount: 10,
        winsCount: 7,
        winPercent: 70,
        firstMoveWins: 3,
        firstMoveGames: 5,
        firstMoveWinPercent: 60,
        avgTurnDurationSec: 30,
        maxTurnDurationSec: 60,
        bestDeckName: 'D1',
        bestDeckWins: 4,
        bestDeckGames: 5,
      ),
      PlayerStats(
        playerName: 'P2',
        gamesCount: 10,
        winsCount: 5,
        winPercent: 50,
        firstMoveWins: 2,
        firstMoveGames: 5,
        firstMoveWinPercent: 40,
        avgTurnDurationSec: 40,
        maxTurnDurationSec: 80,
        bestDeckName: 'D2',
        bestDeckWins: 3,
        bestDeckGames: 6,
      ),
    ];
  }

  @override
  Future<List<DeckStats>> getDeckStats() async {
    return const [
      DeckStats(
        deckId: 1,
        deckName: 'Deck High',
        gamesCount: 8,
        winsCount: 6,
        winPercent: 75,
      ),
      DeckStats(
        deckId: 2,
        deckName: 'Deck Low',
        gamesCount: 8,
        winsCount: 3,
        winPercent: 37.5,
      ),
    ];
  }
}

void main() {
  test('statsDataProvider sorts players and decks by win rate desc', () async {
    final container = ProviderContainer(
      overrides: [
        statsServiceProvider.overrideWithValue(_FakeStatsService()),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(statsDataProvider.future);

    expect(data.playerStats.first.playerName, 'P1');
    expect(data.deckStats.first.deckName, 'Deck High');
  });
}
