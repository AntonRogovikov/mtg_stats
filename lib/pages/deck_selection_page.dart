import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/models/user.dart';
import 'package:mtg_stats/pages/deck_card_page.dart';
import 'package:mtg_stats/pages/deck_picker_page.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/providers/stats_providers.dart';
import 'package:mtg_stats/services/api_config.dart';

/// Экран выбора колод для игроков с двумя режимами: ручной и автовыбор.
/// В обоих режимах: бросить кубик, ввести вручную или выбрать из списка.
class DeckSelectionPage extends ConsumerStatefulWidget {
  final List<User> team1;
  final List<User> team2;
  final List<Deck> allDecks;
  final Map<String, Deck> initialUserDecks;

  const DeckSelectionPage({
    super.key,
    required this.team1,
    required this.team2,
    required this.allDecks,
    required this.initialUserDecks,
  });

  @override
  ConsumerState<DeckSelectionPage> createState() => _DeckSelectionPageState();
}

class _DeckSelectionPageState extends ConsumerState<DeckSelectionPage> {
  late List<User> _playerOrder;
  late List<Deck> _deckOrder;
  late Map<String, Deck> _userDecks;
  bool _isAutoMode = false;
  final Random _random = Random();

  /// Ручной режим: выбранный игрок.
  String? _selectedUserId;

  /// Авто режим: индекс текущего игрока в очереди.
  int _currentPlayerIndex = 0;

  /// Авто режим: сценарий выбора запущен (после «Начать выбор»).
  bool _autoSelectionStarted = false;

  /// Кубики и ручной ввод.
  int _firstDiceValue = 1;
  int _secondDiceValue = 1;
  bool _isRolling = false;
  final Random _fastRandom = Random();
  Random? _secureRandom;
  bool _secureInitialized = false;

