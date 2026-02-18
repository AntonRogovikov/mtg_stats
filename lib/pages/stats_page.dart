import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/services/stats_service.dart';
import 'package:mtg_stats/widgets/stats/stats.dart';

enum StatsViewMode { list, histogram, pie, podium }

/// Статистика игроков и колод: загрузка с API, виды (список, графики, подиум).
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final StatsService _statsService = StatsService();
  List<PlayerStats>? _playerStats;
  List<DeckStats>? _deckStats;
  bool _loading = true;
  String? _error;
  StatsViewMode _viewMode = StatsViewMode.list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final players = await _statsService.getPlayerStats();
      final decks = await _statsService.getDeckStats();
      if (mounted) {
        setState(() {
          _playerStats = List<PlayerStats>.from(players)
            ..sort((a, b) {
              final cmp = b.winPercent.compareTo(a.winPercent);
              if (cmp != 0) return cmp;
              return b.winsCount.compareTo(a.winsCount);
            });
          _deckStats = List<DeckStats>.from(decks)
            ..sort((a, b) {
              final cmp = b.winPercent.compareTo(a.winPercent);
              if (cmp != 0) return cmp;
              return b.winsCount.compareTo(a.winsCount);
            });
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Статистика', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          PopupMenuButton<StatsViewMode>(
            icon: Icon(
              _iconForViewMode(_viewMode),
              color: AppTheme.appBarForeground,
            ),
            tooltip: 'Вид статистики',
            onSelected: (mode) => setState(() => _viewMode = mode),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: StatsViewMode.list,
                child: ListTile(
                  leading: Icon(Icons.list),
                  title: Text('Список'),
                ),
              ),
              const PopupMenuItem(
                value: StatsViewMode.histogram,
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('Гистограмма'),
                ),
              ),
              const PopupMenuItem(
                value: StatsViewMode.pie,
                child: ListTile(
                  leading: Icon(Icons.pie_chart),
                  title: Text('Круговая диаграмма'),
                ),
              ),
              const PopupMenuItem(
                value: StatsViewMode.podium,
                child: ListTile(
                  leading: Icon(Icons.emoji_events),
                  title: Text('Подиум'),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Material(
                        color: Colors.white,
                        child: TabBar(
                          labelColor: Colors.blueGrey[900],
                          tabs: const [
                            Tab(text: 'Игроки'),
                            Tab(text: 'Колоды'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildPlayerView(),
                            _buildDeckView(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  IconData _iconForViewMode(StatsViewMode mode) {
    switch (mode) {
      case StatsViewMode.list:
        return Icons.list;
      case StatsViewMode.histogram:
        return Icons.bar_chart;
      case StatsViewMode.pie:
        return Icons.pie_chart;
      case StatsViewMode.podium:
        return Icons.emoji_events;
    }
  }

  Widget _buildPlayerView() {
    switch (_viewMode) {
      case StatsViewMode.list:
        return _buildPlayerStats();
      case StatsViewMode.histogram:
        return _buildPlayerHistogram();
      case StatsViewMode.pie:
        return _buildPlayerPie();
      case StatsViewMode.podium:
        return _buildPlayerPodium();
    }
  }

  Widget _buildDeckView() {
    switch (_viewMode) {
      case StatsViewMode.list:
        return _buildDeckStats();
      case StatsViewMode.histogram:
        return _buildDeckHistogram();
      case StatsViewMode.pie:
        return _buildDeckPie();
      case StatsViewMode.podium:
        return _buildDeckPodium();
    }
  }

  Widget _buildPlayerStats() {
    final list = _playerStats ?? [];
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных. Сыграйте партии и завершайте их.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        return Card(
          key: ValueKey<String>(s.playerName),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.playerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _row('Игр', '${s.gamesCount}'),
                _row('Побед', '${s.winsCount}'),
                _row('% побед', '${s.winPercent.toStringAsFixed(1)}%'),
                _row(
                  '% побед при первом ходе',
                  '${s.firstMoveWinPercent.toStringAsFixed(1)}% (${s.firstMoveWins}/${s.firstMoveGames})',
                ),
                _row('Среднее время хода', '${s.avgTurnDurationSec} сек'),
                _row('Макс. время хода', '${s.maxTurnDurationSec} сек'),
                if (s.bestDeckName.isNotEmpty)
                  _row(
                    'Лучшая колода',
                    s.bestDeckName,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDeckStats() {
    final list = _deckStats ?? [];
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных по колодам.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        return Card(
          key: ValueKey<String>(s.deckName),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(s.deckName),
            subtitle: Text(
              'Игр: ${s.gamesCount}, побед: ${s.winsCount}, '
              'успешность: ${s.winPercent.toStringAsFixed(1)}%',
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerHistogram() {
    final list = _playerStats ?? [];
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных. Сыграйте партии и завершайте их.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return StatsHistogramBar(
      title: '% побед',
      items: list
          .map((s) => StatsHistogramItem(
                label: s.playerName,
                value: s.winPercent,
                tooltipLines: [
                  s.playerName,
                  'Игр: ${s.gamesCount}, побед: ${s.winsCount}',
                  'Успешность: ${s.winPercent.toStringAsFixed(1)}%'
                ],
              ))
          .toList(),
      maxY: 100,
      valueSuffix: '%',
      barColor: Colors.blueGrey,
      axisIcon: Icons.person,
    );
  }

  Widget _buildDeckHistogram() {
    final list = _deckStats ?? [];
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных по колодам.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return StatsHistogramBar(
      title: '% побед',
      items: list
          .map((s) => StatsHistogramItem(
                label: s.deckName,
                value: s.winPercent,
                tooltipLines: [
                  s.deckName,
                  'Игр: ${s.gamesCount}, побед: ${s.winsCount}',
                  'Успешность: ${s.winPercent.toStringAsFixed(1)}%',
                ],
              ))
          .toList(),
      maxY: 100,
      valueSuffix: '%',
      barColor: Colors.teal,
      axisIcon: Icons.style,
    );
  }

  Widget _buildPlayerPie() {
    final list = _playerStats ?? [];
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных. Сыграйте партии и завершайте их.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    final totalWins = list.fold<int>(0, (s, e) => s + e.winsCount);
    if (totalWins == 0) {
      return const Center(
        child: Text(
          'Нет побед для отображения.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return StatsPieChartView(
      title: 'Доля побед по игрокам',
      items: list
          .map((s) => StatsPieItem(
                label: s.playerName,
                value: s.winsCount.toDouble(),
                tooltip: '${s.playerName}\n${s.winsCount} побед (${s.winPercent.toStringAsFixed(1)}%)',
              ))
          .toList(),
      colors: statsPieDefaultColors,
    );
  }

  Widget _buildDeckPie() {
    final list = _deckStats ?? [];
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных по колодам.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    final totalWins = list.fold<int>(0, (s, e) => s + e.winsCount);
    if (totalWins == 0) {
      return const Center(
        child: Text(
          'Нет побед для отображения.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return StatsPieChartView(
      title: 'Доля побед по колодам',
      items: list
          .map((s) => StatsPieItem(
                label: s.deckName,
                value: s.winsCount.toDouble(),
                tooltip: '${s.deckName}\n${s.winsCount} побед (${s.winPercent.toStringAsFixed(1)}%)',
              ))
          .toList(),
      colors: statsPieDefaultColors,
    );
  }

  Widget _buildPlayerPodium() {
    final list = _playerStats ?? [];
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных. Сыграйте партии и завершайте их.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return StatsPodiumView(
      title: 'Топ игроков',
      items: list
          .map((s) => StatsPodiumItem(
                label: s.playerName,
                value: s.winPercent,
                subtitle: '${s.winsCount} / ${s.gamesCount} игр',
              ))
          .toList(),
    );
  }

  Widget _buildDeckPodium() {
    final list = _deckStats ?? [];
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных по колодам.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return StatsPodiumView(
      title: 'Топ колод',
      items: list
          .map((s) => StatsPodiumItem(
                label: s.deckName,
                value: s.winPercent,
                subtitle: '${s.winsCount} / ${s.gamesCount} игр',
              ))
          .toList(),
    );
  }
}
