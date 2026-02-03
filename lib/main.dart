import 'package:flutter/material.dart';
import 'package:mtg_stats/pages/decks_page.dart';
import 'package:mtg_stats/pages/game_page.dart';
import 'package:mtg_stats/pages/home_page.dart';
import 'package:mtg_stats/pages/settings_page.dart';
import 'package:mtg_stats/pages/stats_page.dart';
import 'package:mtg_stats/services/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  runApp(const MyApp());
}

/// Корневой виджет приложения: маршрутизация по разделам.
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
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