  void _showWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }

  final TextEditingController _manualSumController = TextEditingController();

  List<User> get _allPlayers => [...widget.team1, ...widget.team2];

  User? get _currentTargetUser {
    if (_isAutoMode) {
      if (!_autoSelectionStarted ||
          _currentPlayerIndex >= _playerOrder.length) {
        return null;
      }
      return _playerOrder[_currentPlayerIndex];
    }
    if (_selectedUserId == null) return null;
    for (final u in _allPlayers) {
      if (u.id == _selectedUserId) return u;
    }
    return null;
  }

  bool get _allDecksSelected {
    for (final user in _allPlayers) {
      if (_userDecks[user.id] == null) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _userDecks = Map.from(widget.initialUserDecks);
    _playerOrder = List.from(_allPlayers);
    _deckOrder = List.from(widget.allDecks);
    _initializeSecureRandom();
    ref.read(statsDataProvider.future).catchError((_) => const StatsData(
          playerStats: [],
          deckStats: [],
        ));
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
      final seed = DateTime.now().microsecondsSinceEpoch ^
          (DateTime.now().millisecond << 32);
      _secureRandom = Random(seed);
    } finally {
      if (mounted) setState(() => _secureInitialized = true);
    }
  }

  void _startAutoSelection() {
    final shuffledPlayers = List<User>.from(_allPlayers)..shuffle(_random);
    setState(() {
      _userDecks.clear();
      _playerOrder = shuffledPlayers;
      _currentPlayerIndex = 0;
      _autoSelectionStarted = true;
    });
  }

  void _shuffleDecksForGame() {
    if (!_secureInitialized || _deckOrder.isEmpty) return;
    setState(() {
      if (_secureRandom != null) {
        final list = List<Deck>.from(_deckOrder);
        for (int i = list.length - 1; i > 0; i--) {
          final j = _secureRandom!.nextInt(i + 1);
          final temp = list[i];
          list[i] = list[j];
          list[j] = temp;
        }
        _deckOrder = list;
      } else {
        _deckOrder = List.from(_deckOrder)..shuffle(_random);
      }
    });
  }

  int _gamesCountForDeck(Deck deck) {
    final statsData = ref.read(statsDataProvider).asData?.value;
    if (statsData == null) return 0;
    for (final DeckStats deckStats in statsData.deckStats) {
      if (deckStats.deckId == deck.id) return deckStats.gamesCount;
    }
    return 0;
  }

  double _deckWeightFromHistory(Deck deck) {
    const minWeight = 0.15;
    final gamesCount = _gamesCountForDeck(deck);
    final weight = 1 / (1 + gamesCount);
    return weight < minWeight ? minWeight : weight;
  }

  Deck? _pickDeckByHistoryWeight(List<Deck> availableDecks) {
    if (availableDecks.isEmpty) return null;
    final totalWeight = availableDecks.fold<double>(
      0,
      (sum, deck) => sum + _deckWeightFromHistory(deck),
    );
    if (totalWeight <= 0) {
      return availableDecks[_fastRandom.nextInt(availableDecks.length)];
    }
    final rnd = _secureRandom ?? _fastRandom;
    var threshold = rnd.nextDouble() * totalWeight;
    for (final deck in availableDecks) {
      threshold -= _deckWeightFromHistory(deck);
      if (threshold <= 0) return deck;
    }
    return availableDecks.last;
  }

  void _selectDeckByHistoryWeight(User user) {
    if (_deckOrder.isEmpty) return;
    final takenDeckIds = _userDecks.entries
        .where((e) => e.key != user.id)
        .map((e) => e.value.id)
        .toSet();

    final availableDecks = _deckOrder
        .where((deck) => !takenDeckIds.contains(deck.id))
        .toList(growable: false);
    final deckToAssign = _pickDeckByHistoryWeight(availableDecks);

    if (deckToAssign == null) {
      _showWarning(
          'Все колоды уже выбраны. Освободите колоду или добавьте новую.');
      return;
    }

    setState(() {
      _userDecks[user.id] = deckToAssign;
      if (_isAutoMode) {
        if (_currentPlayerIndex >= _playerOrder.length - 1) {
          _autoSelectionStarted = false;
        } else {
          _currentPlayerIndex++;
        }
      }
    });
  }

  void _rollDiceForDeck(User user) {
    if (_isRolling || !_secureInitialized) return;

    setState(() => _isRolling = true);

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
        _performFinalRollForDeck(user);
      }
    }

    performRoll();
  }

  void _performFinalRollForDeck(User user) {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      if (_secureRandom != null) {
        setState(() {
          _firstDiceValue = _secureRandom!.nextInt(20) + 1;
        });

        Future.delayed(const Duration(milliseconds: 30), () {
          if (!mounted) return;
          setState(() {
            _secondDiceValue = _secureRandom!.nextInt(20) + 1;
            _isRolling = false;
          });
          _selectDeckByHistoryWeight(user);
        });
      } else {
        setState(() {
          _firstDiceValue = _fastRandom.nextInt(20) + 1;
          _secondDiceValue = _fastRandom.nextInt(20) + 1;
          _isRolling = false;
        });
        _selectDeckByHistoryWeight(user);
      }
    });
  }

  void _manualSumInput(User user) {
    String? errorText;
    _manualSumController.text = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Введите сумму для ${user.name}'),
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
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        try {
                          final sum = int.parse(value);
                          if (sum < 2 || sum > 40) {
                            setStateDialog(() {
                              errorText = 'Допустимый диапазон: 2-40';
                            });
                          } else {
                            setStateDialog(() {
                              errorText = null;
                            });
                          }
                        } catch (e) {
                          setStateDialog(() {
                            errorText = 'Введите целое число';
                          });
                        }
                      } else {
                        setStateDialog(() {
                          errorText = null;
                        });
                      }
                    },
                    onSubmitted: (value) {
                      if (errorText == null && value.isNotEmpty) {
                        final sum = int.tryParse(value);
                        if (sum != null && sum >= 2 && sum <= 40) {
                          _processManualSum(user, sum);
                          Navigator.of(context).pop();
                        }
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
                  onPressed: errorText == null &&
                          _manualSumController.text.isNotEmpty
                      ? () {
                          final sum = int.tryParse(_manualSumController.text);
                          if (sum != null && sum >= 2 && sum <= 40) {
                            _processManualSum(user, sum);
                            Navigator.of(context).pop();
                          }
                        }
                      : null,
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _processManualSum(User user, int sum) {
    setState(() {
      _firstDiceValue = min(20, sum ~/ 2);
      _secondDiceValue = sum - _firstDiceValue;
      if (_secondDiceValue > 20) {
        _secondDiceValue = 20;
        _firstDiceValue = sum - 20;
      }
    });
    _selectDeckByHistoryWeight(user);
  }

  void _openDeckPicker(User user) {
    final disabledDeckIds = <int>{};
    final disabledDeckIdToPlayerName = <int, String>{};
    final userById = {for (final u in _allPlayers) u.id: u};
    for (final e in _userDecks.entries) {
      if (e.key == user.id) continue;
      disabledDeckIds.add(e.value.id);
      final name = userById[e.key]?.name;
      if (name != null) disabledDeckIdToPlayerName[e.value.id] = name;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DeckPickerPage(
          userName: user.name,
          userId: user.id,
          decks: List.from(_deckOrder),
          disabledDeckIds: disabledDeckIds,
          disabledDeckIdToPlayerName: disabledDeckIdToPlayerName,
          selectedDeck: _userDecks[user.id],
          onDeckSelected: (deck) {
            setState(() {
              _userDecks[user.id] = deck;
              if (_isAutoMode) {
                if (_currentPlayerIndex >= _playerOrder.length - 1) {
                  _autoSelectionStarted = false;
                } else {
                  _currentPlayerIndex++;
                }
              }
            });
          },
        ),
      ),
    );
  }

  void _openDeckCard(Deck deck) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeckCardPage(
          deck: deck,
          deckService: ref.read(deckServiceProvider),
          readOnly: !ApiConfig.isAdmin,
        ),
      ),
    );
  }

  void _confirmAndReturn() {
    if (!_allDecksSelected) return;
    Navigator.of(context).pop(_userDecks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Выбор колод для игроков', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        elevation: 4,
      ),
      body: widget.allDecks.isEmpty
          ? _buildEmptyDecksMessage()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildModeSelector(),
                  const SizedBox(height: 24),
                  if (_isAutoMode) ...[
                    _buildAutoModeContent(),
                  ] else ...[
                    _buildManualModeContent(),
                  ],
                  const SizedBox(height: 24),
                  _buildAssignedDecksSummary(),
                  const SizedBox(height: 24),
                  _buildConfirmButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyDecksMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections_bookmark_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет доступных колод. Создайте колоды на экране "Колоды".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Режим выбора колод',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModeOption(
                    title: 'Ручной выбор',
                    subtitle: 'Выберите игрока, затем способ выбора колоды',
                    icon: Icons.touch_app,
                    isSelected: !_isAutoMode,
                    onTap: () => setState(() => _isAutoMode = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModeOption(
                    title: 'Автовыбор',
                    subtitle: 'Случайный порядок, по шагам для каждого',
                    icon: Icons.shuffle,
                    isSelected: _isAutoMode,
                    onTap: () {
                      setState(() {
                        _isAutoMode = true;
                        _autoSelectionStarted = false;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? Colors.blue.withValues(alpha: 0.15)
          : Colors.grey.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? Colors.blue[800] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreeButtons(User? targetUser) {
    if (targetUser == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          _isAutoMode ? 'Нажмите «Начать выбор» для старта' : 'Выберите игрока',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      );
    }

    final canAct = !_isRolling && _secureInitialized && _deckOrder.isNotEmpty;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isAutoMode)
                  Expanded(
                    child: Text(
                      '${targetUser.name} выбирает колоду:',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: Text(
                      'Выбор колоды',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: (_secureInitialized &&
                          !_isRolling &&
                          _deckOrder.isNotEmpty)
                      ? _shuffleDecksForGame
                      : null,
                  icon: const Icon(Icons.shuffle),
                  tooltip: 'Перемешать список колод',
                  color: Colors.amber[800],
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
            Center(child: _buildDiceDisplay()),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ElevatedButton.icon(
                      onPressed:
                          canAct ? () => _rollDiceForDeck(targetUser) : null,
                      icon: _isRolling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white70),
                              ),
                            )
                          : const Icon(Icons.casino, size: 18),
                      label: const Text('Бросить кубики',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canAct ? Colors.deepPurple : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton.icon(
                      onPressed:
                          canAct ? () => _manualSumInput(targetUser) : null,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Ввести вручную',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canAct ? Colors.amber[700] : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ElevatedButton.icon(
                      onPressed:
                          canAct ? () => _openDeckPicker(targetUser) : null,
                      icon: const Icon(Icons.collections_bookmark, size: 18),
                      label: const Text('Выбрать из списка',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canAct ? Colors.blueGrey[700] : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiceDisplay() {
    final sum = _firstDiceValue + _secondDiceValue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _diceDisplay('Кубик 1', _firstDiceValue, Colors.blue),
            _diceOperator('+'),
            _diceDisplay('Кубик 2', _secondDiceValue, Colors.blue),
            _diceOperator('='),
            _diceDisplay('Сумма', sum, Colors.deepPurple),
          ],
        ),
      ],
    );
  }

  Widget _diceOperator(String symbol) {
    return Column(
      children: [
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            symbol,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _diceDisplay(String label, int value, MaterialColor color) {
    final borderColor = color[900] ?? color;
    final backgroundColor = color[50] ?? color;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: _isRolling ? Colors.grey[600] : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _isRolling ? Colors.grey[100] : backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isRolling ? Colors.grey[400]! : color,
              width: 3,
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 100),
              child: Text(
                '$value',
                key: ValueKey<int>(value),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _isRolling ? Colors.grey[600]! : borderColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoModeContent() {
    final currentUser = _currentTargetUser;
    final showDiceBlock =
        _autoSelectionStarted && _currentPlayerIndex < _playerOrder.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Порядок выбора колод',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed:
                          _autoSelectionStarted ? null : _startAutoSelection,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Начать выбор'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: List.generate(_playerOrder.length, (index) {
                    final user = _playerOrder[index];
                    final isCurrent = index == _currentPlayerIndex;
                    final inTeam1 = widget.team1.contains(user);
                    final teamColor = inTeam1 ? Colors.blue : Colors.green;
                    return Chip(
                      avatar: _autoSelectionStarted
                          ? CircleAvatar(
                              backgroundColor: teamColor.withValues(alpha: 0.3),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: teamColor[800],
                                ),
                              ),
                            )
                          : null,
                      label: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: isCurrent
                          ? teamColor.withValues(alpha: 0.25)
                          : teamColor.withValues(alpha: 0.08),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (showDiceBlock) _buildThreeButtons(currentUser),
      ],
    );
  }

  Widget _buildManualModeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выберите игрока:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allPlayers.map((user) {
                    final isSelected = _selectedUserId == user.id;
                    final inTeam1 = widget.team1.contains(user);
                    final teamColor = inTeam1 ? Colors.blue : Colors.green;
                    return FilterChip(
                      label: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: isSelected,
                      onSelected: _isRolling
                          ? null
                          : (_) {
                              setState(() {
                                _selectedUserId = user.id;
                              });
                            },
                      selectedColor: teamColor.withValues(alpha: 0.2),
                      checkmarkColor: teamColor,
                      side:
                          BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildThreeButtons(_currentTargetUser),
      ],
    );
  }

  Widget _buildAssignedDecksSummary() {
    if (_userDecks.isEmpty) {
      return const SizedBox.shrink();
    }

    final userById = {for (final u in _allPlayers) u.id: u};
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Назначенные колоды:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _userDecks.entries.map((entry) {
                final user = userById[entry.key];
                final userName = user?.name ?? '?';
                final deck = entry.value;
                final inTeam1 = user != null && widget.team1.contains(user);
                final teamColor = inTeam1 ? Colors.blue : Colors.green;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: teamColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: teamColor.withValues(alpha: 0.3),
                        radius: 12,
                        child:
                            Icon(Icons.person, size: 16, color: teamColor[800]),
                      ),
                      const SizedBox(width: 8),
                      Text('$userName: '),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openDeckCard(deck),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text(
                              deck.name,
                              style: TextStyle(
                                color: Colors.blue[700],
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.blue[700],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _allDecksSelected ? _confirmAndReturn : null,
        icon: const Icon(Icons.check),
        label: Text(
          _allDecksSelected
              ? 'Подтвердить'
              : 'Выберите колоды для всех игроков (${_userDecks.length}/${_allPlayers.length})',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _allDecksSelected ? Colors.green[700] : Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
