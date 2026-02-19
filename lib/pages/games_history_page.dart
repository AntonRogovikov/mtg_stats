import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/format_utils.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/pages/deck_card_page.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/services/deck_service.dart';
import 'package:mtg_stats/services/game_service.dart';

/// Страница истории партий: список завершённых игр.
class GamesHistoryPage extends StatefulWidget {
  const GamesHistoryPage({super.key});

  @override
  State<GamesHistoryPage> createState() => _GamesHistoryPageState();
}

class _GamesHistoryPageState extends State<GamesHistoryPage> {
  final GameService _gameService = GameService();
  final TextEditingController _searchController = TextEditingController();
  List<Game> _games = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGames();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Game> get _filteredGames {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _games;
    return _games.where((g) {
      final team1 = (g.team1Name ?? 'Команда 1').toLowerCase();
      final team2 = (g.team2Name ?? 'Команда 2').toLowerCase();
      final dateStr = _formatDate(g.startTime).toLowerCase();
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

  Future<void> _loadGames() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _gameService.getGames();
      list.sort((a, b) {
        final idA = int.tryParse(a.id) ?? 0;
        final idB = int.tryParse(b.id) ?? 0;
        if (idA != idB) return idB.compareTo(idA);
        return b.startTime.compareTo(a.startTime);
      });
      if (mounted) {
        setState(() {
          _games = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _games = [];
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  static const _weekdayNames = [
    'понедельник', 'вторник', 'среда', 'четверг',
    'пятница', 'суббота', 'воскресенье',
  ];

  String _formatDate(DateTime dt) {
    final weekday = _weekdayNames[dt.weekday - 1];
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} ($weekday)';
  }

  static final _headerStyle = TextStyle(
    color: Colors.grey[700],
    fontWeight: FontWeight.w500,
    fontSize: 14,
  );

  Widget _buildGameHeader(Game g) {
    return Text(
      '${_formatDate(g.startTime)} №${g.id}',
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
    return Scaffold(
      appBar: AppBar(
        title: Text('История партий', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadGames,
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
          if (!_loading && _games.isNotEmpty) _buildGamesHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildGamesHeader() {
    final filteredCount = _filteredGames.length;
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
                : 'Всего партий: ${_games.length}',
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadGames,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (_games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет сыгранных партий',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }
    final filtered = _filteredGames;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте изменить запрос',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGames,
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
                  _buildGameHeader(game),
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
              onTap: () => _openGameDetail(game),
            ),
          );
        },
      ),
    );
  }

  void _openGameDetail(Game game) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameDetailPage(game: game),
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

  const GameDetailPage({super.key, required this.game});

  static String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  static const _weekdayNames = [
    'понедельник', 'вторник', 'среда', 'четверг',
    'пятница', 'суббота', 'воскресенье',
  ];

  static String _formatDateWithWeekday(DateTime dt) {
    final weekday = _weekdayNames[dt.weekday - 1];
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} ($weekday)';
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
      ScaffoldMessenger.of(context).showSnackBar(
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
