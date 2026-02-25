import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/providers/stats_providers.dart';
import 'package:mtg_stats/widgets/common/async_state_views.dart';

class DeckMatchupsPage extends ConsumerStatefulWidget {
  const DeckMatchupsPage({super.key});

  @override
  ConsumerState<DeckMatchupsPage> createState() => _DeckMatchupsPageState();
}

class _DeckMatchupsPageState extends ConsumerState<DeckMatchupsPage> {
  final TextEditingController _searchController = TextEditingController();
  static const int _reliableGamesThreshold = 8;
  int _minGames = 1;
  bool _onlyReliable = false;
  bool _compactView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DeckMatchupStats> _applySearch(List<DeckMatchupStats> matchups) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return matchups;
    return matchups.where((m) {
      return m.deck1Name.toLowerCase().contains(query) ||
          m.deck2Name.toLowerCase().contains(query);
    }).toList();
  }

  Color _heatColor(double rate) {
    if (rate >= 70) return Colors.green.shade500;
    if (rate >= 60) return Colors.green.shade300;
    if (rate >= 52) return Colors.lightGreen.shade200;
    if (rate >= 48) return Colors.grey.shade300;
    if (rate >= 40) return Colors.orange.shade200;
    if (rate >= 30) return Colors.deepOrange.shade300;
    return Colors.red.shade400;
  }

  String _pairKey(String a, String b) {
    return a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildHeatmapTable(List<DeckMatchupStats> matchups) {
    final effectiveMinGames = _onlyReliable
        ? (_minGames > _reliableGamesThreshold ? _minGames : _reliableGamesThreshold)
        : _minGames;
    final filteredByGames = matchups.where((m) => m.gamesCount >= effectiveMinGames).toList();

    final decks = <String>{
      for (final m in filteredByGames) m.deck1Name,
      for (final m in filteredByGames) m.deck2Name,
    }.toList()
      ..sort();

    final byPair = <String, DeckMatchupStats>{
      for (final m in filteredByGames) _pairKey(m.deck1Name, m.deck2Name): m,
    };

    if (decks.isEmpty) {
      return const EmptyStateView(
        icon: Icons.grid_off,
        title: 'Недостаточно данных',
        subtitle: 'Снизьте фильтр "минимум игр" или сыграйте больше партий',
      );
    }

    final rows = <TableRow>[];
    rows.add(
      TableRow(
        children: [
          const _HeaderCell('Колода'),
          for (final colDeck in decks) _HeaderCell(colDeck),
        ],
      ),
    );

    for (final rowDeck in decks) {
      rows.add(
        TableRow(
          children: [
            _HeaderCell(rowDeck, isRowHeader: true),
            for (final colDeck in decks)
              _MatchupHeatCell(
                rowDeck: rowDeck,
                colDeck: colDeck,
                matchup: rowDeck == colDeck ? null : byPair[_pairKey(rowDeck, colDeck)],
                heatColorResolver: _heatColor,
                compactView: _compactView,
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _legendItem('Сильный матчап (>=70%)', _heatColor(72)),
              _legendItem('Ровно (около 50%)', _heatColor(50)),
              _legendItem('Слабый матчап (<=30%)', _heatColor(28)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.75,
            maxScale: 2.0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  defaultColumnWidth: const FixedColumnWidth(96),
                  columnWidths: const {0: FixedColumnWidth(180)},
                  border: TableBorder.all(color: Colors.grey.shade200, width: 0.8),
                  children: rows,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final matchupsAsync = ref.watch(deckMatchupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Матрица матчапов', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(deckMatchupsProvider),
          ),
        ],
      ),
      body: matchupsAsync.when(
        loading: () => const AsyncLoadingView(),
        error: (error, _) => AsyncErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(deckMatchupsProvider),
        ),
        data: (matchups) {
          final filtered = _applySearch(matchups);
          if (matchups.isEmpty) {
            return const EmptyStateView(
              icon: Icons.grid_view,
              title: 'Нет данных для матчапов',
              subtitle: 'Сыграйте и завершите партии',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию колоды',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Показано: ${filtered.length} из ${matchups.length}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    const Text('Минимум игр в матчапе:'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Slider(
                        min: 1,
                        max: 20,
                        divisions: 19,
                        value: _minGames.toDouble(),
                        label: '$_minGames',
                        onChanged: (value) => setState(() => _minGames = value.round()),
                      ),
                    ),
                    Text('$_minGames'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      selected: _onlyReliable,
                      label: const Text('Только надежные (>=8 игр)'),
                      onSelected: (value) => setState(() => _onlyReliable = value),
                    ),
                    FilterChip(
                      selected: _compactView,
                      label: const Text('Компактный вид'),
                      onSelected: (value) => setState(() => _compactView = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.search_off,
                        title: 'Ничего не найдено',
                        subtitle: 'Попробуйте другой запрос',
                      )
                    : _buildHeatmapTable(filtered),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.isRowHeader = false});

  final String text;
  final bool isRowHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Colors.blueGrey.shade50,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isRowHeader ? FontWeight.w600 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MatchupHeatCell extends StatelessWidget {
  const _MatchupHeatCell({
    required this.rowDeck,
    required this.colDeck,
    required this.matchup,
    required this.heatColorResolver,
    required this.compactView,
  });

  final String rowDeck;
  final String colDeck;
  final DeckMatchupStats? matchup;
  final Color Function(double rate) heatColorResolver;
  final bool compactView;

  @override
  Widget build(BuildContext context) {
    if (rowDeck == colDeck) {
      return Container(
        alignment: Alignment.center,
        color: Colors.grey.shade200,
        height: compactView ? 48 : 62,
        child: const Text('—'),
      );
    }
    if (matchup == null) {
      return Container(
        alignment: Alignment.center,
        height: compactView ? 48 : 62,
        child: const Text(
          'n/a',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    final m = matchup!;
    final rowPerspectiveRate =
        m.deck1Name == rowDeck ? m.deck1WinRate : m.deck2WinRate;
    final rowPerspectiveWins =
        m.deck1Name == rowDeck ? m.deck1Wins : m.deck2Wins;

    final bg = heatColorResolver(rowPerspectiveRate);
    final textColor =
        rowPerspectiveRate >= 70 || rowPerspectiveRate <= 30 ? Colors.white : Colors.black87;

    return Tooltip(
      message:
          '$rowDeck vs $colDeck\n'
          'Winrate: ${rowPerspectiveRate.toStringAsFixed(1)}%\n'
          'Побед: $rowPerspectiveWins\n'
          'Игр: ${m.gamesCount}',
      child: Container(
        color: bg,
        height: compactView ? 48 : 62,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: compactView
            ? Center(
                child: Text(
                  '${rowPerspectiveRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${rowPerspectiveRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${m.gamesCount} игр',
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
