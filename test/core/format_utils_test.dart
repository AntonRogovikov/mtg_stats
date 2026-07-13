import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_stats/core/format_utils.dart';

void main() {
  group('FormatUtils.formatDuration', () {
    test('formats mm:ss for durations below one hour', () {
      final value = FormatUtils.formatDuration(
        const Duration(minutes: 5, seconds: 7),
      );
      expect(value, '05:07');
    });

    test('formats hh:mm:ss for durations one hour and above', () {
      final value = FormatUtils.formatDuration(
        const Duration(hours: 2, minutes: 3, seconds: 4),
      );
      expect(value, '02:03:04');
    });
  });

  group('FormatUtils.formatDurationHuman', () {
    test('returns empty string for zero duration', () {
      expect(FormatUtils.formatDurationHuman(Duration.zero), '');
    });

    test('formats hours and minutes', () {
      final value = FormatUtils.formatDurationHuman(
        const Duration(hours: 1, minutes: 15),
      );
      expect(value, '1 ч. 15 мин.');
    });

    test('formats minute and seconds', () {
      final value = FormatUtils.formatDurationHuman(
        const Duration(minutes: 2, seconds: 8),
      );
      expect(value, '2 мин. 8 сек.');
    });
  });

  group('FormatUtils.formatDateRu', () {
    test('форматирует дату как «день месяц год»', () {
      expect(FormatUtils.formatDateRu(DateTime(2026, 7, 9)), '9 июл 2026');
      expect(FormatUtils.formatDateRu(DateTime(2026, 1, 31)), '31 янв 2026');
      expect(FormatUtils.formatDateRu(DateTime(2025, 12, 1)), '1 дек 2025');
    });
  });

  group('FormatUtils.daysAgoRu', () {
    test('сегодня и вчера', () {
      expect(FormatUtils.daysAgoRu(0), 'сегодня');
      expect(FormatUtils.daysAgoRu(-5), 'сегодня');
      expect(FormatUtils.daysAgoRu(1), 'вчера');
    });

    test('склонение слова «день»', () {
      expect(FormatUtils.daysAgoRu(2), '2 дня назад');
      expect(FormatUtils.daysAgoRu(5), '5 дней назад');
      expect(FormatUtils.daysAgoRu(11), '11 дней назад');
      expect(FormatUtils.daysAgoRu(21), '21 день назад');
      expect(FormatUtils.daysAgoRu(22), '22 дня назад');
    });
  });
}
