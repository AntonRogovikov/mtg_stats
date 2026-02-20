import 'package:mtg_stats/models/game.dart';

/// Синглтон: активная игра, текущий ход, таймеры (синхронизация с API через GameService).
class GameManager {
  Game? _activeGame;
  int _currentTurnTeam = 1;
  DateTime? _currentTurnStart;

  /// Локальные названия команд для активной игры (могут быть переопределены из API).
  String? _team1Name;
  String? _team2Name;

  GameManager._();

  static final GameManager instance = GameManager._();

  Game? get activeGame => _activeGame;
  bool get hasActiveGame => _activeGame != null;

  /// Названия команд для отображения на экране активной игры.
  /// Приоритет: локальное переопределение -> поля игры из API -> дефолт.
  String get team1Name =>
      _team1Name ?? _activeGame?.team1Name ?? 'Команда 1';
  String get team2Name =>
      _team2Name ?? _activeGame?.team2Name ?? 'Команда 2';

  int get currentTurnTeam => _currentTurnTeam;
  bool get isTurnRunning => _currentTurnStart != null;
  DateTime? get currentTurnStart => _currentTurnStart;
  bool get isPaused => _activeGame?.isPaused ?? false;
  DateTime? get pauseStartedAt => _activeGame?.pauseStartedAt;

  int get turnLimitSeconds => _activeGame?.turnLimitSeconds ?? 0;
  int get teamTimeLimitSeconds => _activeGame?.teamTimeLimitSeconds ?? 0;

  Duration get currentTurnElapsed {
    if (_currentTurnStart == null) return Duration.zero;
    if (isPaused && pauseStartedAt != null) {
      return pauseStartedAt!.difference(_currentTurnStart!);
    }
    return DateTime.now().difference(_currentTurnStart!);
  }

  void startNewGame({
    required List<GamePlayer> players,
    required int turnLimitSeconds,
    required int firstMoveTeam,
    String? team1Name,
    String? team2Name,
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
    _team1Name = team1Name;
    _team2Name = team2Name;
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
    _team1Name = null;
    _team2Name = null;
  }

  void setActiveGameFromApi(Game game) {
    _activeGame = game;
    _currentTurnTeam = game.currentTurnTeam ?? 1;
    _currentTurnStart = game.currentTurnStart;
    _team1Name ??= game.team1Name;
    _team2Name ??= game.team2Name;
  }

  /// Устанавливает локальные названия команд для текущей активной игры.
  void setTeamNames({String? team1Name, String? team2Name}) {
    _team1Name = team1Name;
    _team2Name = team2Name;
  }
}

