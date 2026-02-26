import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/providers/stats_providers.dart';
import 'package:mtg_stats/widgets/common/async_state_views.dart';

/// Детальная страница колоды: общая статистика и матчапы против каждой колоды.
class DeckDetailPage extends ConsumerWidget {
  const DeckDetailPage({
    super.key,
    required this.deckId,
    required this.deckName,
  });

  final int deckId;
  final String deckName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsDataProvider);
    final matchupsAsync = ref.watch(deckMatchupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(deckName, style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
      ),
      body: statsAsync.when(
        loading: () => const AsyncLoadingView(),
        error: (error, _) => AsyncErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(statsDataProvider),
        ),
        data: (statsData) {
          DeckStats? deckStat;
          for (final s in statsData.deckStats) {
            if (s.deckId == deckId) {
              deckStat = s;
              break;
            }
          }
          return matchupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AsyncErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(deckMatchupsProvider),
            ),
            data: (matchups) {
              final myMatchups = matchups
                  .where((m) => m.deck1Id == deckId || m.deck2Id == deckId)
                  .toList()
                ..sort((a, b) {
                  final oppA = a.deck1Id == deckId ? a.deck2Name : a.deck1Name;
                  final oppB = b.deck1Id == deckId ? b.deck2Name : b.deck1Name;
                  return oppA.compareTo(oppB);
                });

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (deckStat != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Общая статистика',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _row('Игр', '${deckStat.gamesCount}'),
                            _row('Побед', '${deckStat.winsCount}'),
                            _row(
                              'Винрейт',
                              '${deckStat.winPercent.toStringAsFixed(1)}%',
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Матчапы',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (myMatchups.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Нет данных о матчапах для этой колоды.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...myMatchups.map((m) {
                      final isDeck1 = m.deck1Id == deckId;
                      final opponent =
                          isDeck1 ? m.deck2Name : m.deck1Name;
                      final myWins = isDeck1 ? m.deck1Wins : m.deck2Wins;
                      final myRate =
                          isDeck1 ? m.deck1WinRate : m.deck2WinRate;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(opponent),
                          subtitle: Text(
                            'Винрейт: ${myRate.toStringAsFixed(1)}%, '
                            'побед: $myWins / ${m.gamesCount}',
                          ),
                          trailing: _rateChip(myRate),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _rateChip(double rate) {
    Color color;
    if (rate >= 60) {
      color = Colors.green.shade600;
    } else if (rate >= 50) {
      color = Colors.green.shade400;
    } else if (rate >= 40) {
      color = Colors.orange.shade600;
    } else {
      color = Colors.red.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        '${rate.toStringAsFixed(0)}%',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 14,
        ),
      ),
    );
  }
}
