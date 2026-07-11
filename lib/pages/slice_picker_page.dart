import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/slice.dart';
import 'package:mtg_stats/pages/home_page.dart';
import 'package:mtg_stats/providers/slice_providers.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/widgets/common/async_state_views.dart';
import 'package:mtg_stats/widgets/home_button.dart';

/// Корневой виджет: пока разрез не выбран — экран выбора, дальше — главная.
/// При входе автоматически возвращает в последний выбранный разрез (localStorage).
class SliceGate extends ConsumerWidget {
  const SliceGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Держим текущий разрез в актуальном состоянии при обновлении списка с сервера.
    ref.listen(slicesProvider, (_, next) {
      final data = next.asData?.value;
      if (data != null) {
        ref.read(currentSliceProvider.notifier).refreshFrom(data);
      }
    });

    final current = ref.watch(currentSliceProvider);
    // Псевдо-разрез «Все разрезы» не открывает HomePage: остаёмся на экране
    // выбора, откуда кнопки ведут в сводную историю/статистику по всем играм.
    if (current != null && !current.isAll) {
      return const HomePage();
    }

    final slicesAsync = ref.watch(slicesProvider);
    final savedAsync = ref.watch(savedSliceIdProvider);
    if (slicesAsync.isLoading || savedAsync.isLoading) {
      return const Scaffold(body: AsyncLoadingView());
    }
    if (slicesAsync.hasError) {
      return Scaffold(
        appBar: AppBar(
          title: Text('MTG Статистика', style: AppTheme.appBarTitle),
          backgroundColor: AppTheme.appBarBackground,
          foregroundColor: AppTheme.appBarForeground,
        ),
        body: AsyncErrorView(
          message: 'Не удалось загрузить разрезы.\n${slicesAsync.error}',
          onRetry: () => ref.invalidate(slicesProvider),
        ),
      );
    }

    final slices = slicesAsync.asData?.value ?? const <Slice>[];
    final savedId = savedAsync.asData?.value;
    // Авто-вход только из «чистого» состояния (разрез не выбран). Если уже в
    // режиме «Все разрезы» (current != null), не выкидываем из него.
    if (current == null && savedId != null) {
      Slice? match;
      for (final s in slices) {
        if (s.id == savedId) {
          match = s;
          break;
        }
      }
      if (match != null) {
        final selected = match;
        // Авто-вход в последний выбранный разрез.
        Future.microtask(
          () => ref.read(currentSliceProvider.notifier).select(selected),
        );
        return const Scaffold(body: AsyncLoadingView());
      }
    }

    return const SlicePickerPage();
  }
}

/// Экран выбора разреза: список разрезов, вход в приложение, управление (админ).
class SlicePickerPage extends ConsumerWidget {
  const SlicePickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slicesAsync = ref.watch(slicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Выбор разреза', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        elevation: 4,
        actions: [
          if (ApiConfig.isAdmin)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Управление разрезами',
              onPressed: () => Navigator.pushNamed(context, '/slices/manage'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: () => ref.invalidate(slicesProvider),
          ),
          IconButton(
            icon: Icon(
              ApiConfig.isLoggedIn ? Icons.person : Icons.login,
              color: AppTheme.appBarForeground,
            ),
            tooltip: ApiConfig.isLoggedIn
                ? 'Настройки (${ApiConfig.currentUserName})'
                : 'Войти',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: slicesAsync.when(
        loading: () => const AsyncLoadingView(),
        error: (error, _) => AsyncErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(slicesProvider),
        ),
        data: (slices) {
          if (slices.isEmpty) {
            return const Center(
              child: Text(
                'Разрезы не найдены. Проверьте подключение к серверу.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _AllGamesButtons(),
              const Divider(height: 28),
              ...slices.map((s) => _SliceCard(slice: s)),
            ],
          );
        },
      ),
    );
  }
}

/// Кнопки сводного режима «по всем играм»: история и статистика по всем разрезам.
class _AllGamesButtons extends ConsumerWidget {
  const _AllGamesButtons();

  /// Включает псевдо-разрез «Все разрезы» и открывает нужный экран.
  void _open(BuildContext context, WidgetRef ref, String route) {
    ref.read(currentSliceProvider.notifier).select(Slice.all());
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        HomeButton(
          text: 'ИСТОРИЯ ИГР',
          icon: Icons.history,
          onPressed: () => _open(context, ref, '/games/history'),
        ),
        const SizedBox(height: 20),
        HomeButton(
          text: 'СТАТИСТИКА',
          icon: Icons.bar_chart,
          onPressed: () => _open(context, ref, '/stats'),
        ),
      ],
    );
  }
}

class _SliceCard extends ConsumerWidget {
  const _SliceCard({required this.slice});

  final Slice slice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = slice.themeColor ?? AppTheme.appBarBackground;
    final poolLabel = slice.isDefault
        ? 'Все колоды'
        : 'Колод в пуле: ${slice.deckIds.length}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(
            slice.isDefault ? Icons.public : Icons.dashboard_customize,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          slice.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        subtitle: Text('$poolLabel • Игр: ${slice.gamesCount}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ref.read(currentSliceProvider.notifier).select(slice),
      ),
    );
  }
}
