import 'dart:async';
import 'dart:math' show pi;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/core/format_utils.dart';
import 'package:mtg_stats/core/platform_utils.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/providers/active_game_provider.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/widgets/active_game/team_composition.dart';
import 'package:mtg_stats/widgets/active_game/zone_expanded_deck_image.dart';
import 'package:mtg_stats/services/game_manager.dart';

/// Активная партия: таймеры, ходы, завершение.
class ActiveGamePage extends ConsumerStatefulWidget {
  const ActiveGamePage({super.key});

  @override
  ConsumerState<ActiveGamePage> createState() => _ActiveGamePageState();
}

class _ActiveGamePageState extends ConsumerState<ActiveGamePage> {
  Timer? _timer;
  bool _isTickRunning = false;
  final AudioPlayer _turnAudioPlayer = AudioPlayer();
  bool _soundEnabled = false;
  String? _playingTrack; // 'turn' | 'overtime' | null
  /// На iOS Web переключение на музыку перерасхода без жеста блокируется.
  /// Показываем кнопку «Включить музыку перерасхода», по нажатию запускаем трек.
  bool _overtimeMusicPending = false;
  int _lastTotalSeconds = -1;
  int _lastDisplayTurnSeconds = -1;
  int _lastTeam1Seconds = -1;
  int _lastTeam2Seconds = -1;
  /// Режим отображения: false — классический, true — лицом к лицу (2 зоны).
  bool _useFaceToFaceView = false;
  /// Развёрнутое изображение колоды по длинному нажатию (в пределах зоны).
  Deck? _expandedDeck;
  int? _expandedDeckTeamNumber;
  /// Панель лимитов: false — справа, true — слева.
  bool _panelOnLeft = false;

  @override
  void initState() {
    super.initState();
    _turnAudioPlayer.setReleaseMode(ReleaseMode.loop);
    ref.read(activeGameControllerProvider.notifier).ensureDecksLoaded();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_isTickRunning) return;
      _isTickRunning = true;
      try {
      if (!mounted) return;
      final game = GameManager.instance.activeGame;
      if (game == null) return;
      if (GameManager.instance.isPaused) return;
      final teamLimit = GameManager.instance.teamTimeLimitSeconds;
      if (teamLimit > 0) {
        final t1 = _teamTotalTurnDuration(game, 1);
        final t2 = _teamTotalTurnDuration(game, 2);
        if (t1.inSeconds >= teamLimit) {
          await _finishGameTechnicalDefeat(context, 2);
          return;
        }
        if (t2.inSeconds >= teamLimit) {
          await _finishGameTechnicalDefeat(context, 1);
          return;
        }
      }
      final hasTurnLimit = GameManager.instance.turnLimitSeconds > 0;
      final turnElapsed = GameManager.instance.currentTurnElapsed;
      final limit = Duration(seconds: GameManager.instance.turnLimitSeconds);
      final overtime = hasTurnLimit && turnElapsed > limit ? turnElapsed - limit : Duration.zero;
      final displayTurn = hasTurnLimit
          ? (overtime > Duration.zero ? overtime : limit - turnElapsed)
          : turnElapsed;
      final totalSeconds = game.totalDuration.inSeconds;
      final displayTurnSeconds = displayTurn.inSeconds;
      final team1Seconds = _teamTotalTurnDuration(game, 1).inSeconds;
      final team2Seconds = _teamTotalTurnDuration(game, 2).inSeconds;
      if (totalSeconds != _lastTotalSeconds ||
          displayTurnSeconds != _lastDisplayTurnSeconds ||
          team1Seconds != _lastTeam1Seconds ||
          team2Seconds != _lastTeam2Seconds) {
        _lastTotalSeconds = totalSeconds;
        _lastDisplayTurnSeconds = displayTurnSeconds;
        _lastTeam1Seconds = team1Seconds;
        _lastTeam2Seconds = team2Seconds;
        setState(() {});
      }
      _syncTurnMusic();
      } finally {
        _isTickRunning = false;
      }
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

