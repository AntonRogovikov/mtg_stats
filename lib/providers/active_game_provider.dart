import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/providers/stats_providers.dart';

class ActiveGameState {
  final Game? activeGame;
  final int currentTurnTeam;
  final DateTime? currentTurnStart;
  final String? team1NameOverride;
  final String? team2NameOverride;
  final Map<int, Deck> decksById;
  final bool isDecksLoading;

  const ActiveGameState({
    this.activeGame,
    this.currentTurnTeam = 1,
    this.currentTurnStart,
    this.team1NameOverride,
    this.team2NameOverride,
    this.decksById = const {},
    this.isDecksLoading = false,
  });

  ActiveGameState copyWith({
    Game? activeGame,
    bool clearActiveGame = false,
    int? currentTurnTeam,
    DateTime? currentTurnStart,
    bool clearCurrentTurnStart = false,
    String? team1NameOverride,
    bool clearTeam1NameOverride = false,
    String? team2NameOverride,
    bool clearTeam2NameOverride = false,
    Map<int, Deck>? decksById,
    bool? isDecksLoading,
  }) {
    return ActiveGameState(
      activeGame: clearActiveGame ? null : (activeGame ?? this.activeGame),
      currentTurnTeam: currentTurnTeam ?? this.currentTurnTeam,
      currentTurnStart: clearCurrentTurnStart
          ? null
          : (currentTurnStart ?? this.currentTurnStart),
      team1NameOverride: clearTeam1NameOverride
          ? null
          : (team1NameOverride ?? this.team1NameOverride),
      team2NameOverride: clearTeam2NameOverride
          ? null
          : (team2NameOverride ?? this.team2NameOverride),
      decksById: decksById ?? this.decksById,
      isDecksLoading: isDecksLoading ?? this.isDecksLoading,
    );
  }

  bool get hasActiveGame => activeGame != null;
  bool get isTurnRunning => currentTurnStart != null;
  bool get isPaused => activeGame?.isPaused ?? false;
  DateTime? get pauseStartedAt => activeGame?.pauseStartedAt;
  int get turnLimitSeconds => activeGame?.turnLimitSeconds ?? 0;
  int get teamTimeLimitSeconds => activeGame?.teamTimeLimitSeconds ?? 0;
  String get team1Name => team1NameOverride ?? activeGame?.team1Name ?? 'Команда 1';
  String get team2Name => team2NameOverride ?? activeGame?.team2Name ?? 'Команда 2';
  Duration get currentTurnElapsed {
    if (currentTurnStart == null) return Duration.zero;
    if (isPaused && pauseStartedAt != null) {
      return pauseStartedAt!.difference(currentTurnStart!);
    }
    return DateTime.now().difference(currentTurnStart!);
  }
}

class ActiveGameController extends Notifier<ActiveGameState> {
  @override
  ActiveGameState build() {
    return const ActiveGameState();
  }

  void setActiveGameFromApi(Game game) {
    state = state.copyWith(
      activeGame: game,
      currentTurnTeam: game.currentTurnTeam ?? 1,
      currentTurnStart: game.currentTurnStart,
      team1NameOverride: state.team1NameOverride ?? game.team1Name,
      team2NameOverride: state.team2NameOverride ?? game.team2Name,
    );
  }

  void setTeamNames({String? team1Name, String? team2Name}) {
    state = state.copyWith(
      team1NameOverride: team1Name ?? state.team1NameOverride,
      team2NameOverride: team2Name ?? state.team2NameOverride,
    );
  }

  void clearActiveGame() {
    state = state.copyWith(
      clearActiveGame: true,
      currentTurnTeam: 1,
      clearCurrentTurnStart: true,
      clearTeam1NameOverride: true,
      clearTeam2NameOverride: true,
    );
  }

  Future<void> syncActiveGameFromServer() async {
    final game = await ref.read(gameServiceProvider).getActiveGame();
    if (game == null) {
      clearActiveGame();
      return;
    }
    setActiveGameFromApi(game);
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
    final updated = state.isPaused
        ? await gameService.resumeGame()
        : await gameService.pauseGame();
    if (updated != null) {
      setActiveGameFromApi(updated);
    }
    return updated;
  }

  Future<Game?> toggleTurn() async {
    final gameService = ref.read(gameServiceProvider);
    final game = state.activeGame;
    if (game == null) return null;

    if (state.isTurnRunning) {
      final turnStart = state.currentTurnStart!;
      final now = DateTime.now();
      final elapsed = now.difference(turnStart);
      final limit = Duration(seconds: state.turnLimitSeconds);
      final overtime = state.turnLimitSeconds > 0 && elapsed > limit
          ? elapsed - limit
          : Duration.zero;

      final newTurn = GameTurn(
        teamNumber: state.currentTurnTeam,
        duration: elapsed,
        overtime: overtime,
      );
      final newTurns = [...game.turns, newTurn];
      final newTeam = state.currentTurnTeam == 1 ? 2 : 1;
      final updated = await gameService.updateActiveGame(game, newTeam, now, newTurns);
      if (updated != null) {
        setActiveGameFromApi(updated);
      }
      return updated;
    }

    final updated = await gameService.startTurn();
    if (updated != null) {
      setActiveGameFromApi(updated);
    }
    return updated;
  }

  Future<void> finishGame({
    required int winningTeam,
    bool isTechnicalDefeat = false,
  }) async {
    var finishedOnServer = false;
    final game = state.activeGame;
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
    clearActiveGame();
  }
}

final activeGameControllerProvider =
    NotifierProvider<ActiveGameController, ActiveGameState>(
  ActiveGameController.new,
);
