import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/format_utils.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/providers/stats_providers.dart';
import 'package:mtg_stats/widgets/common/async_state_views.dart';
import 'package:mtg_stats/widgets/stats/stats.dart';

enum StatsViewMode { list, histogram, pie, podium }

/// Статистика игроков и колод: загрузка с API, виды (список, графики, подиум).
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  StatsViewMode _viewMode = StatsViewMode.list;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statsDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Статистика', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppTheme.appBarForeground),
            tooltip: 'Меню',
            onSelected: (value) {
              switch (value) {
                case '/stats/matchups':
                case '/stats/meta':
                case '/stats/synergy':
                  Navigator.pushNamed(context, value);
                  break;
                case 'list':
                case 'histogram':
                case 'pie':
                case 'podium':
                  setState(() => _viewMode = _viewModeFromString(value));
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'list',
                child: ListTile(
                  leading: Icon(Icons.list),
                  title: Text('Список'),
                ),
              ),
              const PopupMenuItem(
                value: 'histogram',
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('Гистограмма'),
                ),
              ),
              const PopupMenuItem(
                value: 'pie',
                child: ListTile(
                  leading: Icon(Icons.pie_chart),
                  title: Text('Круговая диаграмма'),
                ),
              ),
              const PopupMenuItem(
                value: 'podium',
                child: ListTile(
                  leading: Icon(Icons.emoji_events),
                  title: Text('Подиум'),
                ),
              ),
              const PopupMenuItem(
                value: '/stats/matchups',
                child: ListTile(
                  leading: Icon(Icons.grid_view),
                  title: Text('Матрица матчапов'),
                ),
              ),
              const PopupMenuItem(
                value: '/stats/meta',
                child: ListTile(
                  leading: Icon(Icons.insights),
                  title: Text('Мета-срез'),
                ),
              ),
              const PopupMenuItem(
                value: '/stats/synergy',
                child: ListTile(
                  leading: Icon(Icons.handshake_outlined),
                  title: Text('Синергия колод'),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(statsDataProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const AsyncLoadingView(),
        error: (error, _) => AsyncErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(statsDataProvider),
        ),
        data: (statsData) => DefaultTabController(
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
                    _buildPlayerView(statsData.playerStats),
                    _buildDeckView(statsData.deckStats),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  StatsViewMode _viewModeFromString(String value) {
    switch (value) {
      case 'histogram':
        return StatsViewMode.histogram;
      case 'pie':
        return StatsViewMode.pie;
      case 'podium':
        return StatsViewMode.podium;
      default:
        return StatsViewMode.list;
    }
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

  Widget _buildPlayerView(List<PlayerStats> playerStats) {
    switch (_viewMode) {
      case StatsViewMode.list:
        return _buildPlayerStats(playerStats);
      case StatsViewMode.histogram:
        return _buildPlayerHistogram(playerStats);
      case StatsViewMode.pie:
        return _buildPlayerPie(playerStats);
      case StatsViewMode.podium:
        return _buildPlayerPodium(playerStats);
    }
  }

  Widget _buildDeckView(List<DeckStats> deckStats) {
    switch (_viewMode) {
      case StatsViewMode.list:
        return _buildDeckStats(deckStats);
      case StatsViewMode.histogram:
        return _buildDeckHistogram(deckStats);
      case StatsViewMode.pie:
        return _buildDeckPie(deckStats);
      case StatsViewMode.podium:
        return _buildDeckPodium(deckStats);
    }
  }

  Widget _buildPlayerStats(List<PlayerStats> list) {
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
                _row(
                  'Среднее время хода',
                  _formatDurationSec(s.avgTurnDurationSec),
                ),
                _row(
                  'Макс. время хода',
                  _formatDurationSec(s.maxTurnDurationSec),
                ),
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

  String _formatDurationSec(int seconds) {
    final s = FormatUtils.formatDurationHuman(Duration(seconds: seconds));
    return s.isEmpty ? '0 секунд' : s;
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

  Widget _buildDeckStats(List<DeckStats> list) {
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

  Widget _buildPlayerHistogram(List<PlayerStats> list) {
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

  Widget _buildDeckHistogram(List<DeckStats> list) {
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

  Widget _buildPlayerPie(List<PlayerStats> list) {
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

  Widget _buildDeckPie(List<DeckStats> list) {
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

  Widget _buildPlayerPodium(List<PlayerStats> list) {
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

  Widget _buildDeckPodium(List<DeckStats> list) {
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
