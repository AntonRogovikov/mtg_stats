import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/services/game_manager.dart';
import 'package:mtg_stats/services/game_service.dart';

/// Страница активной партии: таймеры, ходы, завершение игры.
class ActiveGamePage extends StatefulWidget {
  const ActiveGamePage({super.key});

  @override
  State<ActiveGamePage> createState() => _ActiveGamePageState();
}

class _ActiveGamePageState extends State<ActiveGamePage> {
  Timer? _timer;
  final GameService _gameService = GameService();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = GameManager.instance.activeGame;

    if (game == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold();
    }

    final totalDuration = game.totalDuration;
    final hasTurnLimit = game.turnLimitSeconds > 0;
    final turnElapsed = GameManager.instance.currentTurnElapsed;
    final limit = Duration(seconds: GameManager.instance.turnLimitSeconds);
    final overtime =
        hasTurnLimit && turnElapsed > limit ? turnElapsed - limit : Duration.zero;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Активная партия',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
          backgroundColor: Colors.blueGrey[900],
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Общее время игры',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _formatDuration(totalDuration),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasTurnLimit) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ход команды ${GameManager.instance.currentTurnTeam}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (GameManager.instance.currentTurnTeam != null &&
                          _teamPlayers(game, GameManager.instance.currentTurnTeam!).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _teamPlayers(game, GameManager.instance.currentTurnTeam!).join(', '),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _formatDuration(turnElapsed),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: overtime > Duration.zero
                                ? Colors.red
                                : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Лимит хода: ${_formatDuration(limit)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Перерасход: ${_formatDuration(overtime)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: overtime > Duration.zero
                                  ? Colors.red
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (GameManager.instance.isTurnRunning) {
                              GameManager.instance.endTurn();
                              final g = GameManager.instance.activeGame;
                              if (g != null) {
                                try {
                                  await _gameService.updateActiveGame(
                                    g,
                                    GameManager.instance.currentTurnTeam,
                                    GameManager.instance.currentTurnStart,
                                    g.turns,
                                  );
                                } catch (_) {}
                              }
                            } else {
                              GameManager.instance.startTurn();
                              final g = GameManager.instance.activeGame;
                              if (g != null) {
                                try {
                                  await _gameService.updateActiveGame(
                                    g,
                                    GameManager.instance.currentTurnTeam,
                                    GameManager.instance.currentTurnStart,
                                    g.turns,
                                  );
                                } catch (_) {}
                              }
                            }
                            if (mounted) setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                GameManager.instance.isTurnRunning
                                    ? Colors.orange
                                    : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            GameManager.instance.isTurnRunning
                                ? 'Закончить ход'
                                : 'Начать ход',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Команды и состав',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTeamSection(context, game, 1),
                    const SizedBox(height: 12),
                    _buildTeamSection(context, game, 2),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _finishGame(context),
              icon: const Icon(Icons.flag),
              label: const Text('Завершить партию'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _finishGame(BuildContext context) async {
    int? selectedTeam = 1;

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Кто победил?'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(
                    title: const Text('Команда 1'),
                    value: 1,
                    groupValue: selectedTeam,
                    onChanged: (value) {
                      setState(() {
                        selectedTeam = value;
                      });
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('Команда 2'),
                    value: 2,
                    groupValue: selectedTeam,
                    onChanged: (value) {
                      setState(() {
                        selectedTeam = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: selectedTeam == null
                  ? null
                  : () => Navigator.of(context).pop(selectedTeam),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final game = GameManager.instance.activeGame;
      if (game != null) {
        try {
          await _gameService.finishGame(game.id, result);
        } catch (_) {}
      }
      GameManager.instance.finishGame(winningTeam: result);
      GameManager.instance.clearActiveGame();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  List<String> _teamPlayers(Game game, int teamNumber) {
    final ps = game.players;
    if (ps.isEmpty) return [];
    final half = ps.length ~/ 2;
    if (teamNumber == 1) {
      return ps.take(half).map((p) => p.userName).toList();
    }
    return ps.skip(half).map((p) => p.userName).toList();
  }

  Widget _buildTeamSection(BuildContext context, Game game, int teamNumber) {
    final half = game.players.length ~/ 2;
    final teamPlayers = game.players.asMap().entries.where(
          (e) => (teamNumber == 1 && e.key < half) || (teamNumber == 2 && e.key >= half),
        ).map((e) => e.value).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Команда $teamNumber',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: teamNumber == 1 ? Colors.blue[800] : Colors.green[800],
          ),
        ),
        const SizedBox(height: 6),
        ...teamPlayers.map(
          (p) => Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.userName,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Text(
                  p.deckName,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

