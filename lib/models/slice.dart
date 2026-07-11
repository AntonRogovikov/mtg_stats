import 'package:flutter/material.dart';

/// Разрез статистики: именованный контекст с пулом колод и составом игроков.
/// Игры создаются внутри разреза и навсегда привязаны к нему.
class Slice {
  /// id псевдо-разреза «Все разрезы»: сводка по всем разрезам без фильтра.
  static const int allSliceId = 0;

  final int id;
  final String name;

  /// Цвет разреза в формате #RRGGBB; пусто — стандартная тема приложения.
  final String color;
  final bool isDefault;
  final List<int> deckIds;
  final List<int> playerIds;
  final int gamesCount;

  /// true — псевдо-разрез «Все разрезы» (сводная статистика и история по всем
  /// разрезам). Не приходит с сервера, создаётся на клиенте.
  final bool isAll;

  const Slice({
    required this.id,
    required this.name,
    this.color = '',
    this.isDefault = false,
    this.deckIds = const [],
    this.playerIds = const [],
    this.gamesCount = 0,
    this.isAll = false,
  });

  /// Псевдо-разрез «Все разрезы»: только просмотр сводной статистики и истории.
  factory Slice.all() => const Slice(
        id: allSliceId,
        name: 'Все разрезы',
        isAll: true,
      );

  /// Цвет как [Color]; null — используем стандартную тему.
  Color? get themeColor {
    if (color.length != 7 || !color.startsWith('#')) return null;
    final value = int.tryParse(color.substring(1), radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  factory Slice.fromJson(Map<String, dynamic> json) {
    return Slice(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      deckIds: (json['deck_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      playerIds: (json['player_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      gamesCount: json['games_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'name': name,
        'color': color,
        'deck_ids': deckIds,
        'player_ids': playerIds,
      };
}
