import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_stats/core/deck_draw.dart';
import 'package:mtg_stats/models/game.dart';

Game _game(String id, DateTime startTime, List<int> deckIds) => Game(
      id: id,
      startTime: startTime,
      turnLimitSeconds: 0,
      firstMoveTeam: 1,
      players: [
        for (final deckId in deckIds)
          GamePlayer(
            userId: 'u$deckId',
            userName: 'u$deckId',
            deckName: 'd$deckId',
            deckId: deckId,
          ),
      ],
    );

void main() {
  group('deckWeight', () {
    test('колода без игр имеет максимальный вес 1.0', () {
      expect(deckWeight(0), 1.0);
    });

    test('вес падает с ростом числа игр', () {
      expect(deckWeight(1), closeTo(0.5, 1e-9));
      expect(deckWeight(4), closeTo(0.2, 1e-9));
    });

    test('вес не опускается ниже минимального порога', () {
      // 1/(1+100) = ~0.0099 < 0.15 → срабатывает пол.
      expect(deckWeight(100), kMinDeckWeight);
      expect(deckWeight(1000), kMinDeckWeight);
    });

    test('чем реже игралась колода, тем выше её вес (монотонность)', () {
      for (var g = 0; g < 20; g++) {
        expect(deckWeight(g) >= deckWeight(g + 1), isTrue);
      }
    });
  });

  group('positionFromSum (считалочка «по кругу»)', () {
    test('примеры из ТЗ', () {
      expect(positionFromSum(20, 15), 5);
      expect(positionFromSum(40, 3), 1);
      expect(positionFromSum(15, 15), 15);
    });

    test('сумма, кратная числу колод, попадает в последнюю позицию, а не в 0',
        () {
      expect(positionFromSum(15, 15), 15);
      expect(positionFromSum(30, 15), 15);
      expect(positionFromSum(6, 3), 3);
    });

    test('результат всегда в диапазоне 1..n', () {
      for (var n = 1; n <= 24; n++) {
        for (var sum = kMinDiceSum; sum <= kMaxDiceSum; sum++) {
          final pos = positionFromSum(sum, n);
          expect(pos, inInclusiveRange(1, n));
        }
      }
    });
  });

  group('diceForSum (раскладка суммы на два d20)', () {
    test('оба кубика в диапазоне 1..20 и в сумме дают исходное число', () {
      final rnd = Random(1);
      for (var sum = kMinDiceSum; sum <= kMaxDiceSum; sum++) {
        for (var i = 0; i < 200; i++) {
          final dice = diceForSum(sum, rnd);
          expect(dice, hasLength(2));
          expect(dice[0], inInclusiveRange(1, 20));
          expect(dice[1], inInclusiveRange(1, 20));
          expect(dice[0] + dice[1], sum);
        }
      }
    });

    test('крайние суммы раскладываются однозначно', () {
      final rnd = Random(2);
      expect(diceForSum(2, rnd), [1, 1]);
      expect(diceForSum(40, rnd), [20, 20]);
    });
  });

  group('sumForPosition + consistency (сердце фиолетовой кнопки)', () {
    test('подобранная сумма по считалочке ведёт к той же позиции — для всех n,k',
        () {
      final rnd = Random(7);
      for (var n = 1; n <= 24; n++) {
        for (var k = 1; k <= n; k++) {
          for (var attempt = 0; attempt < 30; attempt++) {
            final sum = sumForPosition(k, n, rnd);
            expect(sum, inInclusiveRange(kMinDiceSum, kMaxDiceSum));
            // Ключевое свойство: показанная сумма честно ведёт к колоде k.
            expect(positionFromSum(sum, n), k);
          }
        }
      }
    });
  });

  group('pickIndexByWeight (взвешенная рулетка)', () {
    test('пустой список весов → -1', () {
      expect(pickIndexByWeight([], Random(0)), -1);
    });

    test('единственный элемент всегда выбирается', () {
      final rnd = Random(0);
      for (var i = 0; i < 100; i++) {
        expect(pickIndexByWeight([0.7], rnd), 0);
      }
    });

    test('индекс всегда в границах списка', () {
      final rnd = Random(3);
      final weights = [1.0, 0.5, 0.15, 0.15];
      for (var i = 0; i < 1000; i++) {
        expect(pickIndexByWeight(weights, rnd), inInclusiveRange(0, 3));
      }
    });

    test('нулевые веса не роняют выбор и держатся в границах', () {
      final rnd = Random(4);
      for (var i = 0; i < 100; i++) {
        expect(pickIndexByWeight([0.0, 0.0], rnd), inInclusiveRange(0, 1));
      }
    });

    test('колода с бóльшим весом выпадает чаще пропорционально весу', () {
      final rnd = Random(42);
      const trials = 100000;
      final weights = [3.0, 1.0]; // ожидаем ~75% / ~25%
      var countZero = 0;
      for (var i = 0; i < trials; i++) {
        if (pickIndexByWeight(weights, rnd) == 0) countZero++;
      }
      final share = countZero / trials;
      expect(share, closeTo(0.75, 0.02));
    });

    test('равные веса дают примерно равные доли', () {
      final rnd = Random(99);
      const trials = 90000;
      final counts = [0, 0, 0];
      for (var i = 0; i < trials; i++) {
        counts[pickIndexByWeight([1.0, 1.0, 1.0], rnd)]++;
      }
      for (final c in counts) {
        expect(c / trials, closeTo(1 / 3, 0.02));
      }
    });
  });

  group('recencyMultiplier (забытость)', () {
    test('никогда не игранная колода (null) → множитель 1.0', () {
      expect(recencyMultiplier(null), 1.0);
    });

    test('колода из последней сессии (0 дней) → множитель 1.0', () {
      expect(recencyMultiplier(0), 1.0);
    });

    test('множитель растёт с числом пропущенных дней', () {
      expect(recencyMultiplier(7), closeTo(1 + log(2), 1e-9)); // ~1.69
      expect(recencyMultiplier(14), closeTo(1 + log(3), 1e-9)); // ~2.10
      expect(recencyMultiplier(7) < recencyMultiplier(14), isTrue);
    });

    test('множитель никогда не превышает потолок 2.5', () {
      expect(recencyMultiplier(28), kMaxRecencyMultiplier);
      expect(recencyMultiplier(365), kMaxRecencyMultiplier);
      for (var d = 0; d <= 1000; d++) {
        expect(recencyMultiplier(d), lessThanOrEqualTo(kMaxRecencyMultiplier));
      }
    });
  });

  group('deckDrawWeight (база × забытость)', () {
    test('свежесыгранная колода = базовому весу (множитель 1.0)', () {
      expect(deckDrawWeight(10, 0), closeTo(deckWeight(10), 1e-9));
      expect(deckDrawWeight(10, null), closeTo(deckWeight(10), 1e-9));
    });

    test('забытая заигранная колода поднимается, но не обгоняет свежую новую',
        () {
      final forgotten = deckDrawWeight(10, 60); // заигранная, давно не бралась
      final brandNew = deckDrawWeight(0, null); // новая, вес 1.0
      expect(forgotten, greaterThan(deckWeight(10))); // поднялась над полом
      expect(forgotten, lessThan(brandNew)); // но новая всё равно приоритетнее
    });

    test('потолок забытости ограничивает итоговый вес заигранной колоды', () {
      // база 0.15 (пол) × кап 2.5 = 0.375, сколько бы ни забывали.
      expect(deckDrawWeight(100, 9999), closeTo(0.375, 1e-9));
    });
  });

  group('daysSinceLastPlayedByDeck (давность из истории игр)', () {
    test('пустая история → пустая карта', () {
      expect(daysSinceLastPlayedByDeck([]), isEmpty);
    });

    test('отсчёт идёт от последней сыгранной игры, а не от «сегодня»', () {
      // Последняя игра в истории — 2026-07-09. «Сегодня» намеренно не при чём.
      final games = [
        _game('1', DateTime(2026, 6, 4), [10]), // колода 10: месяц назад
        _game('2', DateTime(2026, 7, 9), [20]), // колода 20: последняя сессия
      ];
      final days = daysSinceLastPlayedByDeck(games);
      expect(days[20], 0); // играла в последнюю сессию
      expect(days[10], DateTime(2026, 7, 9).difference(DateTime(2026, 6, 4)).inDays);
    });

    test('неделя между играми даёт ровно 7 дней', () {
      final games = [
        _game('1', DateTime(2026, 7, 2, 20), [10]), // прошлый четверг вечером
        _game('2', DateTime(2026, 7, 9, 19), [20]), // этот четверг (чуть раньше)
      ];
      final days = daysSinceLastPlayedByDeck(games);
      expect(days[10], 7); // календарные дни, время суток не влияет
      expect(days[20], 0);
    });

    test('для колоды берётся её самая свежая игра', () {
      final games = [
        _game('1', DateTime(2026, 6, 1), [10]),
        _game('2', DateTime(2026, 7, 9), [10]), // она же, позже
      ];
      expect(daysSinceLastPlayedByDeck(games)[10], 0);
    });
  });
}
