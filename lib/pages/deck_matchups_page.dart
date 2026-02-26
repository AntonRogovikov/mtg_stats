import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/constants.dart';
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
  _SelectedMatchupCell? _selectedCell;
  _StrengthFilter _strengthFilter = _StrengthFilter.all;
  List<DeckMatchupStats>? _cachedRawMatchups;
  List<DeckMatchupStats> _cachedPlayedOnly = const [];
  List<DeckMatchupStats>? _cachedSearchInput;
  String _cachedSearchQuery = '';
  List<DeckMatchupStats> _cachedSearchResult = const [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Поиск фильтрует только строки: показываем только строки, где название колоды содержит запрос.
  List<DeckMatchupStats> _applySearch(List<DeckMatchupStats> matchups) {
    final query = _searchController.text.trim().toLowerCase();
    if (identical(_cachedSearchInput, matchups) && _cachedSearchQuery == query) {
      return _cachedSearchResult;
    }
    // Возвращаем все матчапы — фильтрация по строкам делается в _buildHeatmapTable
    _cachedSearchInput = matchups;
    _cachedSearchQuery = query;
    _cachedSearchResult = matchups;
    return matchups;
  }

  String get _searchQuery => _searchController.text.trim().toLowerCase();

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

  bool _matchesStrength(double rate) {
    switch (_strengthFilter) {
      case _StrengthFilter.strong:
        return rate >= 60;
      case _StrengthFilter.weak:
        return rate <= 40;
      case _StrengthFilter.neutral:
        return rate > 40 && rate < 60;
      case _StrengthFilter.all:
        return true;
    }
  }

  Widget _legendItem(String label, Color color, {bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 10 : 14,
          height: compact ? 10 : 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(compact ? 2 : 4),
          ),
        ),
        SizedBox(width: compact ? 4 : 6),
        Text(label, style: TextStyle(fontSize: compact ? 10 : 12)),
      ],
    );
  }

  Widget _buildHeatmapTable(BuildContext context, List<DeckMatchupStats> matchups) {
    final effectiveMinGames = _onlyReliable
        ? (_minGames > _reliableGamesThreshold ? _minGames : _reliableGamesThreshold)
        : _minGames;
    final filteredByGames =
        matchups.where((m) => m.gamesCount > 0 && m.gamesCount >= effectiveMinGames).toList();

    final byPair = <String, DeckMatchupStats>{
      for (final m in filteredByGames) _pairKey(m.deck1Name, m.deck2Name): m,
    };

    double? rateFor(String rowDeck, String colDeck) {
      final matchup = byPair[_pairKey(rowDeck, colDeck)];
      if (matchup == null) return null;
      return matchup.deck1Name == rowDeck ? matchup.deck1WinRate : matchup.deck2WinRate;
    }

    final activeDecks = <String>{};
    for (final m in filteredByGames) {
      if (_matchesStrength(m.deck1WinRate)) {
        activeDecks.add(m.deck1Name);
      }
      if (_matchesStrength(m.deck2WinRate)) {
        activeDecks.add(m.deck2Name);
      }
    }

    var allDecks = (_strengthFilter == _StrengthFilter.all
            ? <String>{
                for (final m in filteredByGames) m.deck1Name,
                for (final m in filteredByGames) m.deck2Name,
              }
            : activeDecks)
        .toList()
      ..sort();

    // Поиск фильтрует только строки: rowDecks — только колоды, чьё название содержит запрос
    final query = _searchQuery;
    List<String> rowDecks;
    List<String> colDecks;
    if (query.isNotEmpty) {
      rowDecks = allDecks.where((d) => d.toLowerCase().contains(query)).toList();
      // Столбцы — все колоды, у которых есть матчапы с rowDecks
      final rowSet = rowDecks.toSet();
      colDecks = allDecks
          .where((d) {
            if (rowSet.contains(d)) return true;
            for (final r in rowDecks) {
              if (rateFor(r, d) != null || rateFor(d, r) != null) return true;
            }
            return false;
          })
          .toList()
        ..sort();
    } else {
      rowDecks = List.from(allDecks);
      colDecks = List.from(allDecks);
    }

    // Prune rowDecks: убрать строки без видимых матчапов
    var changed = true;
    while (changed && rowDecks.isNotEmpty) {
      changed = false;
      final remove = <String>{};
      for (final deck in rowDecks) {
        var hasMatch = false;
        for (final other in colDecks) {
          if (other == deck) continue;
          final outRate = rateFor(deck, other);
          if (outRate == null) continue;
          if (_strengthFilter == _StrengthFilter.all || _matchesStrength(outRate)) {
            hasMatch = true;
            break;
          }
        }
        if (!hasMatch) {
          remove.add(deck);
        }
      }
      if (remove.isNotEmpty) {
        rowDecks.removeWhere(remove.contains);
        changed = true;
      }
    }

    if (rowDecks.isEmpty) {
      return EmptyStateView(
        icon: Icons.grid_off,
        title: query.isNotEmpty ? 'Строки не найдены' : 'Недостаточно данных',
        subtitle: query.isNotEmpty
            ? 'Нет колод, чьё название содержит «${_searchController.text.trim()}»'
            : 'Под выбранный фильтр не найдено подходящих колод',
      );
    }

    final isCompact =
        MediaQuery.sizeOf(context).width < AppConstants.desktopBreakpoint;
    final cellH = isCompact ? 36.0 : 48.0;
    final headerH = isCompact ? 44.0 : 64.0;

    final rows = <TableRow>[];
    rows.add(
      TableRow(
        children: [
          _HeaderCell('Колода', height: headerH, compact: isCompact),
          for (final colDeck in colDecks)
            _HeaderCell(colDeck, height: headerH, compact: isCompact),
        ],
      ),
    );

    for (final rowDeck in rowDecks) {
      rows.add(
        TableRow(
          children: [
            _HeaderCell(rowDeck, isRowHeader: true, height: cellH, compact: isCompact),
            for (final colDeck in colDecks)
              _MatchupHeatCell(
                rowDeck: rowDeck,
                colDeck: colDeck,
                matchup: rowDeck == colDeck ? null : byPair[_pairKey(rowDeck, colDeck)],
                heatColorResolver: _heatColor,
                isVisible: (rate) => _matchesStrength(rate),
                onSelect: (selected) => setState(() => _selectedCell = selected),
                cellHeight: cellH,
                compact: isCompact,
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: isCompact ? 2 : 2,
          ),
          child: Wrap(
            spacing: isCompact ? 8 : 14,
            runSpacing: isCompact ? 4 : 8,
            children: [
              _legendItem(
                isCompact ? '>=8' : 'Надежные: >=$_reliableGamesThreshold игр',
                Colors.blueGrey.shade300,
                compact: isCompact,
              ),
              _legendItem(
                isCompact ? '>=70%' : 'Сильный матчап (>=70%)',
                _heatColor(72),
                compact: isCompact,
              ),
              _legendItem(
                isCompact ? '~50%' : 'Ровно (около 50%)',
                _heatColor(50),
                compact: isCompact,
              ),
              _legendItem(
                isCompact ? '<=30%' : 'Слабый матчап (<=30%)',
                _heatColor(28),
                compact: isCompact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact =
                  MediaQuery.sizeOf(context).width < AppConstants.desktopBreakpoint;
              final cellW = isCompact ? 56.0 : 112.0;
              final rowHeaderW = isCompact ? 120.0 : 220.0;
              return InteractiveViewer(
                constrained: false,
                minScale: isCompact ? 0.5 : 0.75,
                maxScale: 2.0,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Table(
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      defaultColumnWidth: FixedColumnWidth(cellW),
                      columnWidths: {0: FixedColumnWidth(rowHeaderW)},
                  border: TableBorder(
                    top: BorderSide(color: Colors.grey.shade300, width: 1.1),
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1.1),
                    left: BorderSide(color: Colors.grey.shade300, width: 1.1),
                    right: BorderSide(color: Colors.grey.shade300, width: 1.1),
                    horizontalInside: BorderSide(color: Colors.grey.shade200, width: 0.9),
                    verticalInside: BorderSide(color: Colors.grey.shade500, width: 1.35),
                  ),
                  children: rows,
                ),
              ),
            ),
          );
            },
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
          if (!identical(_cachedRawMatchups, matchups)) {
            _cachedPlayedOnly = matchups.where((m) => m.gamesCount > 0).toList();
            _cachedRawMatchups = matchups;
            _cachedSearchInput = null;
            _cachedSearchQuery = '';
            _cachedSearchResult = const [];
          }
          final playedOnly = _cachedPlayedOnly;
          final filtered = _applySearch(playedOnly);
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
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  6,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию колоды (фильтр строк)',
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
                child: Text(
                  _searchQuery.isEmpty
                      ? 'Показано: ${filtered.length} из ${playedOnly.length} матчапов'
                      : 'Фильтр строк по запросу «${_searchController.text.trim()}»',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      MediaQuery.sizeOf(context).width < AppConstants.desktopBreakpoint;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, compact ? 4 : 6),
                    child: Row(
                      children: [
                        Text(
                          'Мин. игр:',
                          style: TextStyle(
                            fontSize: compact ? 12 : 14,
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 10),
                        Expanded(
                          child: Slider(
                            min: 1,
                            max: 30,
                            divisions: 29,
                            value: _minGames.toDouble(),
                            label: '$_minGames',
                            onChanged: (value) {
                              setState(() {
                                _minGames = value.round();
                                _selectedCell = null;
                              });
                            },
                          ),
                        ),
                        Text('$_minGames', style: TextStyle(fontSize: compact ? 12 : 14)),
                      ],
                    ),
                  );
                },
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.sizeOf(context).width < AppConstants.desktopBreakpoint
                      ? 6
                      : 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      selected: _onlyReliable,
                      label: Text(
                        MediaQuery.sizeOf(context).width < AppConstants.desktopBreakpoint
                            ? '>=8 игр'
                            : 'Только надежные (>=8 игр)',
                      ),
                      onSelected: (value) {
                        setState(() {
                          _onlyReliable = value;
                          _selectedCell = null;
                        });
                      },
                    ),
                    SegmentedButton<_StrengthFilter>(
                      segments: const [
                        ButtonSegment<_StrengthFilter>(
                          value: _StrengthFilter.all,
                          label: Text('Все'),
                        ),
                        ButtonSegment<_StrengthFilter>(
                          value: _StrengthFilter.strong,
                          label: Text('Сильный'),
                        ),
                        ButtonSegment<_StrengthFilter>(
                          value: _StrengthFilter.weak,
                          label: Text('Слабый'),
                        ),
                        ButtonSegment<_StrengthFilter>(
                          value: _StrengthFilter.neutral,
                          label: Text('Нейтральный'),
                        ),
                      ],
                      selected: {_strengthFilter},
                      onSelectionChanged: (value) {
                        setState(() {
                          _strengthFilter = value.first;
                          _selectedCell = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (_selectedCell != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Card(
                    child: ListTile(
                      dense: true,
                      title: Text(
                        '${_selectedCell!.rowDeck} vs ${_selectedCell!.colDeck}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Winrate: ${_selectedCell!.winRate.toStringAsFixed(1)}%, '
                        'побед: ${_selectedCell!.wins}, игр: ${_selectedCell!.gamesCount}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _selectedCell = null),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.search_off,
                        title: 'Ничего не найдено',
                        subtitle: 'Попробуйте другой запрос',
                      )
                    : _buildHeatmapTable(context, filtered),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text,
      {this.isRowHeader = false, this.height = 64, this.compact = false});

  final String text;
  final bool isRowHeader;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 8,
          vertical: compact ? 4 : 10,
        ),
        color: Colors.blueGrey.shade50,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isRowHeader ? FontWeight.w600 : FontWeight.w500,
            fontSize: compact ? 10 : 12,
          ),
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
    required this.isVisible,
    required this.onSelect,
    this.cellHeight = 48,
    this.compact = false,
  });

  final String rowDeck;
  final String colDeck;
  final DeckMatchupStats? matchup;
  final Color Function(double rate) heatColorResolver;
  final bool Function(double rate) isVisible;
  final ValueChanged<_SelectedMatchupCell> onSelect;
  final double cellHeight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (rowDeck == colDeck) {
      return Container(
        alignment: Alignment.center,
        color: Colors.grey.shade200,
        height: cellHeight,
        child: const Text('—'),
      );
    }
    if (matchup == null) {
      return Container(
        alignment: Alignment.center,
        height: cellHeight,
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
    if (!isVisible(rowPerspectiveRate)) {
      return Container(
        alignment: Alignment.center,
        height: cellHeight,
        color: Colors.grey.shade100,
        child: const Text(
          '·',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final bg = heatColorResolver(rowPerspectiveRate);
    final textColor =
        rowPerspectiveRate >= 70 || rowPerspectiveRate <= 30 ? Colors.white : Colors.black87;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onSelect(
          _SelectedMatchupCell(
            rowDeck: rowDeck,
            colDeck: colDeck,
            winRate: rowPerspectiveRate,
            wins: rowPerspectiveWins,
            gamesCount: m.gamesCount,
          ),
        );
      },
      child: Container(
        color: bg,
        height: cellHeight,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 4,
          vertical: compact ? 2 : 6,
        ),
        child: Center(
          child: Text(
            '${rowPerspectiveRate.toStringAsFixed(0)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: compact ? 10 : 14,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedMatchupCell {
  const _SelectedMatchupCell({
    required this.rowDeck,
    required this.colDeck,
    required this.winRate,
    required this.wins,
    required this.gamesCount,
  });

  final String rowDeck;
  final String colDeck;
  final double winRate;
  final int wins;
  final int gamesCount;
}

enum _StrengthFilter { all, strong, weak, neutral }
