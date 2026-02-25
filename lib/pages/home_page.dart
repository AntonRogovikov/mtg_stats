import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/pages/active_game_page.dart';
import 'package:mtg_stats/providers/active_game_provider.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/widgets/home_button.dart';

/// Главная страница приложения: навигация к партиям, статистике и колодам.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveGame = ref.watch(
      activeGameControllerProvider.select((state) => state.hasActiveGame),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('MTG Статистика', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.appBarForeground),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (ApiConfig.isAdmin) ...[
              HomeButton(
                text: 'ПАРТИИ',
                icon: Icons.sports_esports,
                onPressed: () {
                  if (hasActiveGame) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ActiveGamePage(),
                      ),
                    );
                  } else {
                    Navigator.pushNamed(context, '/games');
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
            HomeButton(
              text: 'ИСТОРИЯ ПАРТИЙ',
              icon: Icons.history,
              onPressed: () => Navigator.pushNamed(context, '/games/history'),
            ),
            const SizedBox(height: 20),
            HomeButton(
              text: 'СТАТИСТИКА',
              icon: Icons.bar_chart,
              onPressed: () => Navigator.pushNamed(context, '/stats'),
            ),
            const SizedBox(height: 20),
            HomeButton(
              text: 'КОЛОДЫ',
              icon: Icons.import_contacts,
              onPressed: () => Navigator.pushNamed(context, '/decks'),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
    );
  }
}
