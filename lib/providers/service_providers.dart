import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/models/user.dart';
import 'package:mtg_stats/services/auth_service.dart';
import 'package:mtg_stats/services/app_settings_service.dart';
import 'package:mtg_stats/services/deck_service.dart';
import 'package:mtg_stats/services/game_service.dart';
import 'package:mtg_stats/services/health_service.dart';
import 'package:mtg_stats/services/maintenance_service.dart';
import 'package:mtg_stats/services/user_service.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final gameServiceProvider = Provider<GameService>((ref) {
  return GameService(client: ref.watch(httpClientProvider));
});

final deckServiceProvider = Provider<DeckService>((ref) {
  return DeckService(client: ref.watch(httpClientProvider));
});

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(client: ref.watch(httpClientProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(client: ref.watch(httpClientProvider));
});

final maintenanceServiceProvider = Provider<MaintenanceService>((ref) {
  return MaintenanceService(client: ref.watch(httpClientProvider));
});

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService(client: ref.watch(httpClientProvider));
});

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService(client: ref.watch(httpClientProvider));
});

final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final appSettingsService = ref.watch(appSettingsServiceProvider);
  return appSettingsService.getSettings();
});

final usersProvider = FutureProvider<List<User>>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return userService.getUsers();
});

final decksProvider = FutureProvider<List<Deck>>((ref) async {
  final deckService = ref.watch(deckServiceProvider);
  return deckService.getAllDecks();
});

final gamesHistoryProvider = FutureProvider<List<Game>>((ref) async {
  final gameService = ref.watch(gameServiceProvider);
  final games = await gameService.getGames();
  games.sort((a, b) {
    final idA = int.tryParse(a.id) ?? 0;
    final idB = int.tryParse(b.id) ?? 0;
    if (idA != idB) return idB.compareTo(idA);
    return b.startTime.compareTo(a.startTime);
  });
  return games;
});

final currentTimezoneOffsetProvider = Provider<int>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.asData?.value.timezoneOffsetMinutes ?? 0;
});
