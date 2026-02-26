import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/format_utils.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/services/game_service.dart';

class PublicGamePage extends StatefulWidget {
  const PublicGamePage({super.key, required this.token});

  final String token;

  @override
  State<PublicGamePage> createState() => _PublicGamePageState();
}

class _PublicGamePageState extends State<PublicGamePage> {
  late final GameService _gameService;
  StreamSubscription<Game>? _subscription;
  Game? _game;
  DateTime? _lastUpdatedAt;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _gameService = ProviderScope.containerOf(context, listen: false)
        .read(gameServiceProvider);
    _startStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startStream() {
    _subscription?.cancel();
    _subscription = _gameService
        .streamPublicGameByToken(
      widget.token,
      interval: const Duration(seconds: 1),
    )
        .listen(
      (game) {
        if (!mounted) return;
        setState(() {
          _game = game;
          _lastUpdatedAt = DateTime.now();
          _lastError = null;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _lastError = error.toString();
        });
      },
    );
  }

  Duration _currentTurnElapsed(Game game) {
    final start = game.currentTurnStart;
    if (start == null) return Duration.zero;
    final end = (game.isPaused && game.pauseStartedAt != null)
        ? game.pauseStartedAt!
        : DateTime.now();
    return end.difference(start);
  }

  Duration _teamTotalTime(Game game, int teamNumber) {
    var total = Duration.zero;
    for (final turn in game.turns) {
      if (turn.teamNumber == teamNumber) {
        total += turn.duration;
      }
    }
    final currentTeam = game.currentTurnTeam ?? game.firstMoveTeam;
    final turnElapsed = _currentTurnElapsed(game);
    if (game.currentTurnStart != null && currentTeam == teamNumber) {
      total += turnElapsed;
    }
    return total;
  }

  String _teamName(Game game, int team) {
    if (team == 1) {
      return game.team1Name?.isNotEmpty == true ? game.team1Name! : 'Команда 1';
    }
    return game.team2Name?.isNotEmpty == true ? game.team2Name! : 'Команда 2';
  }

  Widget _timerTile({
    required String label,
    required String value,
    Color? color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;

    return Scaffold(
      appBar: AppBar(
        title: Text('Публичный матч (live)', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          IconButton(
            tooltip: 'Перезапустить стрим',
            onPressed: _startStream,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: game == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Подключение к live-стриму матча...'),
                    if (_lastError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _lastError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : Builder(
              builder: (context) {
                final team1 = _teamName(game, 1);
                final team2 = _teamName(game, 2);
                final currentTeam = game.currentTurnTeam ?? game.firstMoveTeam;
                final currentTeamName = _teamName(game, currentTeam);
                final turnElapsed = _currentTurnElapsed(game);
                final turnLimit = game.turnLimitSeconds;
                final hasTurnLimit = turnLimit > 0;
                final limitDuration = Duration(seconds: turnLimit);
                final overtime = hasTurnLimit && turnElapsed > limitDuration
                    ? turnElapsed - limitDuration
                    : Duration.zero;
                final displayTurn = hasTurnLimit
                    ? (overtime > Duration.zero
                        ? overtime
                        : limitDuration - turnElapsed)
                    : turnElapsed;
                final team1Total = _teamTotalTime(game, 1);
                final team2Total = _teamTotalTime(game, 2);
                final half = game.players.length ~/ 2;
                final team1Players = game.players.take(half).toList();
                final team2Players = game.players.skip(half).toList();

                return RefreshIndicator(
                  onRefresh: () async => _startStream(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: Colors.blueGrey[50],
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$team1 vs $team2',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      game.endTime == null
                                          ? 'LIVE'
                                          : 'Завершена',
                                    ),
                                    backgroundColor: game.endTime == null
                                        ? Colors.green[100]
                                        : Colors.grey[300],
                                  ),
                                  Chip(
                                    label: Text(
                                      'Сейчас ходит: $currentTeamName',
                                    ),
                                  ),
                                  if (_lastUpdatedAt != null)
                                    Chip(
                                      label: Text(
                                        'Обновлено: ${TimeOfDay.fromDateTime(_lastUpdatedAt!).format(context)}',
                                      ),
                                    ),
                                  const Chip(
                                      label: Text('Автообновление: 1 сек')),
                                ],
                              ),
                              if (_lastError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Проблема сети: $_lastError',
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _timerTile(
                        label: 'Общее время матча',
                        value: FormatUtils.formatDuration(game.totalDuration),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _timerTile(
                              label: '$team1 · суммарно',
                              value: FormatUtils.formatDuration(team1Total),
                              color: Colors.blue[800],
                            ),
                          ),
                          Expanded(
                            child: _timerTile(
                              label: '$team2 · суммарно',
                              value: FormatUtils.formatDuration(team2Total),
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                      _timerTile(
                        label: hasTurnLimit
                            ? 'Текущий ход (${FormatUtils.formatDuration(limitDuration)})'
                            : 'Текущий ход',
                        value: FormatUtils.formatDuration(displayTurn),
                        color:
                            overtime > Duration.zero ? Colors.red[700] : null,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Параметры матча',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Лимит хода: ${game.turnLimitSeconds > 0 ? FormatUtils.formatDuration(Duration(seconds: game.turnLimitSeconds)) : 'без лимита'}',
                              ),
                              Text(
                                'Лимит команды: ${game.teamTimeLimitSeconds > 0 ? FormatUtils.formatDuration(Duration(seconds: game.teamTimeLimitSeconds)) : 'без лимита'}',
                              ),
                              Text(
                                  'Первой ходила: ${_teamName(game, game.firstMoveTeam)}'),
                              Text('Пауза: ${game.isPaused ? 'да' : 'нет'}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Составы команд',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(team1,
                                  style: TextStyle(color: Colors.blue[800])),
                              const SizedBox(height: 6),
                              ...team1Players.map(
                                (p) => Text('• ${p.userName} — ${p.deckName}'),
                              ),
                              const SizedBox(height: 10),
                              Text(team2,
                                  style: TextStyle(color: Colors.green[800])),
                              const SizedBox(height: 6),
                              ...team2Players.map(
                                (p) => Text('• ${p.userName} — ${p.deckName}'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Лента ходов',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (game.turns.isEmpty)
                                const Text('Пока нет завершённых ходов')
                              else
                                ...game.turns.reversed
                                    .take(20)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map(
                                  (entry) {
                                    final t = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        'Ход ${game.turns.length - entry.key}: '
                                        '${_teamName(game, t.teamNumber)} · '
                                        '${FormatUtils.formatDuration(t.duration)}'
                                        '${t.overtime.inSeconds > 0 ? ' (+${FormatUtils.formatDuration(t.overtime)})' : ''}',
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
