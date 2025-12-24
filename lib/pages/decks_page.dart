import 'package:flutter/material.dart';
import 'dart:math';
import '../models/deck.dart'; // Импортируем модель

class DeckListPage extends StatefulWidget {
  const DeckListPage({super.key});

  @override
  State<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends State<DeckListPage> {
  // Используем модель Deck вместо Map
  List<Deck> decks = [
    Deck(name: 'Вампиры'),
    Deck(name: 'Ниндзя'),
    Deck(name: 'Саурон'),
    Deck(name: 'Легендарки'),
    Deck(name: 'Пятицветка'),
    Deck(name: 'Шрайны'),
  ];

  int _firstDiceValue = 1;
  int _secondDiceValue = 1;
  bool _isRolling = false;
  int? _selectedDeckIndex;
  final TextEditingController _manualSumController = TextEditingController();

  final Random _fastRandom = Random();
  Random? _secureRandom;
  bool _secureInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSecureRandom();
  }

  @override
  void dispose() {
    _manualSumController.dispose();
    super.dispose();
  }

  Future<void> _initializeSecureRandom() async {
    try {
      _secureRandom = Random.secure();
    } catch (e) {
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
      _selectedDeckIndex = null;
    });

    int rolls = 0;
    const int totalRolls = 8;
    const Duration rollInterval = Duration(milliseconds: 100);

    void performRoll() {
      if (rolls < totalRolls) {
        setState(() {
          _firstDiceValue = _fastRandom.nextInt(20) + 1;
          _secondDiceValue = _fastRandom.nextInt(20) + 1;
        });
        rolls++;
        Future.delayed(rollInterval, performRoll);
      } else {
        setState(() {
          _performFinalRoll();
        });
      }
    }

    performRoll();
  }

  void _performFinalRoll() {
    Future.delayed(Duration(milliseconds: 50), () {
      if (_secureRandom != null) {
        setState(() {
          _firstDiceValue = _secureRandom!.nextInt(20) + 1;
        });

        Future.delayed(Duration(milliseconds: 30), () {
          setState(() {
            _secondDiceValue = _secureRandom!.nextInt(20) + 1;
            _isRolling = false;
            _calculateSelectedDeck();
          });
        });
      } else {
        setState(() {
          _firstDiceValue = _fastRandom.nextInt(20) + 1;
          _secondDiceValue = _fastRandom.nextInt(20) + 1;
          _isRolling = false;
          _calculateSelectedDeck();
        });
      }
    });
  }

  void _calculateSelectedDeck() {
    final sum = _firstDiceValue + _secondDiceValue;
    _selectDeckBySum(sum);
  }

  void _selectDeckBySum(int sum) {
    if (decks.isNotEmpty) {
      int index = (sum - 1) % decks.length;
      setState(() {
        _selectedDeckIndex = index;
      });
    }
  }

  void _manualSumInput() {
    String? errorText;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Введите сумму'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Диапазон: от 2 до 40'),
                  SizedBox(height: 10),
                  TextField(
                    controller: _manualSumController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Число от 2 до 40',
                      border: OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        try {
                          final sum = int.parse(value);
                          if (sum < 2 || sum > 40) {
                            setState(() {
                              errorText = 'Допустимый диапазон: 2-40';
                            });
                          } else {
                            setState(() {
                              errorText = null;
                            });
                          }
                        } catch (e) {
                          setState(() {
                            errorText = 'Введите целое число';
                          });
                        }
                      } else {
                        setState(() {
                          errorText = null;
                        });
                      }
                    },
                    onSubmitted: (value) {
                      if (errorText == null && value.isNotEmpty) {
                        _processManualInput();
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Отмена'),
                ),
                TextButton(
                  onPressed:
                      errorText == null && _manualSumController.text.isNotEmpty
                      ? () {
                          _processManualInput();
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _processManualInput() {
    final text = _manualSumController.text;
    if (text.isNotEmpty) {
      try {
        final sum = int.parse(text);
        if (sum >= 2 && sum <= 40) {
          setState(() {
            _firstDiceValue = min(20, sum ~/ 2);
            _secondDiceValue = sum - _firstDiceValue;
            if (_secondDiceValue > 20) {
              _secondDiceValue = 20;
              _firstDiceValue = sum - 20;
            }
            _selectedDeckIndex = null;
            _selectDeckBySum(sum);
          });
        }
      } catch (e) {}
    }
  }

  void _shuffleDecks() {
    if (!_secureInitialized) return;

    setState(() {
      if (_secureRandom != null) {
        // Используем алгоритм Фишера-Йетса для списка Deck
        for (int i = decks.length - 1; i > 0; i--) {
          int j = _secureRandom!.nextInt(i + 1);
          Deck temp = decks[i];
          decks[i] = decks[j];
          decks[j] = temp;
        }
        _selectedDeckIndex = null;
      } else {
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

  Widget _buildDiceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.blueGrey[50],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _diceDisplay('Кубик 1', _firstDiceValue),
              SizedBox(width: 20),
              _diceDisplay('Кубик 2', _secondDiceValue),
            ],
          ),
          SizedBox(height: 20),
          _buildSumDisplay(),
          SizedBox(height: 10),
          _buildControlButtons(),
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
                key: ValueKey<int>(value),
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

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConstrainedBox(
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
        ),
        SizedBox(width: 10),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: 0, minHeight: 56),
          child: ElevatedButton(
            onPressed: _isRolling ? null : _manualSumInput,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Icon(Icons.edit, size: 20),
          ),
        ),
      ],
    );
  }

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
          Text(
            'Всего колод: ${decks.length}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
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
          Deck deck = entry.value;
          return _cube(
            deck.name,
            index,
          ); // Используем deck.name вместо deck['name']
        }).toList(),
      ),
    );
  }

  Widget _cube(String name, int index) {
    final bool isSelected = index == _selectedDeckIndex;

    return GestureDetector(
      onTap: () {
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

  Widget _buildSelectionInfo() {
    if (_selectedDeckIndex == null) return SizedBox.shrink();

    final deckName = decks[_selectedDeckIndex!].name; // Используем deck.name

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
