import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/services/game_service.dart';

/// Страница истории партий: список завершённых игр.
class GamesHistoryPage extends StatefulWidget {
  const GamesHistoryPage({super.key});

  @override
  State<GamesHistoryPage> createState() => _GamesHistoryPageState();
}

class _GamesHistoryPageState extends State<GamesHistoryPage> {
  final GameService _gameService = GameService();
  List<Game> _games = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _gameService.getGames();
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

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = DateTime(dt.year, dt.month, dt.day);
    if (gameDay == today) {
      return 'Сегодня ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (gameDay == yesterday) {
      return 'Вчера ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _gameSummary(Game g) {
    final team1 = g.team1Name?.isNotEmpty == true
        ? g.team1Name!
        : 'Команда 1';
    final team2 = g.team2Name?.isNotEmpty == true
        ? g.team2Name!
        : 'Команда 2';
    if (g.endTime != null && g.winningTeam != null) {
      final winner = g.winningTeam == 1 ? team1 : team2;
      return '$team1 vs $team2 — победила $winner';
    }
    return '$team1 vs $team2 (активная)';
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
      body: _buildBody(),
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
    return RefreshIndicator(
      onRefresh: _loadGames,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _games.length,
        itemBuilder: (context, index) {
          final game = _games[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              title: Text(
                _gameSummary(game),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(game.startTime),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  if (game.players.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      game.players.map((p) => p.userName).join(', '),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
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

/// Детальный просмотр партии.
class GameDetailPage extends StatelessWidget {
  final Game game;

  const GameDetailPage({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final team1 = game.team1Name?.isNotEmpty == true
        ? game.team1Name!
        : 'Команда 1';
    final team2 = game.team2Name?.isNotEmpty == true
        ? game.team2Name!
        : 'Команда 2';
    final team1Players =
        game.players.length >= 2
            ? game.players.take(2).map((p) => p.userName).join(', ')
            : game.players.map((p) => p.userName).join(', ');
    final team2Players =
        game.players.length > 2
            ? game.players.skip(2).map((p) => p.userName).join(', ')
            : '';

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
                      '$team1 vs $team2',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Начало: ${_formatDateTime(game.startTime)}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    if (game.endTime != null) ...[
                      Text(
                        'Окончание: ${_formatDateTime(game.endTime!)}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      if (game.winningTeam != null) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            'Победила: ${game.winningTeam == 1 ? team1 : team2}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: Colors.green[700],
                        ),
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
                      'Игроки',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _playerRow(team1, team1Players, 1),
                    if (team2Players.isNotEmpty) _playerRow(team2, team2Players, 2),
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
                      const Text(
                        'Ходы',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...game.turns.asMap().entries.map((e) {
                        final i = e.key + 1;
                        final t = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Ход $i: команда ${t.teamNumber} — '
                            '${t.duration.inSeconds} сек'
                            '${t.overtime.inSeconds > 0 ? ' (+${t.overtime.inSeconds} овертайм)' : ''}',
                            style: TextStyle(color: Colors.grey[800]),
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

  Widget _playerRow(String teamName, String players, int teamNum) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$teamName:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey[800],
            ),
          ),
          Text(players, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
