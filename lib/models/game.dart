/// Модели игры: ход, игрок, игра (сериализация JSON для API).
class GameTurn {
  final int teamNumber;
  final Duration duration;
  final Duration overtime;

  GameTurn({
    required this.teamNumber,
    required this.duration,
    required this.overtime,
  });

  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  factory GameTurn.fromJson(Map<String, dynamic> json) {
    return GameTurn(
      teamNumber: _parseInt(json['team_number'], 1),
      duration: Duration(seconds: _parseInt(json['duration_sec'])),
      overtime: Duration(seconds: _parseInt(json['overtime_sec'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'team_number': teamNumber,
        'duration_sec': duration.inSeconds,
        'overtime_sec': overtime.inSeconds,
      };
}

class GamePlayer {
  final String userId;
  final String userName;
  final String deckName;
  final int deckId;

  const GamePlayer({
    required this.userId,
    required this.userName,
    required this.deckName,
    required this.deckId,
  });

  factory GamePlayer.fromJson(Map<String, dynamic> json) {
    String userId;
    String userName;
    final user = json['user'] as Map<String, dynamic>?;
    if (user != null) {
      final id = user['id'];
      userId = id is int ? id.toString() : (id as String? ?? '');
      userName = user['name'] as String? ?? '';
    } else {
      userId = json['user_id']?.toString() ?? '';
      userName = json['user_name'] as String? ?? '';
    }
    return GamePlayer(
      userId: userId,
      userName: userName,
      deckName: json['deck_name'] as String? ?? '',
      deckId: json['deck_id'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_name': userName,
        'deck_name': deckName,
        'deck_id': deckId,
      };
}

class Game {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final int turnLimitSeconds;
  final int firstMoveTeam;
  final List<GamePlayer> players;
  final List<GameTurn> turns;
  /// Произвольные названия команд (могут приходить из API).
  String? team1Name;
  String? team2Name;
  int? winningTeam;
  int? currentTurnTeam;
  DateTime? currentTurnStart;

  Game({
    required this.id,
    required this.startTime,
    required this.turnLimitSeconds,
    required this.firstMoveTeam,
    required this.players,
    List<GameTurn>? turns,
    this.endTime,
    this.team1Name,
    this.team2Name,
    this.winningTeam,
    this.currentTurnTeam,
    this.currentTurnStart,
  }) : turns = turns ?? [];

  Duration get totalDuration =>
      (endTime ?? DateTime.now()).difference(startTime);

  Duration get averageTurnDuration {
    if (turns.isEmpty) return Duration.zero;
    final totalSeconds =
        turns.fold<int>(0, (sum, t) => sum + t.duration.inSeconds);
    return Duration(seconds: totalSeconds ~/ turns.length);
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is int ? idRaw.toString() : (idRaw as String? ?? '');
    return Game(
      id: id,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      turnLimitSeconds: json['turn_limit_seconds'] as int? ?? 0,
      firstMoveTeam: json['first_move_team'] as int? ?? 1,
      players: (json['players'] as List<dynamic>?)
              ?.map((e) => GamePlayer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      turns: (json['turns'] as List<dynamic>?)
              ?.map((e) => GameTurn.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      team1Name: json['team1_name'] as String?,
      team2Name: json['team2_name'] as String?,
      winningTeam: json['winning_team'] as int?,
      currentTurnTeam: json['current_turn_team'] as int?,
      currentTurnStart: json['current_turn_start'] != null
          ? DateTime.parse(json['current_turn_start'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'turn_limit_seconds': turnLimitSeconds,
        'first_move_team': firstMoveTeam,
        'players': players.map((e) => e.toJson()).toList(),
        'turns': turns.map((e) => e.toJson()).toList(),
        'team1_name': team1Name,
        'team2_name': team2Name,
        'winning_team': winningTeam,
      };

  Map<String, dynamic> toCreateRequest() => {
        'turn_limit_seconds': turnLimitSeconds,
        'first_move_team': firstMoveTeam,
        'players': players.map((e) => e.toJson()).toList(),
        'team1_name': team1Name,
        'team2_name': team2Name,
      };
}

