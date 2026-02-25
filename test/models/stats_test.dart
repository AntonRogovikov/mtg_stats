import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_stats/models/stats.dart';

void main() {
  test('DeckMatchupStats.fromJson parses rates and names', () {
    final stats = DeckMatchupStats.fromJson({
      'deck1_id': 1,
      'deck1_name': 'Aggro',
      'deck2_id': 2,
      'deck2_name': 'Control',
      'games_count': 10,
      'deck1_wins': 6,
      'deck2_wins': 4,
      'deck1_win_rate': 60.0,
      'deck2_win_rate': 40.0,
    });

    expect(stats.deck1Name, 'Aggro');
    expect(stats.deck2Name, 'Control');
    expect(stats.gamesCount, 10);
    expect(stats.deck1WinRate, 60.0);
  });

  test('MetaDashboardData.fromJson parses top decks and periods', () {
    final data = MetaDashboardData.fromJson({
      'group_by': 'week',
      'total_games': 12,
      'unique_decks': 4,
      'top_played_decks': [
        {
          'deck_id': 1,
          'deck_name': 'A',
          'games_count': 8,
          'wins_count': 5,
          'win_rate': 62.5,
          'meta_share': 66.7,
        }
      ],
      'top_win_rate_decks': [
        {
          'deck_id': 2,
          'deck_name': 'B',
          'games_count': 4,
          'wins_count': 3,
          'win_rate': 75.0,
          'meta_share': 33.3,
        }
      ],
      'periods': [
        {
          'period': '2026W8',
          'total_games': 12,
          'decks': [],
        }
      ],
    });

    expect(data.groupBy, 'week');
    expect(data.totalGames, 12);
    expect(data.topPlayedDecks.single.deckName, 'A');
    expect(data.periods.single.period, '2026W8');
  });
}
