import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/slice.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/services/slice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sliceServiceProvider = Provider<SliceService>((ref) {
  return SliceService(client: ref.watch(httpClientProvider));
});

/// Список разрезов с сервера: глобальный первым, далее по имени.
final slicesProvider = FutureProvider<List<Slice>>((ref) async {
  final sliceService = ref.watch(sliceServiceProvider);
  return sliceService.getSlices();
});

/// Текущий выбранный разрез. null — разрез ещё не выбран (экран выбора).
/// Выбор запоминается в SharedPreferences (в браузере — localStorage).
class CurrentSliceNotifier extends Notifier<Slice?> {
  static const String prefsKey = 'current_slice_id';

  @override
  Slice? build() => null;

  Future<void> select(Slice slice) async {
    state = slice;
    // Псевдо-разрез «Все разрезы» не запоминаем: при перезапуске возвращаемся
    // в последний реальный разрез, а не в сводный режим.
    if (slice.isAll) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefsKey, slice.id);
    } catch (_) {}
  }

  /// Выйти из разреза — вернуться на экран выбора.
  Future<void> clear() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey);
    } catch (_) {}
    // Сбрасываем кэш сохранённого id, иначе гейт снова автоматически
    // вернёт в только что покинутый разрез.
    ref.invalidate(savedSliceIdProvider);
  }

  /// Синхронизирует текущий разрез со свежим списком с сервера:
  /// подтягивает новые имя/цвет/пул, сбрасывает выбор, если разрез удалён.
  void refreshFrom(List<Slice> slices) {
    final current = state;
    if (current == null) return;
    // Псевдо-разреза «Все разрезы» нет в списке с сервера — не сбрасываем его.
    if (current.isAll) return;
    for (final s in slices) {
      if (s.id == current.id) {
        state = s;
        return;
      }
    }
    clear();
  }

  static Future<int?> savedSliceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(prefsKey);
    } catch (_) {
      return null;
    }
  }
}

final currentSliceProvider =
    NotifierProvider<CurrentSliceNotifier, Slice?>(CurrentSliceNotifier.new);

/// Сохранённый на устройстве id последнего выбранного разреза.
final savedSliceIdProvider = FutureProvider<int?>((ref) {
  return CurrentSliceNotifier.savedSliceId();
});

/// id текущего разреза для запросов к API; до выбора — глобальный (1).
final currentSliceIdProvider = Provider<int>((ref) {
  return ref.watch(currentSliceProvider)?.id ?? 1;
});

/// Колоды, которые в текущем разрезе нельзя выбрать. В «Все разрезы» пусто.
final currentSliceExcludedDeckIdsProvider = Provider<Set<int>>((ref) {
  final slice = ref.watch(currentSliceProvider);
  if (slice == null || slice.isAll) return const {};
  final slices = ref.watch(slicesProvider).asData?.value;
  if (slices != null) {
    for (final candidate in slices) {
      if (candidate.id == slice.id) return candidate.excludedDeckIds.toSet();
    }
  }
  return slice.excludedDeckIds.toSet();
});

/// Колоды, доступные в текущем разрезе.
/// В основном разрезе нет колод, которые уже входят в пул другого разреза.
/// В «Все разрезы» — весь справочник.
final slicePoolDecksProvider = FutureProvider<List<Deck>>((ref) async {
  final decks = await ref.watch(decksProvider.future);
  final slice = ref.watch(currentSliceProvider);
  if (slice == null || slice.isAll) return decks;

  final slices = await ref.watch(slicesProvider.future);
  if (slice.isDefault) {
    final taken = <int>{};
    for (final other in slices) {
      if (other.isDefault || other.isAll) continue;
      taken.addAll(other.deckIds);
    }
    return decks.where((d) => !taken.contains(d.id)).toList();
  }

  Slice source = slice;
  for (final candidate in slices) {
    if (candidate.id == slice.id) {
      source = candidate;
      break;
    }
  }
  final pool = source.deckIds.toSet();
  return decks.where((d) => pool.contains(d.id)).toList();
});
