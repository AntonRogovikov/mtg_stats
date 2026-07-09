import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/pages/deck_detail_page.dart';
import 'package:mtg_stats/pages/decks_page.dart';
import 'package:mtg_stats/pages/game_page.dart';
import 'package:mtg_stats/pages/games_history_page.dart';
import 'package:mtg_stats/pages/change_password_page.dart';
import 'package:mtg_stats/pages/public_game_page.dart';
import 'package:mtg_stats/pages/settings_page.dart';
import 'package:mtg_stats/pages/slice_picker_page.dart';
import 'package:mtg_stats/pages/slices_manage_page.dart';
import 'package:mtg_stats/pages/stats_page.dart';
import 'package:mtg_stats/pages/users_page.dart';
import 'package:mtg_stats/providers/slice_providers.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/widgets/responsive_web_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
  await ApiConfig.load();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// Корневой виджет приложения: MaterialApp с named routes, AppTheme, ResponsiveWebLayout.
/// Тема подстраивается под цвет текущего разреза (SliceGate — точка входа).
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSlice = ref.watch(currentSliceProvider);
    AppTheme.setSliceColor(currentSlice?.themeColor);
    return MaterialApp(
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.appBarBackground,
          foregroundColor: AppTheme.appBarForeground,
          iconTheme: const IconThemeData(color: AppTheme.appBarForeground),
          centerTitle: true,
        ),
      ),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return ResponsiveWebLayout(child: child);
      },
      home: const SliceGate(),
      routes: {
        '/slices/manage': (context) => const SlicesManagePage(),
        '/decks': (context) => const DeckListPage(),
        '/games': (context) => const GamePage(),
        '/games/history': (context) => const GamesHistoryPage(),
        '/stats': (context) => const StatsPage(),
        '/settings': (context) => const SettingsPage(),
        '/settings/change-password': (context) => const ChangePasswordPage(),
        '/users': (context) => const UsersPage(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.startsWith('/public/game/')) {
          final token = name.replaceFirst('/public/game/', '');
          return MaterialPageRoute(
            builder: (_) => PublicGamePage(token: token),
          );
        }
        if (name == '/stats/deck') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (_) => DeckDetailPage(
                deckId: args['deckId'] as int,
                deckName: args['deckName'] as String,
              ),
            );
          }
        }
        return null;
      },
    );
  }
}
