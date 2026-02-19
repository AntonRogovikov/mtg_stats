import 'dart:async';
import 'dart:math' show pi;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/core/format_utils.dart';
import 'package:mtg_stats/core/platform_utils.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/services/deck_image/deck_image_provider.dart';
import 'package:mtg_stats/services/deck_service.dart';
import 'package:mtg_stats/widgets/deck_card.dart';
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
  final DeckService _deckService = DeckService();
  Map<int, Deck> _decksById = {};
  final AudioPlayer _turnAudioPlayer = AudioPlayer();
  bool _soundEnabled = false;
  String? _playingTrack; // 'turn' | 'overtime' | null
  /// На iOS Web переключение на музыку перерасхода без жеста блокируется.
  /// Показываем кнопку «Включить музыку перерасхода», по нажатию запускаем трек.
  bool _overtimeMusicPending = false;
  int _lastTotalSeconds = -1;
  int _lastDisplayTurnSeconds = -1;
  /// Режим отображения: false — классический, true — лицом к лицу (2 зоны).
  bool _useFaceToFaceView = false;
  /// Развёрнутое изображение колоды по длинному нажатию (в пределах зоны).
  Deck? _expandedDeck;
  int? _expandedDeckTeamNumber;
  /// Для каждой зоны: поменяны ли местами игроки (имена и колоды).
  final Map<int, bool> _zonePlayersSwapped = {};

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
      if (_decksById.isEmpty) _loadDecks();
      _syncTurnMusic();
    });
  }

  Future<void> _loadDecks() async {
    try {
      final decks = await _deckService.getAllDecks();
      if (mounted) {
        setState(() {
          _decksById = {for (final d in decks) d.id: d};
        });
      }
    } catch (_) {}
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
    if (!ApiConfig.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Активная партия', style: AppTheme.appBarTitle),
          backgroundColor: AppTheme.appBarBackground,
          foregroundColor: AppTheme.appBarForeground,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.admin_panel_settings, size: 64, color: Colors.orange[400]),
                const SizedBox(height: 16),
                Text(
                  'Требуются права администратора',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Вести активную партию могут только администраторы.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

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

    final currentTeamName = GameManager.instance.currentTurnTeam == 1
        ? GameManager.instance.team1Name
        : GameManager.instance.team2Name;

    final screenSize = MediaQuery.sizeOf(context);
    final buttonScale = (screenSize.shortestSide / 400).clamp(0.7, 1.5);
    final classicButtonPadding = EdgeInsets.symmetric(
      horizontal: (24 * buttonScale).roundToDouble(),
      vertical: (16 * buttonScale).roundToDouble(),
    );
    final classicButtonFontSize = (16 * buttonScale).clamp(14.0, 22.0);

    return Scaffold(
      appBar: _useFaceToFaceView
          ? null
          : AppBar(
              title: Text('Активная партия', style: AppTheme.appBarTitle),
              backgroundColor: AppTheme.appBarBackground,
              automaticallyImplyLeading: true,
              actions: [
                Tooltip(
                  message: _useFaceToFaceView ? 'Классический вид' : 'Вид лицом к лицу',
                  child: IconButton(
                    icon: Icon(
                      _useFaceToFaceView ? Icons.view_agenda : Icons.view_module,
                    ),
                    onPressed: () {
                      setState(() => _useFaceToFaceView = !_useFaceToFaceView);
                    },
                  ),
                ),
              ],
            ),
      body: _useFaceToFaceView
          ? _buildFaceToFaceBody(context, game)
          : SingleChildScrollView(
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
                        FormatUtils.formatDuration(totalDuration),
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
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                children: [
                                  const TextSpan(text: 'Ход: '),
                                  TextSpan(
                                    text: currentTeamName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: GameManager.instance.currentTurnTeam == 1
                                          ? Colors.blue[800]
                                          : Colors.green[800],
                                    ),
                                  ),
                                ],
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
                          FormatUtils.formatDuration(displayTurn),
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
                            'Лимит хода: ${FormatUtils.formatDuration(limit)}',
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
                              // Автоматически начинаем ход у команды противника.
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
                            padding: classicButtonPadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            GameManager.instance.isTurnRunning
                                ? 'Закончить ход'
                                : 'Начать ход',
                            style: TextStyle(fontSize: classicButtonFontSize),
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
            GestureDetector(
              onLongPress: () => _finishGame(context),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Удерживайте кнопку для завершения партии'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: AbsorbPointer(
                child: ElevatedButton.icon(
                  onPressed: () {},
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
              ),
            ),
          ],
          ),
        ),
    );
  }

  /// Общее время хода команды (включая текущий ход, если он у неё).
  Duration _teamTotalTurnDuration(Game game, int teamNumber) {
    final turns = game.turns;
    var total = Duration.zero;
    for (final t in turns) {
      if (t.teamNumber == teamNumber) {
        total += t.duration;
      }
    }
    if (GameManager.instance.isTurnRunning &&
        GameManager.instance.currentTurnTeam == teamNumber) {
      total += GameManager.instance.currentTurnElapsed;
    }
    return total;
  }

  Widget _buildFaceToFaceBody(BuildContext context, Game game) {
    final team1Color = Colors.blue;
    final team2Color = Colors.green;
    final team1Name = GameManager.instance.team1Name;
    final team2Name = GameManager.instance.team2Name;
    final team1TotalTime = _teamTotalTurnDuration(game, 1);
    final team2TotalTime = _teamTotalTurnDuration(game, 2);
    final totalDuration = game.totalDuration;
    final currentTeam = GameManager.instance.currentTurnTeam;
    final isTurnRunning = GameManager.instance.isTurnRunning;
    final isTeam1Active = currentTeam == 1;
    final isTeam2Active = currentTeam == 2;

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: Transform.rotate(
                  angle: pi,
                  child: _buildFaceToFaceZone(
                    game: game,
                    teamNumber: 1,
                    teamName: team1Name,
                    color: team1Color,
                    isActive: isTeam1Active,
                    isTurnRunning: isTurnRunning,
                    nameAtTop: true,
                    showComposition: true,
                    useDeckAvatars: true,
                    decksById: _decksById,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildFaceToFaceZone(
                  game: game,
                  teamNumber: 2,
                  teamName: team2Name,
                  color: team2Color,
                  isActive: isTeam2Active,
                  isTurnRunning: isTurnRunning,
                  nameAtTop: true,
                  showComposition: true,
                  useDeckAvatars: true,
                  decksById: _decksById,
                ),
              ),
            ],
          ),
        ),
        _buildFaceToFaceRightAppBar(
          context: context,
          team1TotalTime: team1TotalTime,
          team2TotalTime: team2TotalTime,
          totalDuration: totalDuration,
          team1Color: team1Color,
          team2Color: team2Color,
        ),
      ],
    );
  }

  Widget _buildFaceToFaceRightAppBar({
    required BuildContext context,
    required Duration team1TotalTime,
    required Duration team2TotalTime,
    required Duration totalDuration,
    required MaterialColor team1Color,
    required MaterialColor team2Color,
  }) {
    final blueTimer = FittedBox(
      fit: BoxFit.scaleDown,
      child: Transform.rotate(
        angle: pi / 2,
        child: Text(
          FormatUtils.formatDuration(team1TotalTime),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: team1Color[300],
          ),
          softWrap: false,
        ),
      ),
    );
    final totalTimer = LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.none,
          child: Transform.rotate(
            angle: pi / 2,
            child: Text(
              FormatUtils.formatDuration(totalDuration),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              softWrap: false,
            ),
          ),
        );
      },
    );
    final greenTimer = FittedBox(
      fit: BoxFit.scaleDown,
      child: Transform.rotate(
        angle: pi / 2,
        child: Text(
          FormatUtils.formatDuration(team2TotalTime),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: team2Color[300],
          ),
          softWrap: false,
        ),
      ),
    );
    final buttons = 
       Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: 'Стандартный режим',
            child: IconButton(
              icon: Icon(
                Icons.view_agenda,
                color: AppTheme.appBarForeground,
                size: 22,
              ),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
              onPressed: () {
                setState(() => _useFaceToFaceView = false);
              },
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onLongPress: () => _finishGame(context),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Удерживайте для завершения партии'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[700]!.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.flag, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = (screenWidth * 0.12).clamp(50.0, 80.0);

    return Container(
      width: panelWidth,
      color: AppTheme.appBarBackground,
      child: SafeArea(
        left: false,
        top: false,
        bottom: true,
        child: Column(
          children: [
            SizedBox(height: 100),
            Expanded(
              flex: 1,
              child: Center(child: blueTimer),
            ),
            Center(
              child: SizedBox(
                width: panelWidth,
                height: 120,
                child: totalTimer,
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(child: greenTimer),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: buttons,
            ),
          ],
        ),
      ),
    );
  }

  List<GamePlayer> _teamPlayersWithDecks(Game game, int teamNumber) {
    final half = game.players.length ~/ 2;
    return game.players.asMap().entries
        .where((e) =>
            (teamNumber == 1 && e.key < half) ||
            (teamNumber == 2 && e.key >= half))
        .map((e) => e.value)
        .toList();
  }

  Widget _buildFaceToFaceZone({
    required Game game,
    required int teamNumber,
    required String teamName,
    required MaterialColor color,
    required bool isActive,
    required bool isTurnRunning,
    required bool nameAtTop,
    required bool showComposition,
    bool useDeckAvatars = false,
    Map<int, Deck> decksById = const {},
  }) {
    final nameWidget = Text(
      teamName,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color[800],
      ),
      textAlign: TextAlign.center,
    );
    final screenSize = MediaQuery.sizeOf(context);
    final scale = (screenSize.shortestSide / 400).clamp(0.7, 1.5);
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: (24 * scale).roundToDouble(),
      vertical: (16 * scale).roundToDouble(),
    );
    final buttonFontSize = (16 * scale).clamp(14.0, 22.0);

    final buttonWidget = ElevatedButton(
      onPressed: isActive
          ? () async {
              if (isTurnRunning) {
                GameManager.instance.endTurn();
                GameManager.instance.startTurn();
              } else {
                GameManager.instance.startTurn();
              }
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
              if (mounted) setState(() {});
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isTurnRunning ? Colors.orange : Colors.green,
        foregroundColor: Colors.white,
        padding: buttonPadding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        isActive
            ? (isTurnRunning ? 'Закончить ход' : 'Начать ход')
            : 'Ход соперника',
        style: TextStyle(fontSize: buttonFontSize),
        textAlign: TextAlign.center,
      ),
    );

    final hasTurnLimit = game.turnLimitSeconds > 0;
    final turnElapsed = GameManager.instance.currentTurnElapsed;
    final limit = Duration(seconds: game.turnLimitSeconds);
    final overtime =
        hasTurnLimit && turnElapsed > limit ? turnElapsed - limit : Duration.zero;
    final isOvertime = overtime > Duration.zero;
    final displayTurn = hasTurnLimit
        ? (isOvertime ? overtime : limit - turnElapsed)
        : turnElapsed;

    final timerWidget = hasTurnLimit
        ? Center(
            child: Text(
              FormatUtils.formatDuration(displayTurn),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: isOvertime ? Colors.red : Colors.black,
              ),
            ),
          )
        : null;

    final teamPlayers = _teamPlayersWithDecks(game, teamNumber);
    final displayTeamPlayers = (_zonePlayersSwapped[teamNumber] ?? false) && teamPlayers.length == 2
        ? [teamPlayers[1], teamPlayers[0]]
        : teamPlayers;
    final compositionWidget = showComposition
        ? (useDeckAvatars
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  ...teamPlayers.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${p.userName}: ${p.deckName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: color[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ))
        : const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        border: Border(
          bottom: teamNumber == 1
              ? BorderSide(color: color.withValues(alpha: 0.5), width: 2)
              : BorderSide.none,
          top: teamNumber == 2
              ? BorderSide(color: color.withValues(alpha: 0.5), width: 2)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, zoneConstraints) {
            final compositionWithZoneHeight = showComposition && useDeckAvatars
                ? Expanded(
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            _GreenTeamComposition(
                              teamPlayers: displayTeamPlayers,
                              color: color,
                              decksById: decksById,
                              maxAvatarHeight: (zoneConstraints.maxHeight * 0.45).clamp(80.0, 375.0),
                              onDeckLongPress: (deck) {
                                setState(() {
                                  _expandedDeck = deck;
                                  _expandedDeckTeamNumber = teamNumber;
                                });
                              },
                              onSwap: teamPlayers.length == 2
                                  ? () {
                                      setState(() {
                                        _zonePlayersSwapped[teamNumber] =
                                            !(_zonePlayersSwapped[teamNumber] ?? false);
                                      });
                                    }
                                  : null,
                            ),
                            if (timerWidget != null) ...[
                              const SizedBox(height: 8),
                              timerWidget,
                            ],
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: buttonWidget,
                            ),
                          ],
                        ),
                        if (_expandedDeck != null &&
                            _expandedDeckTeamNumber == teamNumber)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _expandedDeck = null;
                                  _expandedDeckTeamNumber = null;
                                });
                              },
                              child: Container(
                                color: Colors.black87,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _ZoneExpandedDeckImage(
                                      deck: _expandedDeck!,
                                      maxWidth: zoneConstraints.maxWidth,
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _expandedDeck = null;
                                            _expandedDeckTeamNumber = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : compositionWidget;
            return Column(
              mainAxisAlignment: nameAtTop ? MainAxisAlignment.start : MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: nameAtTop
                  ? [
                      nameWidget,
                      compositionWithZoneHeight,
                      if (!useDeckAvatars) ...[
                        const Spacer(),
                        if (timerWidget != null) ...[
                          timerWidget,
                          const SizedBox(height: 8),
                        ],
                        buttonWidget,
                      ],
                    ]
                  : [
                      buttonWidget,
                      const SizedBox(height: 16),
                      nameWidget,
                      compositionWidget,
                    ],
            );
          },
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
              final team1Name = GameManager.instance.team1Name;
              final team2Name = GameManager.instance.team2Name;
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
                    RadioListTile<int>(title: Text(team1Name), value: 1),
                    RadioListTile<int>(title: Text(team2Name), value: 2),
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
    final teamName = teamNumber == 1
        ? GameManager.instance.team1Name
        : GameManager.instance.team2Name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
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

/// Развёрнутое изображение колоды на всю ширину зоны.
class _ZoneExpandedDeckImage extends StatelessWidget {
  final Deck deck;
  final double maxWidth;

  const _ZoneExpandedDeckImage({
    required this.deck,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final pathOrUrl = deck.imageUrl ?? deck.avatarUrl;
    final provider = deckImageProvider(
      pathOrUrl?.isNotEmpty == true ? pathOrUrl : null,
    );
    final useAsset = provider == null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: useAsset
          ? Image.asset(
              AppConstants.defaultDeckImageAsset,
              fit: BoxFit.contain,
            )
          : Image(
              image: provider,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, __, ___) => Image.asset(
                AppConstants.defaultDeckImageAsset,
                fit: BoxFit.contain,
              ),
            ),
    );
  }
}

