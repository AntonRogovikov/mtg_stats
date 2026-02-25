import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/providers/stats_providers.dart';
import 'package:mtg_stats/widgets/common/async_state_views.dart';

class MetaDashboardPage extends ConsumerStatefulWidget {
  const MetaDashboardPage({super.key});

  @override
  ConsumerState<MetaDashboardPage> createState() => _MetaDashboardPageState();
}

class _MetaDashboardPageState extends ConsumerState<MetaDashboardPage> {
  String _groupBy = 'week';

  String _labelForGroupBy(String groupBy) {
    switch (groupBy) {
      case 'day':
        return 'день';
      case 'month':
        return 'месяц';
      default:
        return 'неделя';
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = MetaDashboardQuery(groupBy: _groupBy);
    final metaAsync = ref.watch(metaDashboardProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: Text('Мета-срез', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(metaDashboardProvider(query)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'day', label: Text('День')),
                ButtonSegment<String>(value: 'week', label: Text('Неделя')),
                ButtonSegment<String>(value: 'month', label: Text('Месяц')),
              ],
              selected: {_groupBy},
              onSelectionChanged: (selection) {
                setState(() => _groupBy = selection.first);
              },
            ),
          ),
          Expanded(
            child: metaAsync.when(
              loading: () => const AsyncLoadingView(),
              error: (error, _) => AsyncErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(metaDashboardProvider(query)),
              ),
              data: (meta) {
                if (meta.totalGames == 0) {
                  return const EmptyStateView(
                    icon: Icons.insights,
                    title: 'Нет данных для мета-среза',
                    subtitle: 'Сыграйте и завершите партии',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 8,
                          children: [
                            Text('Всего игр: ${meta.totalGames}'),
                            Text('Уникальных колод: ${meta.uniqueDecks}'),
                            Text('Группировка: ${_labelForGroupBy(meta.groupBy)}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.blueGrey[50],
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Дополнительные инсайты',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Самая популярная колода: '
                              '${meta.topPlayedDecks.isNotEmpty ? meta.topPlayedDecks.first.deckName : '—'}',
                            ),
                            Text(
                              'Самая успешная колода: '
                              '${meta.topWinRateDecks.isNotEmpty ? meta.topWinRateDecks.first.deckName : '—'}',
                            ),
                            if (meta.topPlayedDecks.isNotEmpty &&
                                meta.topWinRateDecks.isNotEmpty &&
                                meta.topPlayedDecks.first.deckId ==
                                    meta.topWinRateDecks.first.deckId)
                              const Text(
                                'Доминирующая мета: лидер по популярности совпадает с лидером по winrate.',
                              )
                            else
                              const Text(
                                'Мета сбалансирована: лидеры по популярности и winrate различаются.',
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Топ колод по популярности',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...meta.topPlayedDecks.map(
                      (s) => ListTile(
                        dense: true,
                        title: Text(s.deckName),
                        subtitle: Text(
                          'Игр: ${s.gamesCount}, meta: ${s.metaShare.toStringAsFixed(1)}%',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Топ колод по винрейту',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...meta.topWinRateDecks.map(
                      (s) => ListTile(
                        dense: true,
                        title: Text(s.deckName),
                        subtitle: Text(
                          'Winrate: ${s.winRate.toStringAsFixed(1)}%, игр: ${s.gamesCount}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Периодные срезы',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...meta.periods.map(
                      (p) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.period} · игр: ${p.totalGames}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              ...p.decks.take(3).map(
                                    (d) => Text(
                                      '${d.deckName}: ${d.gamesCount} игр, ${d.winRate.toStringAsFixed(1)}%',
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
