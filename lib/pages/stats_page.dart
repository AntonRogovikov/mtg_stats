import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/services/stats_service.dart';

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
    return _HistogramBar(
      title: '% побед',
      items: list
          .map((s) => _HistogramItem(
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
    return _HistogramBar(
      title: '% побед',
      items: list
          .map((s) => _HistogramItem(
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

  static const List<Color> _pieColors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Color(0xFF66BB6A),
  ];

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
    return _PieChartView(
      title: 'Доля побед по игрокам',
      items: list
          .map((s) => _PieItem(
                label: s.playerName,
                value: s.winsCount.toDouble(),
                tooltip: '${s.playerName}\n${s.winsCount} побед (${s.winPercent.toStringAsFixed(1)}%)',
              ))
          .toList(),
      colors: _pieColors,
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
    return _PieChartView(
      title: 'Доля побед по колодам',
      items: list
          .map((s) => _PieItem(
                label: s.deckName,
                value: s.winsCount.toDouble(),
                tooltip: '${s.deckName}\n${s.winsCount} побед (${s.winPercent.toStringAsFixed(1)}%)',
              ))
          .toList(),
      colors: _pieColors,
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
    return _PodiumView(
      title: 'Топ игроков',
      items: list
          .map((s) => _PodiumItem(
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
    return _PodiumView(
      title: 'Топ колод',
      items: list
          .map((s) => _PodiumItem(
                label: s.deckName,
                value: s.winPercent,
                subtitle: '${s.winsCount} / ${s.gamesCount} игр',
              ))
          .toList(),
    );
  }
}

class _HistogramItem {
  final String label;
  final double value;
  final List<String> tooltipLines;

  _HistogramItem({
    required this.label,
    required this.value,
    required this.tooltipLines,
  });
}

class _HistogramBar extends StatefulWidget {
  final String title;
  final List<_HistogramItem> items;
  final double maxY;
  final String valueSuffix;
  final Color barColor;
  final IconData axisIcon;

  const _HistogramBar({
    required this.title,
    required this.items,
    required this.maxY,
    required this.valueSuffix,
    required this.barColor,
    required this.axisIcon,
  });

  @override
  State<_HistogramBar> createState() => _HistogramBarState();
}

class _HistogramBarState extends State<_HistogramBar> {
  int? _touchedGroupIndex;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final maxVal = items.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMaxY = (maxVal > 0 ? maxVal * 1.15 : widget.maxY).clamp(1.0, widget.maxY);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56.0 * items.length.clamp(2, 12).toDouble(),
                    child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: effectiveMaxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedGroupIndex = response?.spot?.touchedBarGroupIndex;
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex >= 0 && groupIndex < items.length) {
                        final item = items[groupIndex];
                        return BarTooltipItem(
                          item.tooltipLines.join('\n'),
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        );
                      }
                      return null;
                    },
                    getTooltipColor: (_) => Colors.blueGrey[800]!,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipMargin: 8,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= 0 && i < items.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Icon(
                              widget.axisIcon,
                              size: 24,
                              color: Colors.grey[700],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}${widget.valueSuffix}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: effectiveMaxY / 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isTouched = _touchedGroupIndex == i;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: item.value.clamp(0.0, effectiveMaxY),
                        color: isTouched
                            ? widget.barColor.withValues(alpha: 0.8)
                            : widget.barColor.withValues(alpha: 0.6),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                    showingTooltipIndicators: isTouched ? [0] : [],
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 200),
            ),
          ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PieItem {
  final String label;
  final double value;
  final String tooltip;

  _PieItem({required this.label, required this.value, required this.tooltip});
}

class _PieChartView extends StatefulWidget {
  final String title;
  final List<_PieItem> items;
  final List<Color> colors;

  const _PieChartView({
    required this.title,
    required this.items,
    required this.colors,
  });

  @override
  State<_PieChartView> createState() => _PieChartViewState();
}

class _PieChartViewState extends State<_PieChartView> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final total = items.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = math.min(constraints.maxWidth, constraints.maxHeight);
        // Адаптивный размер диаграммы в зависимости от размера экрана
        final chartSize = maxSide.clamp(220.0, 420.0);
        final baseRadius = chartSize * 0.28;
        final touchedRadius = baseRadius * 1.15;

        final sections = items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final color = widget.colors[i % widget.colors.length];
          final isTouched = _touchedIndex == i;
          return PieChartSectionData(
            value: item.value,
            title: '${(item.value / total * 100).toStringAsFixed(0)}%',
            color: isTouched ? color.withValues(alpha: 0.9) : color.withValues(alpha: 0.75),
            radius: isTouched ? touchedRadius : baseRadius,
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          );
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: chartSize,
                    child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: chartSize * 0.16,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedIndex = response?.touchedSection?.touchedSectionIndex;
                    });
                  },
                ),
                sectionsSpace: 2,
              ),
              duration: const Duration(milliseconds: 200),
            ),
          ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final color = widget.colors[i % widget.colors.length];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 500),
                                child: Text(
                                  item.label,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(item.value / total * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PodiumItem {
  final String label;
  final double value;
  final String subtitle;

  _PodiumItem({
    required this.label,
    required this.value,
    required this.subtitle,
  });
}

class _PodiumView extends StatelessWidget {
  final String title;
  final List<_PodiumItem> items;

  const _PodiumView({required this.title, required this.items});

  static const _medals = ['🥇', '🥈', '🥉'];
  static const _placeColors = [
    Color(0xFFD4AF37),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final top3 = items.take(3).toList();
    final rest = items.length > 3 ? items.sublist(3) : <_PodiumItem>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (top3.length > 1)
                Expanded(
                  child: _PodiumPlace(
                    place: 2,
                    medal: _medals[1],
                    item: top3[1],
                    color: _placeColors[1],
                    height: 85,
                  ),
                ),
              if (top3.isNotEmpty) ...[
                if (top3.length > 1) const SizedBox(width: 8),
                Expanded(
                  child: _PodiumPlace(
                    place: 1,
                    medal: _medals[0],
                    item: top3[0],
                    color: _placeColors[0],
                    height: 110,
                  ),
                ),
              ],
              if (top3.length > 2) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _PodiumPlace(
                    place: 3,
                    medal: _medals[2],
                    item: top3[2],
                    color: _placeColors[2],
                    height: 65,
                  ),
                ),
              ],
            ],
                  ),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    ...rest.asMap().entries.map((entry) {
                      final idx = entry.key + 4;
                      final item = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey[100],
                            child: Text(
                              '$idx',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                            ),
                          ),
                          title: Text(
                            item.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(item.subtitle),
                          trailing: Text(
                            '${item.value.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final int place;
  final String medal;
  final _PodiumItem item;
  final Color color;
  final double height;

  const _PodiumPlace({
    required this.place,
    required this.medal,
    required this.item,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          medal,
          style: const TextStyle(fontSize: 36),
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${item.value.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              '$place',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
