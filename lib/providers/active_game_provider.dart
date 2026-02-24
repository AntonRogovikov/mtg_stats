import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/providers/stats_providers.dart';
import 'package:mtg_stats/services/game_manager.dart';

class ActiveGameState {
  final Map<int, Deck> decksById;
  final bool isDecksLoading;

  const ActiveGameState({
    this.decksById = const {},
    this.isDecksLoading = false,
  });

  ActiveGameState copyWith({
    Map<int, Deck>? decksById,
    bool? isDecksLoading,
  }) {
    return ActiveGameState(
      decksById: decksById ?? this.decksById,
      isDecksLoading: isDecksLoading ?? this.isDecksLoading,
    );
  }
}

class ActiveGameController extends Notifier<ActiveGameState> {
  @override
  ActiveGameState build() {
    return const ActiveGameState();
  }

  Future<void> ensureDecksLoaded() async {
    if (state.isDecksLoading || state.decksById.isNotEmpty) return;
    state = state.copyWith(isDecksLoading: true);
    try {
      final decks = await ref.read(deckServiceProvider).getAllDecks();
      state = state.copyWith(
        decksById: {for (final d in decks) d.id: d},
        isDecksLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isDecksLoading: false);
    }
  }

  Future<Game?> togglePause() async {
    final gameService = ref.read(gameServiceProvider);
    final updated = GameManager.instance.isPaused
        ? await gameService.resumeGame()
        : await gameService.pauseGame();
    if (updated != null) {
      GameManager.instance.setActiveGameFromApi(updated);
    }
    return updated;
  }

  Future<Game?> toggleTurn() async {
    final gameService = ref.read(gameServiceProvider);
    final game = GameManager.instance.activeGame;
    if (game == null) return null;

    if (GameManager.instance.isTurnRunning) {
      final turnStart = GameManager.instance.currentTurnStart!;
      final now = DateTime.now();
      final elapsed = now.difference(turnStart);
      final limit = Duration(seconds: GameManager.instance.turnLimitSeconds);
      final overtime = GameManager.instance.turnLimitSeconds > 0 && elapsed > limit
          ? elapsed - limit
          : Duration.zero;

      final newTurn = GameTurn(
        teamNumber: GameManager.instance.currentTurnTeam,
        duration: elapsed,
        overtime: overtime,
      );
      final newTurns = [...game.turns, newTurn];
      final newTeam = GameManager.instance.currentTurnTeam == 1 ? 2 : 1;
      final updated = await gameService.updateActiveGame(game, newTeam, now, newTurns);
      if (updated != null) {
        GameManager.instance.setActiveGameFromApi(updated);
      }
      return updated;
    }

    final updated = await gameService.startTurn();
    if (updated != null) {
      GameManager.instance.setActiveGameFromApi(updated);
    }
    return updated;
  }

  Future<void> finishGame({
    required int winningTeam,
    bool isTechnicalDefeat = false,
  }) async {
    var finishedOnServer = false;
    final game = GameManager.instance.activeGame;
    if (game != null) {
      try {
        await ref.read(gameServiceProvider).finishGame(
              game.id,
              winningTeam,
              isTechnicalDefeat: isTechnicalDefeat,
            );
        finishedOnServer = true;
      } catch (_) {}
    }

    if (finishedOnServer) {
      // Обновляем источники данных, от которых зависят вероятности колод и история.
      ref.invalidate(statsDataProvider);
      ref.invalidate(gamesHistoryProvider);
    }

    GameManager.instance.finishGame(winningTeam: winningTeam);
    GameManager.instance.clearActiveGame();
  }
}

final activeGameControllerProvider =
    NotifierProvider<ActiveGameController, ActiveGameState>(
  ActiveGameController.new,
);
