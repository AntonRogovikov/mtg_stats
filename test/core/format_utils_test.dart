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
}
