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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Оценка синергии строится как покрытие матчапов парой колод (чем выше — тем лучше).',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ),
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
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Text('${index + 1}')),
                              title: Text('${s.deckA} + ${s.deckB}'),
                              subtitle: Text(
                                'Синергия: ${s.synergyScore.toStringAsFixed(1)}%, '
                                'покрытие: ${(s.confidence * 100).toStringAsFixed(0)}%, '
                                'оппонентов: ${s.coveredOpponents}',
                              ),
                            ),
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
