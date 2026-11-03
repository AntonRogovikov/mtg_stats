import 'dart:math';

import 'package:mtg_stats/models/game.dart';

/// Чистая логика жеребьёвки колод: веса по истории игр, взвешенный выбор,
/// считалочка «сумма кубиков → колода» и раскладка суммы на два d20.
///
/// Всё вынесено сюда без Flutter-зависимостей, чтобы:
///  * не дублировать одинаковый код на экранах «Колоды» и «Выбор колод»;
///  * покрыть логику юнит-тестами (см. `test/core/deck_draw_test.dart`).

/// Минимальный вес колоды: даже часто игранная колода сохраняет шанс выпасть.
const double kMinDeckWeight = 0.15;

/// Диапазон суммы двух двадцатигранников (d20 + d20).
const int kMinDiceSum = 2;
const int kMaxDiceSum = 40;

/// Характерный период «забытости» в днях (совпадает с ритмом игр — раз в неделю).
const int kRecencyPeriodDays = 7;

/// Потолок множителя забытости: колода, забытая надолго, не забирает весь шанс.
const double kMaxRecencyMultiplier = 2.5;

/// Базовый вес колоды по числу игр. Чем меньше сыграно игр — тем выше вес,
/// поэтому редкие колоды выпадают чаще (но не гарантированно).
double deckWeight(int gamesCount) {
  final weight = 1 / (1 + gamesCount);
  return weight < kMinDeckWeight ? kMinDeckWeight : weight;
}

/// Множитель «забытости»: чем дольше колода не появлялась, тем выше множитель —
/// мягко (логарифмически) и не выше [kMaxRecencyMultiplier].
///
/// [daysSinceLastPlayed] == null означает «колоду ни разу не играли»: множитель
/// равен 1.0, потому что такую колоду и так выделяет высокий базовый вес — она
/// не должна забирать весь шанс.
double recencyMultiplier(int? daysSinceLastPlayed) {
  if (daysSinceLastPlayed == null || daysSinceLastPlayed <= 0) return 1.0;
  final raw = 1 + log(1 + daysSinceLastPlayed / kRecencyPeriodDays);
  return raw > kMaxRecencyMultiplier ? kMaxRecencyMultiplier : raw;
}

/// Итоговый вес колоды для взвешенного выбора: база по числу игр, усиленная
/// множителем забытости. Используется только автовыбором (фиолетовая кнопка).
double deckDrawWeight(int gamesCount, int? daysSinceLastPlayed) {
  return deckWeight(gamesCount) * recencyMultiplier(daysSinceLastPlayed);
}

/// Давность последней игры каждой колоды в днях, отсчитанная от даты самой
/// свежей игры в истории (а не от «сегодня»): колода из последней сессии → 0.
/// Даты сравниваются по календарным дням, поэтому неделя между играми = 7.
/// Пустая история → пустая карта.
Map<int, int> daysSinceLastPlayedByDeck(List<Game> games) {
  final lastPlayed = <int, DateTime>{};
  for (final game in games) {
    final day = DateTime(
        game.startTime.year, game.startTime.month, game.startTime.day);
    for (final player in game.players) {
      final current = lastPlayed[player.deckId];
      if (current == null || day.isAfter(current)) {
        lastPlayed[player.deckId] = day;
      }
    }
  }
  if (lastPlayed.isEmpty) return const {};

  var reference = lastPlayed.values.first;
  for (final day in lastPlayed.values) {
    if (day.isAfter(reference)) reference = day;
  }
  return {
    for (final entry in lastPlayed.entries)
      entry.key: reference.difference(entry.value).inDays,
  };
}

/// Взвешенный выбор индекса методом рулетки. Возвращает индекс в [weights]
/// с вероятностью, пропорциональной весу. Для пустого списка возвращает -1.
int pickIndexByWeight(List<double> weights, Random rnd) {
  if (weights.isEmpty) return -1;
  final total = weights.fold<double>(0, (sum, w) => sum + w);
  // Все нули — выбирать некого (например, все колоды помечены). Не подменяем
  // это случайным индексом, иначе помеченная колода всё равно выпадет.
  if (total <= 0) return -1;

  var threshold = rnd.nextDouble() * total;
  for (var i = 0; i < weights.length; i++) {
    threshold -= weights[i];
    if (threshold <= 0) return i;
  }
  return weights.length - 1;
}

/// Считалочка «по кругу»: сумма кубиков → позиция колоды (1..n) среди [n]
/// доступных. Кратные [n] суммы аккуратно попадают в последнюю позицию.
int positionFromSum(int sum, int n) => ((sum - 1) % n) + 1;

/// Индексы колод, которые участвуют в считалочке. [blocked] — колоду пропускаем
/// (пометка «не выбирать» или её уже взял другой игрок).
List<int> selectableIndexes(List<bool> blocked) {
  final out = <int>[];
  for (var i = 0; i < blocked.length; i++) {
    if (!blocked[i]) out.add(i);
  }
  return out;
}

/// Индекс колоды в полном списке по сумме кубиков.
///
/// Считалочка идёт только по колодам без [blocked]: семёрка — это седьмая
/// доступная колода, а не седьмая строка полного списка. Если выбирать не из
/// чего, возвращает -1.
int indexFromSum(int sum, List<bool> blocked) {
  final selectable = selectableIndexes(blocked);
  if (selectable.isEmpty) return -1;
  final k = positionFromSum(sum, selectable.length);
  return selectable[k - 1];
}

/// Подбирает сумму в диапазоне [kMinDiceSum]..[kMaxDiceSum], которая по
/// считалочке даёт позицию [k] при [n] колодах. Из всех подходящих сумм
/// берётся случайная — чтобы анимация броска каждый раз была разной.
///
/// Если ни одной подходящей суммы нет (возможно только при n > 39, чего в
/// игре не бывает) — возвращается любая сумма из диапазона, как запасной путь.
int sumForPosition(int k, int n, Random rnd) {
  final candidates = <int>[];
  for (var s = kMinDiceSum; s <= kMaxDiceSum; s++) {
    if (positionFromSum(s, n) == k) candidates.add(s);
  }
  if (candidates.isEmpty) {
    return kMinDiceSum + rnd.nextInt(kMaxDiceSum - kMinDiceSum + 1);
  }
  return candidates[rnd.nextInt(candidates.length)];
}

/// Раскладывает сумму на два d20 (каждый 1..20) случайным допустимым образом.
/// Возвращает `[кубик1, кубик2]`, где `кубик1 + кубик2 == sum`.
List<int> diceForSum(int sum, Random rnd) {
  final lo = max(1, sum - 20);
  final hi = min(20, sum - 1);
  final d1 = lo + rnd.nextInt(hi - lo + 1);
  return [d1, sum - d1];
}
