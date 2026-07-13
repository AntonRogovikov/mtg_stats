import 'package:mtg_stats/models/game.dart';

/// Чистая логика статистики отдельной колоды по истории игр.
/// Без Flutter-зависимостей — покрыто тестами (`test/core/deck_history_test.dart`).

/// Партии, в которых участвовала колода [deckId], в исходном порядке [games].
List<Game> gamesForDeck(List<Game> games, int deckId) {
  return games
      .where((game) => game.players.any((p) => p.deckId == deckId))
      .toList(growable: false);
}

/// Дата самой ранней игры из списка (дебют). Пустой список → null.
DateTime? firstPlayedDate(List<Game> deckGames) {
  DateTime? earliest;
  for (final game in deckGames) {
    if (earliest == null || game.startTime.isBefore(earliest)) {
      earliest = game.startTime;
    }
  }
  return earliest;
}

/// Дата самой поздней игры из списка. Пустой список → null.
DateTime? lastPlayedDate(List<Game> deckGames) {
  DateTime? latest;
  for (final game in deckGames) {
    if (latest == null || game.startTime.isAfter(latest)) {
      latest = game.startTime;
    }
  }
  return latest;
}

/// Победила ли колода [deckId] в партии [game].
///
/// Команда игрока определяется порядком в списке: первая половина `players` —
/// команда 1, вторая — команда 2 (так же, как на экранах истории и активной игры).
/// Возвращает null, если игра не завершена или колоды в партии нет.
bool? deckWon(Game game, int deckId) {
  if (game.winningTeam == null) return null;
  final index = game.players.indexWhere((p) => p.deckId == deckId);
  if (index < 0) return null;
  final half = (game.players.length / 2).ceil();
  final team = index < half ? 1 : 2;
  return game.winningTeam == team;
}
