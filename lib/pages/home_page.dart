import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/widgets/home_button.dart';

/// Главная страница приложения: навигация к партиям, статистике и колодам.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
            HomeButton(
              text: 'ПАРТИИ',
              icon: Icons.sports_esports,
              onPressed: () => Navigator.pushNamed(context, '/games'),
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