    if (!hasTurnLimit || !_soundEnabled || !isTurnRunning || GameManager.instance.isPaused) {
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

  void _showErrorSnackBar(ScaffoldMessengerState messenger, Object error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Ошибка: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showFinishHint(BuildContext context, {required bool compactText}) {
    final message = compactText
        ? 'Удерживайте для завершения партии'
        : 'Удерживайте кнопку для завершения партии';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _togglePauseWithFeedback(ScaffoldMessengerState messenger) async {
    try {
      await ref.read(activeGameControllerProvider.notifier).togglePause();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(messenger, e);
    }
  }

  Future<void> _toggleTurnWithFeedback(ScaffoldMessengerState messenger) async {
    try {
      await ref.read(activeGameControllerProvider.notifier).toggleTurn();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(messenger, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decksById = ref.watch(
      activeGameControllerProvider.select((state) => state.decksById),
    );

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
    final teamTotalTimeByNumber = <int, Duration>{
      1: _teamTotalTurnDuration(game, 1),
      2: _teamTotalTurnDuration(game, 2),
    };

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
          ? _buildFaceToFaceBody(
              context,
              game,
              decksById,
              teamTotalTimeByNumber,
            )
          : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            _TotalTimeCard(
              totalDuration: totalDuration,
              isPaused: GameManager.instance.isPaused,
              onTogglePause: () => _togglePauseWithFeedback(
                ScaffoldMessenger.of(context),
              ),
            ),
            if (hasTurnLimit) ...[
              const SizedBox(height: 16),
              _TurnControlCard(
                currentTeamName: currentTeamName,
                currentTurnTeam: GameManager.instance.currentTurnTeam,
                currentTurnTeamPlayers: currentTurnTeamPlayers,
                soundEnabled: _soundEnabled,
                onToggleSound: () {
                  setState(() => _soundEnabled = !_soundEnabled);
                  _syncTurnMusic();
                },
                displayTurn: displayTurn,
                isOvertime: isOvertime,
                limit: limit,
                overtimeMusicPending: _overtimeMusicPending,
                onPlayOvertimeMusicFromGesture: _playOvertimeMusicFromGesture,
                isPaused: GameManager.instance.isPaused,
                isTurnRunning: GameManager.instance.isTurnRunning,
                onToggleTurn: () => _toggleTurnWithFeedback(
                  ScaffoldMessenger.of(context),
                ),
                classicButtonPadding: classicButtonPadding,
                classicButtonFontSize: classicButtonFontSize,
              ),
            ],
            const SizedBox(height: 16),
            _TeamCompositionCard(
              team1Section: _buildTeamSection(
                context,
                game,
                1,
                teamTotalTimeByNumber[1]!,
              ),
              team2Section: _buildTeamSection(
                context,
                game,
                2,
                teamTotalTimeByNumber[2]!,
              ),
            ),
            const SizedBox(height: 24),
            _FinishGameActionButton(
              onLongPress: () => _finishGame(context),
              onTapHint: () => _showFinishHint(context, compactText: false),
            ),
          ],
          ),
        ),
    );
  }

  Future<void> _finishGameTechnicalDefeat(BuildContext context, int winningTeam) async {
    if (GameManager.instance.activeGame == null) return;
    final navigator = Navigator.of(context);
    await ref.read(activeGameControllerProvider.notifier).finishGame(
          winningTeam: winningTeam,
          isTechnicalDefeat: true,
        );
    if (mounted) {
      navigator.pop();
    }
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

  Widget _buildFaceToFaceBody(
    BuildContext context,
    Game game,
    Map<int, Deck> decksById,
    Map<int, Duration> teamTotalTimeByNumber,
  ) {
    const baseTeam1Color = Colors.blue;
    const baseTeam2Color = Colors.green;
    final team1Name = GameManager.instance.team1Name;
    final team2Name = GameManager.instance.team2Name;
    final team1TotalTime = teamTotalTimeByNumber[1] ?? Duration.zero;
    final team2TotalTime = teamTotalTimeByNumber[2] ?? Duration.zero;
    final teamLimit = GameManager.instance.teamTimeLimitSeconds;
    const warningThreshold = Duration(seconds: 30); // для теста; было 5 мин
    final isTeam1TimeWarning = teamLimit > 0 &&
        (Duration(seconds: teamLimit) - team1TotalTime) <= warningThreshold &&
        team1TotalTime < Duration(seconds: teamLimit);
    final isTeam2TimeWarning = teamLimit > 0 &&
        (Duration(seconds: teamLimit) - team2TotalTime) <= warningThreshold &&
        team2TotalTime < Duration(seconds: teamLimit);
    final team1Color = isTeam1TimeWarning ? Colors.red : baseTeam1Color;
    final team2Color = isTeam2TimeWarning ? Colors.red : baseTeam2Color;
    final totalDuration = game.totalDuration;
    final currentTeam = GameManager.instance.currentTurnTeam;
    final isTurnRunning = GameManager.instance.isTurnRunning;
    final isTeam1Active = currentTeam == 1;
    final isTeam2Active = currentTeam == 2;

    final panel = _buildFaceToFaceRightAppBar(
      context: context,
      team1TotalTime: team1TotalTime,
      team2TotalTime: team2TotalTime,
      totalDuration: totalDuration,
      team1Color: team1Color,
      team2Color: team2Color,
      panelOnLeft: _panelOnLeft,
    );
    return Row(
      children: [
        if (_panelOnLeft) panel,
        Expanded(
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: Transform.rotate(
                  angle: pi,
                  child: _FaceToFaceZone(
                    game: game,
                    teamNumber: 1,
                    teamName: team1Name,
                    color: team1Color,
                    isActive: isTeam1Active,
                    isTurnRunning: isTurnRunning,
                    isPaused: GameManager.instance.isPaused,
                    nameAtTop: true,
                    showComposition: true,
                    useDeckAvatars: true,
                    decksById: decksById,
                    expandedDeck: _expandedDeckTeamNumber == 1 ? _expandedDeck : null,
                    onDeckTap: (deck) {
                      setState(() {
                        _expandedDeck = deck;
                        _expandedDeckTeamNumber = 1;
                      });
                    },
                    onCloseExpandedDeck: () {
                      setState(() {
                        _expandedDeck = null;
                        _expandedDeckTeamNumber = null;
                      });
                    },
                    onToggleTurn: () => _toggleTurnWithFeedback(
                      ScaffoldMessenger.of(context),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: _FaceToFaceZone(
                  game: game,
                  teamNumber: 2,
                  teamName: team2Name,
                  color: team2Color,
                  isActive: isTeam2Active,
                  isTurnRunning: isTurnRunning,
                  isPaused: GameManager.instance.isPaused,
                  nameAtTop: true,
                  showComposition: true,
                  useDeckAvatars: true,
                  decksById: decksById,
                  expandedDeck: _expandedDeckTeamNumber == 2 ? _expandedDeck : null,
                  onDeckTap: (deck) {
                    setState(() {
                      _expandedDeck = deck;
                      _expandedDeckTeamNumber = 2;
                    });
                  },
                  onCloseExpandedDeck: () {
                    setState(() {
                      _expandedDeck = null;
                      _expandedDeckTeamNumber = null;
                    });
                  },
                  onToggleTurn: () => _toggleTurnWithFeedback(
                    ScaffoldMessenger.of(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_panelOnLeft) panel,
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
    required bool panelOnLeft,
  }) {
    return _FaceToFaceSidePanel(
      team1TotalTime: team1TotalTime,
      team2TotalTime: team2TotalTime,
      totalDuration: totalDuration,
      team1Color: team1Color,
      team2Color: team2Color,
      panelOnLeft: panelOnLeft,
      soundEnabled: _soundEnabled,
      isPaused: GameManager.instance.isPaused,
      onTogglePanelSide: () {
        setState(() => _panelOnLeft = !_panelOnLeft);
      },
      onSwitchToClassicView: () {
        setState(() => _useFaceToFaceView = false);
      },
      onToggleSound: () {
        setState(() => _soundEnabled = !_soundEnabled);
        _syncTurnMusic();
      },
      onTogglePause: () async {
        await _togglePauseWithFeedback(ScaffoldMessenger.of(context));
      },
      onFinishLongPress: () => _finishGame(context),
      onFinishTapHint: () => _showFinishHint(context, compactText: true),
    );
  }

  Future<void> _finishGame(BuildContext context) async {
    final navigator = Navigator.of(context);
    final team1Name = GameManager.instance.team1Name;
    final team2Name = GameManager.instance.team2Name;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => _WinningTeamDialog(
        team1Name: team1Name,
        team2Name: team2Name,
      ),
    );

    if (result != null) {
      await ref.read(activeGameControllerProvider.notifier).finishGame(
            winningTeam: result,
          );
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

  Widget _buildTeamSection(
    BuildContext context,
    Game game,
    int teamNumber,
    Duration teamTotalTime,
  ) {
    final half = game.players.length ~/ 2;
    final teamPlayers = game.players.asMap().entries.where(
          (e) => (teamNumber == 1 && e.key < half) || (teamNumber == 2 && e.key >= half),
        ).map((e) => e.value).toList();
    final teamName = teamNumber == 1
        ? GameManager.instance.team1Name
        : GameManager.instance.team2Name;
    final teamLimit = GameManager.instance.teamTimeLimitSeconds;
    final isTimeWarning = teamLimit > 0 &&
        (Duration(seconds: teamLimit) - teamTotalTime) <= const Duration(seconds: 30) && // для теста; было 5 мин
        teamTotalTime < Duration(seconds: teamLimit);
    final teamColor = isTimeWarning ? Colors.red : (teamNumber == 1 ? Colors.blue : Colors.green);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                teamName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: teamColor[800],
                ),
              ),
            ),
            if (teamLimit > 0)
              Text(
                '${FormatUtils.formatDuration(teamTotalTime)} / ${FormatUtils.formatDuration(Duration(seconds: teamLimit))}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isTimeWarning ? Colors.red[700] : Colors.grey[700],
                ),
              ),
          ],
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

class _TotalTimeCard extends StatelessWidget {
  const _TotalTimeCard({
    required this.totalDuration,
    required this.isPaused,
    required this.onTogglePause,
  });

  final Duration totalDuration;
  final bool isPaused;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Общее время игры',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onTogglePause,
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(isPaused ? 'Продолжить' : 'Пауза'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaused ? Colors.green : Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (isPaused)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'ПАУЗА',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
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
    );
  }
}

class _TurnControlCard extends StatelessWidget {
  const _TurnControlCard({
    required this.currentTeamName,
    required this.currentTurnTeam,
    required this.currentTurnTeamPlayers,
    required this.soundEnabled,
    required this.onToggleSound,
    required this.displayTurn,
    required this.isOvertime,
    required this.limit,
    required this.overtimeMusicPending,
    required this.onPlayOvertimeMusicFromGesture,
    required this.isPaused,
    required this.isTurnRunning,
    required this.onToggleTurn,
    required this.classicButtonPadding,
    required this.classicButtonFontSize,
  });

  final String currentTeamName;
  final int currentTurnTeam;
  final List<String> currentTurnTeamPlayers;
  final bool soundEnabled;
  final VoidCallback onToggleSound;
  final Duration displayTurn;
  final bool isOvertime;
  final Duration limit;
  final bool overtimeMusicPending;
  final VoidCallback onPlayOvertimeMusicFromGesture;
  final bool isPaused;
  final bool isTurnRunning;
  final VoidCallback onToggleTurn;
  final EdgeInsetsGeometry classicButtonPadding;
  final double classicButtonFontSize;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                            color: currentTurnTeam == 1
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
                    soundEnabled ? Icons.volume_up : Icons.volume_off,
                    color: soundEnabled ? null : Colors.grey,
                  ),
                  tooltip: soundEnabled
                      ? 'Выключить музыку'
                      : 'Включить музыку хода',
                  onPressed: onToggleSound,
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
            if (overtimeMusicPending) ...[
              const SizedBox(height: 10),
              Center(
                child: OutlinedButton.icon(
                  onPressed: onPlayOvertimeMusicFromGesture,
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
                onPressed: isPaused ? null : onToggleTurn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTurnRunning ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  padding: classicButtonPadding,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isTurnRunning ? 'Закончить ход' : 'Начать ход',
                  style: TextStyle(fontSize: classicButtonFontSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishGameActionButton extends StatelessWidget {
  const _FinishGameActionButton({
    required this.onLongPress,
    required this.onTapHint,
  });

  final VoidCallback onLongPress;
  final VoidCallback onTapHint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTapHint,
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
    );
  }
}

class _WinningTeamDialog extends StatefulWidget {
  const _WinningTeamDialog({
    required this.team1Name,
    required this.team2Name,
  });

  final String team1Name;
  final String team2Name;

  @override
  State<_WinningTeamDialog> createState() => _WinningTeamDialogState();
}

class _WinningTeamDialogState extends State<_WinningTeamDialog> {
  int? _selectedTeam = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Кто победил?'),
      content: RadioGroup<int>(
        groupValue: _selectedTeam,
        onChanged: (value) {
          setState(() => _selectedTeam = value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(title: Text(widget.team1Name), value: 1),
            RadioListTile<int>(title: Text(widget.team2Name), value: 2),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _selectedTeam == null
              ? null
              : () => Navigator.of(context).pop(_selectedTeam),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _TeamCompositionCard extends StatelessWidget {
  const _TeamCompositionCard({
    required this.team1Section,
    required this.team2Section,
  });

  final Widget team1Section;
  final Widget team2Section;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            team1Section,
            const SizedBox(height: 12),
            team2Section,
          ],
        ),
      ),
    );
  }
}

class _FaceToFaceSidePanel extends StatelessWidget {
  const _FaceToFaceSidePanel({
    required this.team1TotalTime,
    required this.team2TotalTime,
    required this.totalDuration,
    required this.team1Color,
    required this.team2Color,
    required this.panelOnLeft,
    required this.soundEnabled,
    required this.isPaused,
    required this.onTogglePanelSide,
    required this.onSwitchToClassicView,
    required this.onToggleSound,
    required this.onTogglePause,
    required this.onFinishLongPress,
    required this.onFinishTapHint,
  });

  final Duration team1TotalTime;
  final Duration team2TotalTime;
  final Duration totalDuration;
  final MaterialColor team1Color;
  final MaterialColor team2Color;
  final bool panelOnLeft;
  final bool soundEnabled;
  final bool isPaused;
  final VoidCallback onTogglePanelSide;
  final VoidCallback onSwitchToClassicView;
  final VoidCallback onToggleSound;
  final Future<void> Function() onTogglePause;
  final VoidCallback onFinishLongPress;
  final VoidCallback onFinishTapHint;

  @override
  Widget build(BuildContext context) {
    final timerAngle = pi / 2 + (panelOnLeft ? pi : 0);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = (screenWidth * 0.12).clamp(50.0, 80.0);

    final blueTimer = FittedBox(
      fit: BoxFit.scaleDown,
      child: Transform.rotate(
        angle: timerAngle,
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

    final totalTimerText = FittedBox(
      fit: BoxFit.none,
      child: Transform.rotate(
        angle: timerAngle,
        child: Text(
          FormatUtils.formatDuration(totalDuration),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          softWrap: false,
        ),
      ),
    );

    final greenTimer = FittedBox(
      fit: BoxFit.scaleDown,
      child: Transform.rotate(
        angle: timerAngle,
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

    return Container(
      width: panelWidth,
      color: AppTheme.appBarBackground,
      child: SafeArea(
        left: false,
        top: false,
        bottom: true,
        child: Column(
          children: [
            const SizedBox(height: 100),
            Expanded(
              child: Center(child: blueTimer),
            ),
            Center(
              child: SizedBox(
                width: panelWidth,
                height: 120,
                child: totalTimerText,
              ),
            ),
            Expanded(
              child: Center(child: greenTimer),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: panelOnLeft ? 'Панель справа' : 'Панель слева',
                    child: IconButton(
                      icon: Icon(
                        panelOnLeft ? Icons.arrow_forward : Icons.arrow_back,
                        color: AppTheme.appBarForeground,
                        size: 22,
                      ),
                      onPressed: onTogglePanelSide,
                    ),
                  ),
                  Tooltip(
                    message: 'Стандартный режим',
                    child: IconButton(
                      icon: const Icon(
                        Icons.flip_to_front,
                        color: AppTheme.appBarForeground,
                        size: 22,
                      ),
                      onPressed: onSwitchToClassicView,
                    ),
                  ),
                  Tooltip(
                    message: soundEnabled ? 'Выключить музыку' : 'Включить музыку хода',
                    child: IconButton(
                      icon: Icon(
                        soundEnabled ? Icons.volume_up : Icons.volume_off,
                        color: soundEnabled ? AppTheme.appBarForeground : Colors.grey,
                        size: 22,
                      ),
                      onPressed: onToggleSound,
                    ),
                  ),
                  Tooltip(
                    message: isPaused ? 'Продолжить' : 'Пауза',
                    child: IconButton(
                      icon: Icon(
                        isPaused ? Icons.play_arrow : Icons.pause,
                        color: AppTheme.appBarForeground,
                        size: 22,
                      ),
                      onPressed: () async {
                        await onTogglePause();
                      },
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onLongPress: onFinishLongPress,
                      onTap: onFinishTapHint,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red[700]!.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.flag, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceToFaceZone extends StatelessWidget {
  const _FaceToFaceZone({
    required this.game,
    required this.teamNumber,
    required this.teamName,
    required this.color,
    required this.isActive,
    required this.isTurnRunning,
    required this.isPaused,
    required this.nameAtTop,
    required this.showComposition,
    required this.useDeckAvatars,
    required this.decksById,
    required this.expandedDeck,
    required this.onDeckTap,
    required this.onCloseExpandedDeck,
    required this.onToggleTurn,
  });

  final Game game;
  final int teamNumber;
  final String teamName;
  final MaterialColor color;
  final bool isActive;
  final bool isTurnRunning;
  final bool isPaused;
  final bool nameAtTop;
  final bool showComposition;
  final bool useDeckAvatars;
  final Map<int, Deck> decksById;
  final Deck? expandedDeck;
  final ValueChanged<Deck> onDeckTap;
  final VoidCallback onCloseExpandedDeck;
  final VoidCallback onToggleTurn;

  @override
  Widget build(BuildContext context) {
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
      onPressed: isActive && !isPaused ? onToggleTurn : null,
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
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, zoneConstraints) {
                final compositionWithZoneHeight = showComposition && useDeckAvatars
                    ? Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            TeamComposition(
                              teamPlayers: teamPlayers,
                              color: color,
                              decksById: decksById,
                              onDeckTap: onDeckTap,
                            ),
                            if (timerWidget != null) ...[
                              const SizedBox(height: 8),
                              timerWidget,
                            ],
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: isActive
                                  ? buttonWidget
                                  : Opacity(
                                      opacity: 0.5,
                                      child: buttonWidget,
                                    ),
                            ),
                          ],
                        ),
                      )
                    : compositionWidget;

                return Column(
                  mainAxisAlignment: nameAtTop
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
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
                            isActive
                                ? buttonWidget
                                : Opacity(
                                    opacity: 0.5,
                                    child: buttonWidget,
                                  ),
                          ],
                        ]
                      : [
                          isActive
                              ? buttonWidget
                              : Opacity(
                                  opacity: 0.5,
                                  child: buttonWidget,
                                ),
                          const SizedBox(height: 16),
                          nameWidget,
                          compositionWidget,
                        ],
                );
              },
            ),
            if (expandedDeck != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTap: onCloseExpandedDeck,
                      child: Container(
                        color: Colors.black87,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ZoneExpandedDeckImage(
                              deck: expandedDeck!,
                              maxWidth: constraints.maxWidth,
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
                                onPressed: onCloseExpandedDeck,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<GamePlayer> _teamPlayersWithDecks(Game game, int teamNumber) {
  final half = game.players.length ~/ 2;
  return game.players.asMap().entries
      .where((e) =>
          (teamNumber == 1 && e.key < half) || (teamNumber == 2 && e.key >= half))
      .map((e) => e.value)
      .toList();
}

