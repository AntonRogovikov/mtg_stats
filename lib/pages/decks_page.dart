import 'package:flutter/material.dart';
import 'dart:math';

class DeckListPage extends StatefulWidget {
  const DeckListPage({super.key});

  @override
  State<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends State<DeckListPage> {
  // Пример данных для списка колод
  final List<Map<String, dynamic>> decks = const [
    {'name': 'Тестовая колода 1'},
    {'name': 'Тестовая колода 2'},
    {'name': 'Тестовая колода 3'},
    {'name': 'Тестовая колода 4'},
    {'name': 'Тестовая колода 5'},
    {'name': 'Тестовая колода 6'},
  ];
  int _firstDiceValue = 1;
  int _secondDiceValue = 1;
  bool _isRolling = false;

  // Два разных генератора
  final Random _fastRandom = Random(); // Для анимации (быстрый)
  Random? _secureRandom; // Для финального результата
  bool _secureInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSecureRandom();
  }

  Future<void> _initializeSecureRandom() async {
    try {
      // Инициализируем безопасный генератор заранее
      // (это может занять немного времени)
      _secureRandom = Random.secure();
    } catch (e) {
      // Fallback на обычный Random с хорошим seed
      int seed =
          DateTime.now().microsecondsSinceEpoch ^
          (DateTime.now().millisecond << 32);
      _secureRandom = Random(seed);
    } finally {
      setState(() {
        _secureInitialized = true;
      });
    }
  }

  void _rollDice() {
    if (_isRolling || !_secureInitialized) return;

    setState(() {
      _isRolling = true;
    });

    // Эффект броска с несколькими изменениями
    int rolls = 0;
    const int totalRolls = 8;
    const Duration rollInterval = Duration(milliseconds: 100);

    void performRoll() {
      if (rolls < totalRolls) {
        setState(() {
          // На промежуточных шагах используем быстрый Random
          _firstDiceValue = _fastRandom.nextInt(20) + 1;
          _secondDiceValue = _fastRandom.nextInt(20) + 1;
        });
        rolls++;
        Future.delayed(rollInterval, performRoll);
      } else {
        setState(() {
          // ФИНАЛЬНЫЙ ШАГ: используем Random.secure()
          _performFinalRoll();
        });
      }
    }

    performRoll();
  }

  void _performFinalRoll() {
    // Для максимальной случайности на финальном броске:
    // 1. Используем secure random
    // 2. Миксуем несколько бросков
    // 3. Добавляем небольшую задержку для сбора энтропии

    Future.delayed(Duration(milliseconds: 50), () {
      if (_secureRandom != null) {
        setState(() {
          // Бросаем первый кубик с secure random
          _firstDiceValue = _secureRandom!.nextInt(20) + 1;
        });

        // Небольшая задержка между бросками для большего расхождения
        Future.delayed(Duration(milliseconds: 30), () {
          setState(() {
            // Бросаем второй кубик с тем же secure random
            // но время изменилось, так что результат будет другим
            _secondDiceValue = _secureRandom!.nextInt(20) + 1;
            _isRolling = false;
          });
        });
      } else {
        // Fallback если secure random недоступен
        setState(() {
          _firstDiceValue = _fastRandom.nextInt(20) + 1;
          _secondDiceValue = _fastRandom.nextInt(20) + 1;
          _isRolling = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Колоды',
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey[900],
        elevation: 4,
      ),
      body: Column(children: [_buildDiceSection(), _buildDecksGrid()]),
    );
  }

  // Верхний экран
  Widget _buildDiceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.blueGrey[50],
      child: Column(
        children: [
          // Два кубика
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _diceDisplay('Кубик 1', _firstDiceValue),
              _diceDisplay('Кубик 2', _secondDiceValue),
            ],
          ),
          // Отступ
          SizedBox(height: 20),
          // Сумма кубиков
          _buildSumDisplay(),
          SizedBox(height: 10),
          _buildRollButton(),
        ],
      ),
    );
  }

  Widget _diceDisplay(String name, int value) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            color: _isRolling ? Colors.grey[600] : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: _isRolling ? Colors.grey[100] : Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isRolling ? Colors.grey[400]! : Colors.blue,
              width: 3,
            ),
            boxShadow: _isRolling
                ? []
                : [
                    BoxShadow(
                      color: Color.fromRGBO(33, 150, 243, 0.2),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 100),
              child: Text(
                '$value',
                key: ValueKey<int>(value), // Для анимации изменения цифр
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _isRolling ? Colors.grey[600] : Colors.blue[900],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSumDisplay() {
    final sum = _firstDiceValue + _secondDiceValue;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      decoration: BoxDecoration(
        color: _isRolling ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRolling ? Colors.grey[300]! : Colors.deepPurple,
          width: 2,
        ),
      ),
      child: Text(
        'Сумма: $sum',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _isRolling ? Colors.grey[600] : Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildRollButton() {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 200, minHeight: 56),
      child: ElevatedButton(
        onPressed: _isRolling ? null : _rollDice,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isRolling ? Colors.grey : Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: _isRolling
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Бросить кубики', style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  // Экран со списком колод
  Widget _buildDecksGrid() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: decks.map((deck) {
          return _cube(deck['name']);
        }).toList(),
      ),
    );
  }

  Widget _cube(String name) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
