import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_stats/models/game.dart';

void main() {
  test('Game.fromJson parses public token and players', () {
    final json = <String, dynamic>{
      'id': 123,
      'public_view_token': 'abc-token',
      'start_time': '2026-02-01T10:00:00Z',
      'turn_limit_seconds': 300,
      'team_time_limit_seconds': 1800,
      'first_move_team': 1,
      'players': [
        {
          'user': {'id': 1, 'name': 'Anton'},
          'deck_id': 10,
          'deck_name': 'Deck A',
        },
        {
          'user': {'id': 2, 'name': 'Max'},
          'deck_id': 11,
          'deck_name': 'Deck B',
        },
      ],
      'turns': [
        {
          'team_number': 1,
          'duration_sec': 42,
          'overtime_sec': 0,
        }
      ],
      'current_turn_team': 2,
      'is_paused': false,
      'total_pause_duration_seconds': 0,
    };

    final game = Game.fromJson(json);

    expect(game.id, '123');
    expect(game.publicViewToken, 'abc-token');
    expect(game.players.length, 2);
    expect(game.players.first.userName, 'Anton');
    expect(game.turns.single.duration.inSeconds, 42);
  });

  test('RematchMode has expected API values', () {
    expect(RematchMode.classicRematch.apiValue, 'classic_rematch');
    expect(
      RematchMode.swapTeamDecksRandomPerPlayer.apiValue,
      'swap_team_decks_random_per_player',
    );
  });
}
