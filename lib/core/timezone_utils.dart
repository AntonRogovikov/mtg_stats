/// Утилиты конвертации UTC-времени в настроенный timezone по offset в минутах.
abstract class TimezoneUtils {
  static DateTime toConfiguredTimezone(
    DateTime source, {
    required int timezoneOffsetMinutes,
  }) {
    final utc = source.isUtc ? source : source.toUtc();
    return utc.add(Duration(minutes: timezoneOffsetMinutes));
  }
}
