import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_stats/core/deck_history.dart';
import 'package:mtg_stats/models/game.dart';

Game _game(
  String id,
  DateTime startTime,
  List<int> deckIds, {
  int? winningTeam,
}) =>
    Game(
      id: id,
      startTime: startTime,
      turnLimitSeconds: 0,
      firstMoveTeam: 1,
      winningTeam: winningTeam,
      players: [
        for (final deckId in deckIds)
          GamePlayer(
            userId: 'u$deckId',
            userName: 'u$deckId',
            deckName: 'd$deckId',
            deckId: deckId,
          ),
      ],
    );

void main() {
  group('gamesForDeck', () {
    test('оставляет только партии, где встречается колода', () {
      final games = [
        _game('1', DateTime(2026, 1, 1), [10, 20]),
        _game('2', DateTime(2026, 1, 2), [30, 40]),
        _game('3', DateTime(2026, 1, 3), [10, 40]),
      ];
      final result = gamesForDeck(games, 10);
      expect(result.map((g) => g.id), ['1', '3']);
    });

    test('нет партий с колодой → пустой список', () {
      final games = [
        _game('1', DateTime(2026, 1, 1), [10, 20]),
      ];
      expect(gamesForDeck(games, 99), isEmpty);
    });
  });

  group('firstPlayedDate / lastPlayedDate', () {
    test('берут крайние даты из списка', () {
      final games = [
        _game('1', DateTime(2026, 3, 5), [10]),
        _game('2', DateTime(2026, 1, 2), [10]),
        _game('3', DateTime(2026, 7, 9), [10]),
      ];
      expect(firstPlayedDate(games), DateTime(2026, 1, 2));
      expect(lastPlayedDate(games), DateTime(2026, 7, 9));
    });

    test('пустой список → null', () {
      expect(firstPlayedDate([]), isNull);
      expect(lastPlayedDate([]), isNull);
    });
  });

  group('deckWon', () {
    test('колода в победившей команде → true', () {
      // 4 игрока: [10,20] — команда 1, [30,40] — команда 2.
      final game = _game('1', DateTime(2026, 1, 1), [10, 20, 30, 40],
          winningTeam: 1);
      expect(deckWon(game, 10), isTrue); // команда 1
      expect(deckWon(game, 20), isTrue); // команда 1
    });

    test('колода в проигравшей команде → false', () {
      final game = _game('1', DateTime(2026, 1, 1), [10, 20, 30, 40],
          winningTeam: 1);
      expect(deckWon(game, 30), isFalse); // команда 2
      expect(deckWon(game, 40), isFalse); // команда 2
    });

    test('незавершённая игра (winningTeam == null) → null', () {
      final game = _game('1', DateTime(2026, 1, 1), [10, 20]);
      expect(deckWon(game, 10), isNull);
    });

    test('колоды нет в партии → null', () {
      final game =
          _game('1', DateTime(2026, 1, 1), [10, 20], winningTeam: 1);
      expect(deckWon(game, 99), isNull);
    });

    test('дуэль 1 на 1: второй игрок — команда 2', () {
      final game =
          _game('1', DateTime(2026, 1, 1), [10, 20], winningTeam: 2);
      expect(deckWon(game, 10), isFalse); // индекс 0 → команда 1
      expect(deckWon(game, 20), isTrue); // индекс 1 → команда 2
    });
  });
}
