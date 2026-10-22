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
import 'package:mtg_stats/services/auth_http_client.dart';
import 'package:mtg_stats/widgets/responsive_web_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
  await ApiConfig.load();
  runApp(
    const ProviderScope(
      retry: apiProviderRetry,
      child: MyApp(),
    ),
  );
}

/// Корневой виджет приложения: MaterialApp с named routes, AppTheme, ResponsiveWebLayout.
/// Тема подстраивается под цвет текущего разреза (SliceGate — точка входа).
/// Слушает ApiConfig.sessionExpired и предлагает войти заново.
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    ApiConfig.sessionExpired.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    ApiConfig.sessionExpired.removeListener(_onSessionExpired);
    super.dispose();
  }

  void _onSessionExpired() {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Сессия истекла. Войдите снова.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Войти',
          textColor: Colors.white,
          onPressed: () => _navigatorKey.currentState?.pushNamed('/settings'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSlice = ref.watch(currentSliceProvider);
    AppTheme.setSliceColor(currentSlice?.themeColor);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
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
