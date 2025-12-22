import 'package:flutter/material.dart';
import 'dart:math';

class DeckListPage extends StatefulWidget {
  const DeckListPage({super.key});

  @override
  State<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends State<DeckListPage> {
  // Пример данных для списка колод
  List<Map<String, dynamic>> decks = const [
    {'name': 'Вампиры'},
    {'name': 'Ниндзя'},
    {'name': 'Саурон'},
    {'name': 'Легендарки'},
    {'name': 'Пятицветка'},
    {'name': 'Шрайны'},
  ];
  int _firstDiceValue = 1;
  int _secondDiceValue = 1;
  bool _isRolling = false;
  int? _selectedDeckIndex; // Индекс выбранной колоды

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
      _selectedDeckIndex = null; // Сбрасываем выбор колоды
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
            _secondDiceValue = _secureRandom!.nextInt(20) + 1;
            _isRolling = false;

            // После броска вычисляем выбранную колоду
            _calculateSelectedDeck();
          });
        });
      } else {
        // Fallback если secure random недоступен
        setState(() {
          _firstDiceValue = _fastRandom.nextInt(20) + 1;
          _secondDiceValue = _fastRandom.nextInt(20) + 1;
          _isRolling = false;
          _calculateSelectedDeck(); // Вычисляем выбранную колоду
        });
      }
    });
  }

  // Метод для вычисления выбранной колоды по сумме кубиков
  void _calculateSelectedDeck() {
    final sum = _firstDiceValue + _secondDiceValue;

    if (decks.isNotEmpty) {
      // Циклический расчет: (сумма - 1) % количество_колод
      // -1 потому что индексы начинаются с 0
      int index = (sum - 1) % decks.length;

      setState(() {
        _selectedDeckIndex = index;
      });
    }
  }

  // Метод для перемешивания колод
  void _shuffleDecks() {
    if (!_secureInitialized) return;

    setState(() {
      // Используем secure random для перемешивания
      if (_secureRandom != null) {
        // Создаем копию списка и перемешиваем
        List<Map<String, dynamic>> shuffledDecks = List.from(decks);

        // Алгоритм Фишера-Йетса (правильное перемешивание)
        for (int i = shuffledDecks.length - 1; i > 0; i--) {
          // Используем secure random для выбора случайного индекса
          int j = _secureRandom!.nextInt(i + 1);

          // Меняем местами элементы
          Map<String, dynamic> temp = shuffledDecks[i];
          shuffledDecks[i] = shuffledDecks[j];
          shuffledDecks[j] = temp;
        }

        decks = shuffledDecks;
        _selectedDeckIndex = null; // Сбрасываем выбор при перемешивании
      } else {
        // Fallback с обычным random
        decks.shuffle(_fastRandom);
        _selectedDeckIndex = null;
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
      body: Column(
        children: [
          _buildDiceSection(),
          _buildDecksHeader(),
          _buildDecksGrid(),
          _buildSelectionInfo(),
        ],
      ),
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
  Widget _buildDecksHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Информация о количестве колод
          Text(
            'Всего колод: ${decks.length}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
          // Кнопка перемешивания
          ElevatedButton.icon(
            onPressed: (_secureInitialized && !_isRolling)
                ? _shuffleDecks
                : null,
            icon: Icon(Icons.shuffle, size: 20),
            label: Text('Перемешать'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRolling
                  ? Colors.grey[400]
                  : Colors.amber[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecksGrid() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: decks.asMap().entries.map((entry) {
          int index = entry.key;
          var deck = entry.value;
          return _cube(deck['name'], index);
        }).toList(),
      ),
    );
  }

  Widget _cube(String name, int index) {
    final bool isSelected = index == _selectedDeckIndex;

    return GestureDetector(
      onTap: () {
        // Можно добавить возможность выбрать колоду вручную
        setState(() {
          _selectedDeckIndex = index;
        });
      },
      child: Card(
        elevation: isSelected ? 8 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
        ),
        child: Container(
          width: 100,
          height: 140,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/back_card.jpg'),
              fit: BoxFit.fill,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Виджет с информацией о выборе колоды
  Widget _buildSelectionInfo() {
    if (_selectedDeckIndex == null) return SizedBox.shrink();

    final deckName = decks[_selectedDeckIndex!]['name'];

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, color: Colors.green[800]),
          SizedBox(width: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Выбрана колода:',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(width: 10),
              Text(
                '«$deckName»',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
