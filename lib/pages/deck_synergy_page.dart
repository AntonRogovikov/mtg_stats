import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/providers/stats_providers.dart';
import 'package:mtg_stats/widgets/common/async_state_views.dart';

class DeckSynergyPage extends ConsumerStatefulWidget {
  const DeckSynergyPage({super.key});

  @override
  ConsumerState<DeckSynergyPage> createState() => _DeckSynergyPageState();
}

class _DeckSynergyPageState extends ConsumerState<DeckSynergyPage> {
  final TextEditingController _searchController = TextEditingController();
  int _minGames = 8;
  List<DeckMatchupStats>? _cachedMatchupsForSynergy;
  int? _cachedMinGamesForSynergy;
  List<_SynergyPairStat> _cachedBaseSynergy = const [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _pairKey(String a, String b) {
    return a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
  }

  List<_SynergyPairStat> _buildSynergy(List<DeckMatchupStats> matchups) {
    if (!identical(_cachedMatchupsForSynergy, matchups) ||
        _cachedMinGamesForSynergy != _minGames) {
      _cachedBaseSynergy = _buildBaseSynergy(matchups);
      _cachedMatchupsForSynergy = matchups;
      _cachedMinGamesForSynergy = _minGames;
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _cachedBaseSynergy;
    }
    return _cachedBaseSynergy
        .where(
          (s) =>
              s.deckA.toLowerCase().contains(query) ||
              s.deckB.toLowerCase().contains(query),
        )
        .toList();
  }

  List<_SynergyPairStat> _buildBaseSynergy(List<DeckMatchupStats> matchups) {
    final eligible = matchups.where((m) => m.gamesCount >= _minGames).toList();
    final byPair = <String, DeckMatchupStats>{
      for (final m in eligible) _pairKey(m.deck1Name, m.deck2Name): m,
    };
    final decks = <String>{
      for (final m in eligible) m.deck1Name,
      for (final m in eligible) m.deck2Name,
    }.toList()
      ..sort();

    double? rateFor(String a, String b) {
      final m = byPair[_pairKey(a, b)];
      if (m == null) return null;
      return m.deck1Name == a ? m.deck1WinRate : m.deck2WinRate;
    }

    int? gamesFor(String a, String b) {
      final m = byPair[_pairKey(a, b)];
      return m?.gamesCount;
    }

    final results = <_SynergyPairStat>[];
    for (var i = 0; i < decks.length; i++) {
      for (var j = i + 1; j < decks.length; j++) {
        final a = decks[i];
        final b = decks[j];
        double weightedRateSum = 0;
        double weightSum = 0;
        var coveredOpponents = 0;

        for (final opponent in decks) {
          if (opponent == a || opponent == b) continue;
          final rateA = rateFor(a, opponent);
          final rateB = rateFor(b, opponent);
          if (rateA == null && rateB == null) continue;

          final effectiveRate = [rateA ?? 0, rateB ?? 0].reduce((x, y) => x > y ? x : y);
          final gA = gamesFor(a, opponent) ?? 0;
          final gB = gamesFor(b, opponent) ?? 0;
          final weight = ((gA + gB) / 2).toDouble().clamp(1, 100000);

          weightedRateSum += effectiveRate * weight;
          weightSum += weight;
          coveredOpponents++;
        }

        if (weightSum == 0 || coveredOpponents < 2) continue;
        final synergyScore = weightedRateSum / weightSum;
        final denominator = (decks.length - 2).clamp(1, 999);
        final confidence = (coveredOpponents / denominator).clamp(0.0, 1.0);
        results.add(
          _SynergyPairStat(
            deckA: a,
            deckB: b,
            synergyScore: synergyScore,
            confidence: confidence,
            coveredOpponents: coveredOpponents,
          ),
        );
      }
    }

    results.sort((a, b) {
      final scoreCmp = b.synergyScore.compareTo(a.synergyScore);
      if (scoreCmp != 0) return scoreCmp;
      return b.confidence.compareTo(a.confidence);
    });
    return results;
  }

  List<_OpponentBreakdown> _getBreakdown(
    List<DeckMatchupStats> matchups,
    String deckA,
    String deckB,
  ) {
    final eligible = matchups.where((m) => m.gamesCount >= _minGames).toList();
    final byPair = <String, DeckMatchupStats>{
      for (final m in eligible) _pairKey(m.deck1Name, m.deck2Name): m,
    };
    final decks = <String>{
      for (final m in eligible) m.deck1Name,
      for (final m in eligible) m.deck2Name,
    }.toList()
      ..sort();

    double? rateFor(String a, String b) {
      final m = byPair[_pairKey(a, b)];
      if (m == null) return null;
      return m.deck1Name == a ? m.deck1WinRate : m.deck2WinRate;
    }

    int gamesFor(String a, String b) {
      final m = byPair[_pairKey(a, b)];
      return m?.gamesCount ?? 0;
    }

    final result = <_OpponentBreakdown>[];
    for (final opponent in decks) {
      if (opponent == deckA || opponent == deckB) continue;
      final rateA = rateFor(deckA, opponent);
      final rateB = rateFor(deckB, opponent);
      if (rateA == null && rateB == null) continue;
      final effective = [rateA ?? 0, rateB ?? 0].reduce((x, y) => x > y ? x : y);
      result.add(_OpponentBreakdown(
        opponent: opponent,
        rateA: rateA,
        rateB: rateB,
        effectiveRate: effective,
        gamesA: gamesFor(deckA, opponent),
        gamesB: gamesFor(deckB, opponent),
      ));
    }
    result.sort((a, b) => b.effectiveRate.compareTo(a.effectiveRate));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final matchupsAsync = ref.watch(deckMatchupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Синергия колод', style: AppTheme.appBarTitle),
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
          final synergy = _buildSynergy(matchups);
          if (matchups.isEmpty) {
            return const EmptyStateView(
              icon: Icons.handshake_outlined,
              title: 'Нет данных для синергии',
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
                    hintText: 'Поиск пары по названию колоды',
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    const Text('Минимум игр в матчапе:'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Slider(
                        min: 1,
                        max: 30,
                        divisions: 29,
                        value: _minGames.toDouble(),
                        label: '$_minGames',
                        onChanged: (value) => setState(() => _minGames = value.round()),
                      ),
                    ),
                    Text('$_minGames'),
                  ],
                ),
              ),
              _SynergyDiagramCard(),
              Expanded(
                child: synergy.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.filter_alt_off,
                        title: 'Недостаточно данных',
                        subtitle: 'Снизьте фильтры или сыграйте больше партий',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: synergy.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final s = synergy[index];
                          final breakdown = _getBreakdown(matchups, s.deckA, s.deckB);
                          return _SynergyPairCard(
                            stat: s,
                            index: index,
                            breakdown: breakdown,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SynergyPairStat {
  const _SynergyPairStat({
    required this.deckA,
    required this.deckB,
    required this.synergyScore,
    required this.confidence,
    required this.coveredOpponents,
  });

  final String deckA;
  final String deckB;
  final double synergyScore;
  final double confidence;
  final int coveredOpponents;
}

/// Оппонент и его винрейты для разбора синергии.
class _OpponentBreakdown {
  const _OpponentBreakdown({
    required this.opponent,
    required this.rateA,
    required this.rateB,
    required this.effectiveRate,
    required this.gamesA,
    required this.gamesB,
  });

  final String opponent;
  final double? rateA;
  final double? rateB;
  final double effectiveRate;
  final int gamesA;
  final int gamesB;
}

/// Схема расчёта синергии.
class _SynergyDiagramCard extends StatefulWidget {
  @override
  State<_SynergyDiagramCard> createState() => _SynergyDiagramCardState();
}

class _SynergyDiagramCardState extends State<_SynergyDiagramCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.info_outline,
                    size: 20,
                    color: Colors.blueGrey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Как считается синергия',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              _buildDiagram(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiagram() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _deckChip('A', Colors.blue.shade400),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.add, size: 18, color: Colors.grey.shade600),
            ),
            _deckChip('B', Colors.teal.shade400),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Icon(Icons.arrow_downward, size: 20, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'для каждого оппонента',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              'max(winrate A, winrate B)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Icon(Icons.arrow_downward, size: 20, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Synergy = взвешенное среднее',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _deckChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }
}

/// Карточка пары с расширяемым разбором.
class _SynergyPairCard extends StatelessWidget {
  const _SynergyPairCard({
    required this.stat,
    required this.index,
    required this.breakdown,
  });

  final _SynergyPairStat stat;
  final int index;
  final List<_OpponentBreakdown> breakdown;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.shade100,
          child: Text('${index + 1}', style: TextStyle(color: Colors.blueGrey.shade800)),
        ),
        title: Text(
          '${stat.deckA} + ${stat.deckB}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Синергия: ${stat.synergyScore.toStringAsFixed(1)}%, '
          'покрытие: ${(stat.confidence * 100).toStringAsFixed(0)}%, '
          'оппонентов: ${stat.coveredOpponents}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Разбор по оппонентам:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ...breakdown.map((b) => _BreakdownRow(breakdown: b)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.breakdown});

  final _OpponentBreakdown breakdown;

  Color _rateColor(double rate) {
    if (rate >= 60) return Colors.green.shade600;
    if (rate >= 50) return Colors.green.shade400;
    if (rate >= 40) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final hasA = breakdown.rateA != null;
    final hasB = breakdown.rateB != null;
    final bestIsA = hasA && (breakdown.rateA ?? -1) >= (breakdown.rateB ?? -1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  breakdown.opponent,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              if (hasA)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: bestIsA ? Colors.blue.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: bestIsA ? Border.all(color: Colors.blue.shade300) : null,
                  ),
                  child: Text(
                    'A:${breakdown.rateA!.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: _rateColor(breakdown.rateA!),
                      fontWeight: bestIsA ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              if (hasB)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: !bestIsA ? Colors.teal.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: !bestIsA ? Border.all(color: Colors.teal.shade300) : null,
                  ),
                  child: Text(
                    'B:${breakdown.rateB!.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: _rateColor(breakdown.rateB!),
                      fontWeight: !bestIsA ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '→ ${breakdown.effectiveRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _rateColor(breakdown.effectiveRate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: breakdown.effectiveRate / 100,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_rateColor(breakdown.effectiveRate)),
            ),
          ),
        ],
      ),
    );
  }
}
