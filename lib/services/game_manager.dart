import 'package:mtg_stats/models/game.dart';

/// Синглтон: активная игра, текущий ход, таймеры. Синхронизация с API через GameService.
class GameManager {
  Game? _activeGame;
  int _currentTurnTeam = 1;
  DateTime? _currentTurnStart;

  GameManager._();

  static final GameManager instance = GameManager._();

  Game? get activeGame => _activeGame;
  bool get hasActiveGame => _activeGame != null;

  int get currentTurnTeam => _currentTurnTeam;
  bool get isTurnRunning => _currentTurnStart != null;
  DateTime? get currentTurnStart => _currentTurnStart;

  int get turnLimitSeconds => _activeGame?.turnLimitSeconds ?? 0;

  Duration get currentTurnElapsed {
    if (_currentTurnStart == null) return Duration.zero;
    return DateTime.now().difference(_currentTurnStart!);
  }

  void startNewGame({
    required List<GamePlayer> players,
    required int turnLimitSeconds,
    required int firstMoveTeam,
  }) {
    _activeGame = Game(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      turnLimitSeconds: turnLimitSeconds,
      firstMoveTeam: firstMoveTeam,
      players: players,
    );
    _currentTurnTeam = 1;
    _currentTurnStart = null;
  }

  void startTurn() {
    if (_activeGame == null || _currentTurnStart != null) return;
    _currentTurnStart = DateTime.now();
  }

  void endTurn() {
    if (_activeGame == null || _currentTurnStart == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_currentTurnStart!);
    final limit = Duration(seconds: turnLimitSeconds);
    final overtime = turnLimitSeconds > 0 && elapsed > limit
        ? elapsed - limit
        : Duration.zero;

    _activeGame!.turns.add(
      GameTurn(
        teamNumber: _currentTurnTeam,
        duration: elapsed,
        overtime: overtime,
      ),
    );

    _currentTurnStart = null;
    _currentTurnTeam = _currentTurnTeam == 1 ? 2 : 1;
  }

  void finishGame({required int winningTeam}) {
    if (_activeGame == null) return;
    _activeGame!
      ..winningTeam = winningTeam
      ..endTime = DateTime.now();
  }

  void clearActiveGame() {
    _activeGame = null;
    _currentTurnStart = null;
    _currentTurnTeam = 1;
  }

  void setActiveGameFromApi(Game game) {
    _activeGame = game;
    _currentTurnTeam = game.currentTurnTeam ?? 1;
    _currentTurnStart = game.currentTurnStart;
  }
}

