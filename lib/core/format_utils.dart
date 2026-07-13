/// Утилиты форматирования для отображения в UI.
abstract class FormatUtils {
  /// Форматирует Duration в виде MM:SS или HH:MM:SS (для таймеров).
  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Форматирует Duration в человекочитаемый вид (например, "5 мин. 30 сек.").
  static String formatDurationHuman(Duration d) {
    final totalSec = d.inSeconds;
    if (totalSec == 0) return '';

    if (totalSec >= 3600) {
      final hours = d.inHours;
      final min = (totalSec % 3600) ~/ 60;
      return min > 0 ? '$hours ч. $min мин.' : '$hours ч.';
    }

    final min = d.inMinutes;
    final sec = totalSec % 60;

    if (min > 0 && sec > 0) return '$min мин. $sec сек.';

    String secWord(int n) {
      final mod10 = n % 10;
      final mod100 = n % 100;
      if (mod10 == 1 && mod100 != 11) {
        return 'секунда';
      }
      if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
        return 'секунды';
      }
      return 'секунд';
    }

    String minWord(int n) {
      final mod10 = n % 10;
      final mod100 = n % 100;
      if (mod10 == 1 && mod100 != 11) {
        return 'минута';
      }
      if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
        return 'минуты';
      }
      return 'минут';
    }

    if (min == 0) return '$totalSec ${secWord(totalSec)}';
    return '$min ${minWord(min)}';
  }

  static const _shortMonthsRu = [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  /// Форматирует дату в вид «9 июл 2026».
  static String formatDateRu(DateTime date) {
    return '${date.day} ${_shortMonthsRu[date.month - 1]} ${date.year}';
  }

  /// Склонение слова «день» по числу: 1 день, 2 дня, 5 дней.
  static String dayWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'день';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'дня';
    return 'дней';
  }

  /// Человекочитаемая давность в днях: «сегодня», «вчера», «N дней назад».
  static String daysAgoRu(int days) {
    if (days <= 0) return 'сегодня';
    if (days == 1) return 'вчера';
    return '$days ${dayWord(days)} назад';
  }
}
