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
}
