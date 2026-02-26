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
  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(metaDashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Мета-срез', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(metaDashboardProvider),
          ),
        ],
      ),
      body: metaAsync.when(
        loading: () => const AsyncLoadingView(),
        error: (error, _) => AsyncErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(metaDashboardProvider),
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
                      const Text('Период: за всё время'),
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
            ],
          );
        },
      ),
    );
  }
}
