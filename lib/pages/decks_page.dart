import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/pages/deck_card_page.dart';
import 'package:mtg_stats/pages/full_screen_image_page.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/services/deck_service.dart';
import 'package:mtg_stats/widgets/deck_card.dart';

/// Список колод: CRUD, кубики для выбора, открытие карточки колоды.
class DeckListPage extends StatefulWidget {
  const DeckListPage({super.key});

  @override
  State<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends State<DeckListPage> {
  List<Deck> decks = [];
  bool _isLoading = true;
  int? _selectedDeckIndex;
  late DeckService _deckService;

  int _firstDiceValue = 1;
  int _secondDiceValue = 1;
  bool _isRolling = false;
  final TextEditingController _manualSumController = TextEditingController();
  final Random _fastRandom = Random();
  Random? _secureRandom;
  bool _secureInitialized = false;
  bool _isDiceSectionVisible = false;

  final ScrollController _decksScrollController = ScrollController();
  bool _isMouseScrollDragging = false;
  double _scrollDragStartOffset = 0;
  double _scrollDragStartPosition = 0;

  final TextEditingController _searchController = TextEditingController();

  List<Deck> get _filteredDecks {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return decks;
    return decks
        .where((d) => d.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _deckService = DeckService();
    _initializeSecureRandom();
    _getAllDecks();
  }

  @override
  void dispose() {
    _manualSumController.dispose();
    _searchController.dispose();
    _decksScrollController.dispose();
    super.dispose();
  }

  Future<void> _getAllDecks() async {
    try {
      final loadedDecks = await _deckService.getAllDecks();
      setState(() {
        decks = loadedDecks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        decks = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке списка колод'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createDeck(String name) async {
    try {
      final newDeck = await _deckService.createDeck(name);
      if (mounted) {
        setState(() {
          decks.add(newDeck);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при добавлении колоды'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDeck(int id) async {
    try {
      await _deckService.deleteDeck(id);
      if (mounted) {
        setState(() {
          decks.removeWhere((deck) => deck.id == id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении колоды'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addDeckDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Новая колода'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Введите название колоды',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _createDeck(value.trim());
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  _createDeck(name);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    ).then((_) => nameController.dispose());
  }

  void _showDeleteDeckDialog(Deck deck) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Удалить колоду'),
          content: Text(
            'Вы уверены, что хотите удалить колоду "${deck.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                _deleteDeck(deck.id);
                Navigator.of(context).pop();
              },
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeSecureRandom() async {
    try {
      _secureRandom = Random.secure();
    } catch (e) {
      int seed = DateTime.now().microsecondsSinceEpoch ^
          (DateTime.now().millisecond << 32);
      _secureRandom = Random(seed);
    } finally {
      setState(() {
        _secureInitialized = true;
      });
    }
  }

  void _shuffleDecks() {
    if (!_secureInitialized) return;

    setState(() {
      if (_secureRandom != null) {
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
                  const Text('Диапазон: от 2 до 40'),
                  const SizedBox(height: 10),
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
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Колоды', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.appBarForeground),
            tooltip: 'Обновить список колод',
            onPressed: _isLoading ? null : () async {
              setState(() => _isLoading = true);
              await _getAllDecks();
            },
          ),
          IconButton(
            icon: Icon(
              _isDiceSectionVisible ? Icons.visibility_off : Icons.visibility,
              color: AppTheme.appBarForeground,
            ),
            onPressed: () {
              setState(() {
                _isDiceSectionVisible = !_isDiceSectionVisible;
              });
            },
          ),
        ],
      ),
      floatingActionButton: ApiConfig.isAdmin
          ? FloatingActionButton(
              onPressed: _addDeckDialog,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isDiceSectionVisible) _buildDiceSection(),
                _buildDecksHeader(),
                _buildSearchField(),
                if (decks.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        ApiConfig.isAdmin
                    ? 'Нет колод. Нажмите + чтобы добавить'
                    : 'Нет колод',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  )
                else if (_filteredDecks.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'Ничего не найдено',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  _buildDecksGrid(),
                if (_isDiceSectionVisible) _buildSelectionInfo(),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Поиск по названию колоды',
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: hasSearch
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDecksHeader() {
    final filteredCount = _filteredDecks.length;
    final isSearching = _searchController.text.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isSearching
                ? 'Найдено: $filteredCount'
                : 'Всего колод: ${decks.length}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
          ElevatedButton.icon(
            onPressed:
                (_secureInitialized && !_isRolling) ? _shuffleDecks : null,
            icon: Icon(Icons.shuffle, size: 20),
            label: Text('Перемешать'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isRolling ? Colors.grey[400] : Colors.amber[700],
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

  Widget _buildDecksGrid() {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _getAllDecks,
        child: Listener(
          onPointerDown: (PointerDownEvent e) {
          if (e.kind == PointerDeviceKind.mouse && e.buttons == 1) {
            setState(() {
              _isMouseScrollDragging = true;
              _scrollDragStartOffset = _decksScrollController.offset;
              _scrollDragStartPosition = e.position.dy;
            });
          }
        },
        onPointerMove: (PointerMoveEvent e) {
          if (_isMouseScrollDragging && e.kind == PointerDeviceKind.mouse) {
            if (!_decksScrollController.hasClients) return;
            final delta = e.position.dy - _scrollDragStartPosition;
            _scrollDragStartPosition = e.position.dy;
            final maxExtent = _decksScrollController.position.maxScrollExtent;
            final newOffset = (_scrollDragStartOffset + delta)
                .clamp(0.0, maxExtent);
            _decksScrollController.jumpTo(newOffset);
            _scrollDragStartOffset = newOffset;
          }
        },
        onPointerUp: (PointerUpEvent e) {
          if (e.kind == PointerDeviceKind.mouse) {
            setState(() => _isMouseScrollDragging = false);
          }
        },
        onPointerCancel: (PointerCancelEvent e) {
          setState(() => _isMouseScrollDragging = false);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: GridView.builder(
            controller: _decksScrollController,
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              crossAxisSpacing: 20,
              mainAxisSpacing: 10,
              childAspectRatio: 0.63,
            ),
            itemCount: _filteredDecks.length,
            itemBuilder: (context, index) {
              final deck = _filteredDecks[index];
              final isSelected = _selectedDeckIndex != null &&
                  _selectedDeckIndex! < decks.length &&
                  decks[_selectedDeckIndex!].id == deck.id;
              return DeckCard(
                key: ValueKey<int>(deck.id),
                deck: deck,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedDeckIndex = decks.indexWhere((d) => d.id == deck.id);
                  });
                },
                onLongPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImagePage(
                        imagePathOrUrl: deck.imageUrl ?? deck.avatarUrl,
                        assetFallback: AppConstants.defaultDeckImageAsset,
                      ),
                    ),
                  );
                },
                onMenuTap: () => _showDeckOptions(deck),
              );
            },
          ),
        ),
        ),
      ),
    );
  }

  void _showDeckOptions(Deck deck) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.badge, color: Colors.blue),
                title: Text('Открыть'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push<Deck>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeckCardPage(
                        deck: deck,
                        deckService: _deckService,
                        readOnly: !ApiConfig.isAdmin,
                      ),
                    ),
                  ).then((updated) async {
                    if (updated != null && mounted) {
                      final index = decks.indexWhere((d) => d.id == updated.id);
                      if (index != -1) {
                        setState(() => decks[index] = updated);
                      }
                      // Перезагрузка с сервера, чтобы подтянуть обновлённое изображение и остальные поля
                      await _getAllDecks();
                    }
                  });
                },
              ),
              if (ApiConfig.isAdmin)
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Удалить'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteDeckDialog(deck);
                  },
                ),
              ListTile(
                leading: Icon(Icons.close),
                title: Text('Отмена'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionInfo() {
    if (_selectedDeckIndex == null || _selectedDeckIndex! >= decks.length) {
      return const SizedBox.shrink();
    }

    final deckName = decks[_selectedDeckIndex!].name;

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
