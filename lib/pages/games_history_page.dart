import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/format_utils.dart';
import 'package:mtg_stats/core/timezone_utils.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/pages/deck_card_page.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/services/deck_service.dart';
import 'package:mtg_stats/widgets/common/async_state_views.dart';

/// Страница истории партий: список завершённых игр.
class GamesHistoryPage extends ConsumerStatefulWidget {
  const GamesHistoryPage({super.key});

  @override
  ConsumerState<GamesHistoryPage> createState() => _GamesHistoryPageState();
}

class _GamesHistoryPageState extends ConsumerState<GamesHistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Game> _filteredGames(
    List<Game> games,
    int timezoneOffsetMinutes,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return games;
    return games.where((g) {
      final team1 = (g.team1Name ?? 'Команда 1').toLowerCase();
      final team2 = (g.team2Name ?? 'Команда 2').toLowerCase();
      final dateStr = _formatDate(
        g.startTime,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
      ).toLowerCase();
      if (g.id.toLowerCase().contains(query)) return true;
      if (team1.contains(query) || team2.contains(query)) return true;
      if (dateStr.contains(query)) return true;
      for (final p in g.players) {
        if (p.userName.toLowerCase().contains(query)) return true;
        if (p.deckName.toLowerCase().contains(query)) return true;
      }
      return false;
    }).toList();
  }

  Future<void> _refreshGames() async {
    ref.invalidate(gamesHistoryProvider);
    await ref.read(gamesHistoryProvider.future);
  }

  static const _weekdayNames = [
    'понедельник', 'вторник', 'среда', 'четверг',
    'пятница', 'суббота', 'воскресенье',
  ];

  String _formatDate(DateTime dt, {required int timezoneOffsetMinutes}) {
    final localDt = TimezoneUtils.toConfiguredTimezone(
      dt,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
    );
    final weekday = _weekdayNames[localDt.weekday - 1];
    return '${localDt.day.toString().padLeft(2, '0')}.'
        '${localDt.month.toString().padLeft(2, '0')}.'
        '${localDt.year} ($weekday)';
  }

  static final _headerStyle = TextStyle(
    color: Colors.grey[700],
    fontWeight: FontWeight.w500,
    fontSize: 14,
  );

  Widget _buildGameHeader(Game g, {required int timezoneOffsetMinutes}) {
    return Text(
      '${_formatDate(g.startTime, timezoneOffsetMinutes: timezoneOffsetMinutes)} №${g.id}',
      style: _headerStyle,
    );
  }

  Widget _buildWinBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber[700],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'WIN',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildGameTitle(Game g) {
    final team1 = g.team1Name?.isNotEmpty == true ? g.team1Name! : 'Команда 1';
    final team2 = g.team2Name?.isNotEmpty == true ? g.team2Name! : 'Команда 2';
    final winner = g.winningTeam;
    final techDefeat = g.isTechnicalDefeat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 16,
            ),
            children: [
              TextSpan(text: team1, style: TextStyle(color: _team1Color[800])),
              if (winner == 1)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _buildWinBadge(),
                ),
              const TextSpan(text: ' vs '),
              TextSpan(text: team2, style: TextStyle(color: _team2Color[800])),
              if (winner == 2)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _buildWinBadge(),
                ),
              if (g.endTime == null) const TextSpan(text: ' (активная)'),
            ],
          ),
        ),
        if (techDefeat)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Тех. поражение по времени',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildPlayersByTeam(Game g) {
    if (g.players.isEmpty) return [];
    final team1 = g.team1Name?.isNotEmpty == true ? g.team1Name! : 'Команда 1';
    final team2 = g.team2Name?.isNotEmpty == true ? g.team2Name! : 'Команда 2';
    final half = (g.players.length / 2).ceil();
    final team1Players = g.players.take(half).map((p) => p.userName).join(', ');
    final team2Players = g.players.skip(half).map((p) => p.userName).join(', ');
    return [
      _buildTeamRow(team1, team1Players, _team1Color),
      if (team2Players.isNotEmpty)
        _buildTeamRow(team2, team2Players, _team2Color),
    ];
  }

  Widget _buildTeamRow(
    String teamName,
    String players,
    MaterialColor teamColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          children: [
            TextSpan(
              text: '$teamName: ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: teamColor[700],
              ),
            ),
            TextSpan(text: players),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gamesHistoryProvider);
    final timezoneOffsetMinutes = ref.watch(currentTimezoneOffsetProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('История партий', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: gamesAsync.isLoading ? null : _refreshGames,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск партий',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          if (gamesAsync.asData?.value.isNotEmpty == true)
            _buildGamesHeader(gamesAsync.asData!.value, timezoneOffsetMinutes),
          Expanded(
            child: _buildBody(
              gamesAsync: gamesAsync,
              timezoneOffsetMinutes: timezoneOffsetMinutes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesHeader(List<Game> games, int timezoneOffsetMinutes) {
    final filteredCount = _filteredGames(games, timezoneOffsetMinutes).length;
    final isSearching = _searchController.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            isSearching
                ? 'Найдено: $filteredCount'
                : 'Всего партий: ${games.length}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required AsyncValue<List<Game>> gamesAsync,
    required int timezoneOffsetMinutes,
  }) {
    if (gamesAsync.isLoading) {
      return const AsyncLoadingView();
    }
    if (gamesAsync.hasError) {
      return AsyncErrorView(
        message: gamesAsync.error.toString(),
        onRetry: _refreshGames,
      );
    }
    final games = gamesAsync.asData?.value ?? const <Game>[];
    if (games.isEmpty) {
      return const EmptyStateView(
        icon: Icons.history,
        title: 'Нет сыгранных партий',
      );
    }
    final filtered = _filteredGames(games, timezoneOffsetMinutes);
    if (filtered.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off,
        title: 'Ничего не найдено',
        subtitle: 'Попробуйте изменить запрос',
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshGames,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final game = filtered[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGameHeader(
                    game,
                    timezoneOffsetMinutes: timezoneOffsetMinutes,
                  ),
                  const SizedBox(height: 4),
                  _buildGameTitle(game),
                  const Divider(),  
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildPlayersByTeam(game),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openGameDetail(
                game,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openGameDetail(Game game, {required int timezoneOffsetMinutes}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameDetailPage(
          game: game,
          timezoneOffsetMinutes: timezoneOffsetMinutes,
        ),
      ),
    );
  }
}

/// Цвета команд (как на странице активной игры).
const _team1Color = Colors.blue;
const _team2Color = Colors.green;

/// Детальный просмотр партии.
class GameDetailPage extends StatelessWidget {
  final Game game;
  final int timezoneOffsetMinutes;

  const GameDetailPage({
    super.key,
    required this.game,
    required this.timezoneOffsetMinutes,
  });

  String _formatDateTime(DateTime dt) {
    final localDt = TimezoneUtils.toConfiguredTimezone(
      dt,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
    );
    return '${localDt.day.toString().padLeft(2, '0')}.'
        '${localDt.month.toString().padLeft(2, '0')}.'
        '${localDt.year} '
        '${localDt.hour.toString().padLeft(2, '0')}:'
        '${localDt.minute.toString().padLeft(2, '0')}';
  }

  static const _weekdayNames = [
    'понедельник', 'вторник', 'среда', 'четверг',
    'пятница', 'суббота', 'воскресенье',
  ];

  String _formatDateWithWeekday(DateTime dt) {
    final localDt = TimezoneUtils.toConfiguredTimezone(
      dt,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
    );
    final weekday = _weekdayNames[localDt.weekday - 1];
    return '${localDt.day.toString().padLeft(2, '0')}.'
        '${localDt.month.toString().padLeft(2, '0')}.'
        '${localDt.year} ($weekday)';
  }

  @override
  Widget build(BuildContext context) {
    final team1 =
        game.team1Name?.isNotEmpty == true ? game.team1Name! : 'Команда 1';
    final team2 =
        game.team2Name?.isNotEmpty == true ? game.team2Name! : 'Команда 2';
    final half = (game.players.length / 2).ceil();
    final team1Players = game.players.take(half).toList();
    final team2Players = game.players.skip(half).toList();

    // duration — полное время хода (overtime уже включён), паузы не учитываются в ходах
    final team1TurnDuration = game.turns
        .where((t) => t.teamNumber == 1)
        .fold<Duration>(Duration.zero, (s, t) => s + t.duration);
    final team2TurnDuration = game.turns
        .where((t) => t.teamNumber == 2)
        .fold<Duration>(Duration.zero, (s, t) => s + t.duration);

    return Scaffold(
      appBar: AppBar(
        title: Text('Партия #${game.id}', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Дата игры: ${_formatDateWithWeekday(game.startTime)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Общее время партии: ${FormatUtils.formatDurationHuman(game.totalDuration)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: team1,
                            style: TextStyle(color: _team1Color[800]),
                          ),
                          const TextSpan(text: ' vs '),
                          TextSpan(
                            text: team2,
                            style: TextStyle(color: _team2Color[800]),
                          ),
                        ],
                      ),
                    ),
                    if (game.endTime != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Начало: ${_formatDateTime(game.startTime)}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Окончание: ${_formatDateTime(game.endTime!)}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      if (game.winningTeam != null) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            'Победила команда: ${game.winningTeam == 1 ? team1 : team2}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w100,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: Colors.green[700],
                        ),
                        if (game.isTechnicalDefeat) ...[
                          const SizedBox(height: 4),
                          Chip(
                            label: const Text(
                              'Тех. поражение по времени',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: Colors.orange[700],
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Состав команд',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _teamRow(context, team1, team1Players, 1),
                    if (team2Players.isNotEmpty)
                      _teamRow(context, team2, team2Players, 2),
                  ],
                ),
              ),
            ),
            if (game.turns.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Время по командам:',
                        style: TextStyle(
                         fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$team1: ${FormatUtils.formatDurationHuman(team1TurnDuration)}',
                        style: TextStyle(
                          color: _team1Color[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$team2: ${FormatUtils.formatDurationHuman(team2TurnDuration)}',
                        style: TextStyle(
                          color: _team2Color[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Ходы',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        game.turnLimitSeconds > 0
                            ? 'Лимит хода: ${FormatUtils.formatDurationHuman(Duration(seconds: game.turnLimitSeconds))}'
                            : 'Без ограничения времени на ход',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (game.teamTimeLimitSeconds > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Лимит на команду: ${FormatUtils.formatDurationHuman(Duration(seconds: game.teamTimeLimitSeconds))}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ...game.turns.asMap().entries.map((e) {
                        final i = e.key + 1;
                        final t = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  'Ход $i:',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'команда ${t.teamNumber}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: (t.teamNumber == 1
                                              ? _team1Color
                                              : _team2Color)[800],
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' — ${FormatUtils.formatDurationHuman(t.duration)}',
                                      ),
                                      if (t.overtime.inSeconds > 0)
                                        TextSpan(
                                          text:
                                              ' (+${FormatUtils.formatDurationHuman(t.overtime)})',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _teamRow(
    BuildContext context,
    String teamName,
    List<GamePlayer> players,
    int teamNum,
  ) {
    final color = teamNum == 1 ? _team1Color : _team2Color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$teamName:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color[800],
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          ...players.map(
            (p) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.userName,
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ),
                  _DeckLink(
                    deckId: p.deckId,
                    deckName: p.deckName.isNotEmpty ? p.deckName : '—',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ссылка на колоду: при нажатии открывает карточку колоды.
class _DeckLink extends StatelessWidget {
  final int deckId;
  final String deckName;

  const _DeckLink({required this.deckId, required this.deckName});

  Future<void> _openDeck(BuildContext context) async {
    if (deckId <= 0) return;
    final deckService = DeckService();
    final deck = await deckService.getDeckById(deckId);
    if (!context.mounted) return;
    if (deck != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeckCardPage(
            deck: deck,
            deckService: deckService,
            readOnly: !ApiConfig.isAdmin,
          ),
        ),
      );
    } else {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Не удалось загрузить колоду «$deckName»'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLink = deckId > 0;
    return GestureDetector(
      onTap: isLink ? () => _openDeck(context) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLink) Icon(Icons.badge, size: 16, color: Colors.blue[700]),
          if (isLink) const SizedBox(width: 4),
          Text(
            deckName,
            style: TextStyle(
              fontSize: 13,
              color: isLink ? Colors.blue[700] : Colors.grey[600],
              decoration: isLink ? TextDecoration.underline : null,
              decorationColor: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }
}
