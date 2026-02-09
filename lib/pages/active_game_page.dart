import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/core/platform_utils.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/services/game_manager.dart';
import 'package:mtg_stats/services/game_service.dart';

/// Активная партия: таймеры, ходы, завершение.
class ActiveGamePage extends StatefulWidget {
  const ActiveGamePage({super.key});

  @override
  State<ActiveGamePage> createState() => _ActiveGamePageState();
}

class _ActiveGamePageState extends State<ActiveGamePage> {
  Timer? _timer;
  final GameService _gameService = GameService();
  final AudioPlayer _turnAudioPlayer = AudioPlayer();
  bool _soundEnabled = false;
  String? _playingTrack; // 'turn' | 'overtime' | null
  /// На iOS Web переключение на музыку перерасхода без жеста блокируется.
  /// Показываем кнопку «Включить музыку перерасхода», по нажатию запускаем трек.
  bool _overtimeMusicPending = false;
  int _lastTotalSeconds = -1;
  int _lastDisplayTurnSeconds = -1;

  @override
  void initState() {
    super.initState();
    _turnAudioPlayer.setReleaseMode(ReleaseMode.loop);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final game = GameManager.instance.activeGame;
      if (game == null) return;
      final hasTurnLimit = GameManager.instance.turnLimitSeconds > 0;
      final turnElapsed = GameManager.instance.currentTurnElapsed;
      final limit = Duration(seconds: GameManager.instance.turnLimitSeconds);
      final overtime = hasTurnLimit && turnElapsed > limit ? turnElapsed - limit : Duration.zero;
      final displayTurn = hasTurnLimit
          ? (overtime > Duration.zero ? overtime : limit - turnElapsed)
          : turnElapsed;
      final totalSeconds = game.totalDuration.inSeconds;
      final displayTurnSeconds = displayTurn.inSeconds;
      if (totalSeconds != _lastTotalSeconds || displayTurnSeconds != _lastDisplayTurnSeconds) {
        _lastTotalSeconds = totalSeconds;
        _lastDisplayTurnSeconds = displayTurnSeconds;
        setState(() {});
      }
      _syncTurnMusic();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _turnAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _syncTurnMusic() async {
    if (!mounted) return;
    final hasTurnLimit = GameManager.instance.turnLimitSeconds > 0;
    final isTurnRunning = GameManager.instance.isTurnRunning;
    final turnElapsed = GameManager.instance.currentTurnElapsed;
    final limit = Duration(seconds: GameManager.instance.turnLimitSeconds);
    final overtime = hasTurnLimit && turnElapsed > limit ? turnElapsed - limit : Duration.zero;

    if (!hasTurnLimit || !_soundEnabled || !isTurnRunning) {
      if (_playingTrack != null) {
        await _turnAudioPlayer.stop();
        if (mounted) {
          setState(() {
            _playingTrack = null;
            _overtimeMusicPending = false;
          });
        }
      }
      return;
    }

    final wantedTrack = overtime > Duration.zero ? 'overtime' : 'turn';
    if (_playingTrack == wantedTrack) {
      if (wantedTrack == 'turn') {
        _overtimeMusicPending = false;
      }
      return;
    }

    if (wantedTrack == 'overtime' && isIOSWeb) {
      if (!_overtimeMusicPending && mounted) {
        setState(() => _overtimeMusicPending = true);
      }
      return;
    }

    await _turnAudioPlayer.stop();
    final source = wantedTrack == 'overtime'
        ? AssetSource(AppConstants.overtimeMusicAsset)
        : AssetSource(AppConstants.turnMusicAsset);
    try {
      await _turnAudioPlayer.play(source);
      if (mounted) {
        setState(() {
          _playingTrack = wantedTrack;
          _overtimeMusicPending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _playingTrack = null);
      }
    }
  }

  Future<void> _playOvertimeMusicFromGesture() async {
    await _turnAudioPlayer.stop();
    try {
      await _turnAudioPlayer.play(AssetSource(AppConstants.overtimeMusicAsset));
      if (mounted) {
        setState(() {
          _playingTrack = 'overtime';
          _overtimeMusicPending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _playingTrack = null);
      }
    }
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
    final isOvertime = overtime > Duration.zero;
    // Для отображения таймера хода:
    // - пока нет перерасхода: считаем от лимита вниз до 0;
    // - при перерасходе: считаем от 00:00 вверх.
    final displayTurn = hasTurnLimit
        ? (isOvertime ? overtime : limit - turnElapsed)
        : turnElapsed;
    final currentTurnTeamPlayers = _teamPlayers(game, GameManager.instance.currentTurnTeam);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Активная партия', style: AppTheme.appBarTitle),
          backgroundColor: AppTheme.appBarBackground,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ход команды ${GameManager.instance.currentTurnTeam}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _soundEnabled ? Icons.volume_up : Icons.volume_off,
                              color: _soundEnabled ? null : Colors.grey,
                            ),
                            tooltip: _soundEnabled ? 'Выключить музыку' : 'Включить музыку хода',
                            onPressed: () {
                              setState(() => _soundEnabled = !_soundEnabled);
                              _syncTurnMusic();
                            },
                          ),
                        ],
                      ),
                      if (currentTurnTeamPlayers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            currentTurnTeamPlayers.join(', '),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _formatDuration(displayTurn),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isOvertime ? Colors.red : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Лимит хода: ${_formatDuration(limit)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      if (_overtimeMusicPending) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: _playOvertimeMusicFromGesture,
                            icon: const Icon(Icons.music_note, size: 20),
                            label: const Text('Включить музыку перерасхода'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red[700],
                              side: BorderSide(color: Colors.red[700]!),
                            ),
                          ),
                        ),
                      ],
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
            const SizedBox(height: 24),
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
    final navigator = Navigator.of(context);

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Кто победил?'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return RadioGroup<int>(
                groupValue: selectedTeam,
                onChanged: (value) {
                  setState(() {
                    selectedTeam = value;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<int>(title: const Text('Команда 1'), value: 1),
                    RadioListTile<int>(title: const Text('Команда 2'), value: 2),
                  ],
                ),
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
        navigator.pop();
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

