/// Точка входа приложения MTG Stats — статистика партий Magic: The Gathering.
import 'package:flutter/material.dart';
import 'package:mtg_stats/pages/decks_page.dart';
import 'package:mtg_stats/pages/game_page.dart';
import 'package:mtg_stats/pages/home_page.dart';
import 'package:mtg_stats/pages/stats_page.dart';

void main() {
  runApp(const MyApp());
}

/// Корневой виджет приложения: маршруты и домашняя страница.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
      routes: {
        '/decks': (context) => const DeckListPage(),
        '/games': (context) => const GamePage(),
        '/stats': (context) => const StatsPage(),
      },
    );
  }
}