/// Состав зелёной команды: имена в строке, карточки колод как в списке колод.
class _GreenTeamComposition extends StatelessWidget {
  final List<GamePlayer> teamPlayers;
  final MaterialColor color;
  final Map<int, Deck> decksById;
  final double maxAvatarHeight;
  final void Function(Deck deck)? onDeckLongPress;
  final VoidCallback? onSwap;

  const _GreenTeamComposition({
    required this.teamPlayers,
    required this.color,
    required this.decksById,
    this.maxAvatarHeight = 200,
    this.onDeckLongPress,
    this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final playerWidgets = teamPlayers.map((p) {
      final deck = decksById[p.deckId];
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.userName,
                style: TextStyle(
                  fontSize: 14,
                  color: color[800],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 230,
                  maxHeight: maxAvatarHeight,
                ),
                child: AspectRatio(
                  aspectRatio: 0.63,
                  child: deck != null
                      ? DeckCard(
                          deck: deck,
                          isSelected: false,
                          onTap: () {},
                          onLongPress: () {
                            onDeckLongPress?.call(deck);
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              p.deckName,
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    final swapButton = onSwap != null
        ? Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: IconButton(
              onPressed: onSwap,
              icon: Icon(Icons.swap_horiz, color: color[700], size: 28),
              tooltip: 'Поменять местами',
              style: IconButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.2),
                padding: const EdgeInsets.all(8),
              ),
            ),
          )
        : null;

    final rowChildren = <Widget>[
      playerWidgets[0],
      if (swapButton != null) ...[swapButton, playerWidgets[1]],
      if (swapButton == null) ...playerWidgets.sublist(1),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        ),
      ],
    );
  }
}


