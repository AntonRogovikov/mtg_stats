import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/pages/active_game_page.dart';
import 'package:mtg_stats/pages/deck_picker_page.dart';
import 'package:mtg_stats/services/deck_service.dart';
import 'package:mtg_stats/services/game_manager.dart';
import 'package:mtg_stats/services/game_service.dart';

/// Страница настройки новой партии: команды, первый ход, колоды игроков (кубики/ручной выбор).
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class User {
  final String id;
  final String name;

  User({
    required this.id,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

class _GamePageState extends State<GamePage> {
  final List<User> _users = [
    User(id: '1', name: 'Женя Козлов'),
    User(id: '2', name: 'Андрей Евглевский'),
    User(id: '3', name: 'Илья Сухачев'),
    User(id: '4', name: 'Антон Роговиков'),
  ];

  final Random _random = Random();
  final DeckService _deckService = DeckService();
  List<Deck> _allDecks = [];
  bool _isDecksLoading = true;
  bool _isDecksError = false;
  final Map<String, Deck> _userDecks = {};
  String? _selectedUserId;
  int _firstDiceValue = 1;
  int _secondDiceValue = 1;
  bool _isRolling = false;
  final Random _fastRandom = Random();
  Random? _secureRandom;
  bool _secureInitialized = false;
  final TextEditingController _manualSumController = TextEditingController();

  List<User> _team1 = [];
  List<User> _team2 = [];

  bool _teamsExpanded = false;

  int? _firstMoveTeam;
  bool _useTurnLimit = false;
  int _turnLimitSeconds = 300;

  final GameService _gameService = GameService();

  @override
  void initState() {
    super.initState();
    _selectedUserId = _users.first.id;
    _initializeSecureRandom();
    _getAllDecks();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (GameManager.instance.hasActiveGame) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ActiveGamePage(),
          ),
        );
        return;
      }
      try {
        final active = await _gameService.getActiveGame();
        if (mounted && active != null) {
          GameManager.instance.setActiveGameFromApi(active);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ActiveGamePage(),
            ),
          );
        } else if (mounted && GameManager.instance.hasActiveGame) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ActiveGamePage(),
            ),
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _manualSumController.dispose();
    super.dispose();
  }

  Future<void> _getAllDecks() async {
    setState(() {
      _isDecksLoading = true;
      _isDecksError = false;
    });

    try {
      final loadedDecks = await _deckService.getAllDecks();
      setState(() {
        _allDecks = loadedDecks;
        _isDecksLoading = false;
      });
    } catch (e) {
      setState(() {
        _allDecks = [];
        _isDecksLoading = false;
        _isDecksError = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при загрузке списка колод'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeSecureRandom() async {
    try {
      _secureRandom = Random.secure();
    } catch (e) {
      final seed = DateTime.now().microsecondsSinceEpoch ^
          (DateTime.now().millisecond << 32);
      _secureRandom = Random(seed);
    } finally {
      setState(() {
        _secureInitialized = true;
      });
    }
  }

  void _randomizeTeams() {
    setState(() {
      _team1.clear();
      _team2.clear();
      final usersCopy = List<User>.from(_users);
      usersCopy.shuffle(_random);
      for (int i = 0; i < usersCopy.length; i++) {
        if (i < 2) {
          _team1.add(usersCopy[i]);
        } else {
          _team2.add(usersCopy[i]);
        }
      }
    });
  }

  void _randomizeMoveFirst() {
    setState(() {
      _firstMoveTeam = _random.nextInt(2) + 1;
    });
  }

  Future<void> _startGame() async {
    if (GameManager.instance.hasActiveGame) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ActiveGamePage(),
        ),
      );
      return;
    }

    if (_team1.length != 2 || _team2.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Распределите по 2 игрока в каждую команду'),
        ),
      );
      return;
    }

    if (_firstMoveTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите команду, которая ходит первой'),
        ),
      );
      return;
    }

    for (final user in _users) {
      if (_userDecks[user.id] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Выберите колоду для игрока ${user.name}'),
          ),
        );
        return;
      }
    }
    final players = <GamePlayer>[];
    for (final user in _team1) {
      final deck = _userDecks[user.id]!;
      players.add(
        GamePlayer(
          userId: user.id,
          userName: user.name,
          deckName: deck.name,
          deckId: deck.id,
        ),
      );
    }
    for (final user in _team2) {
      final deck = _userDecks[user.id]!;
      players.add(
        GamePlayer(
          userId: user.id,
          userName: user.name,
          deckName: deck.name,
          deckId: deck.id,
        ),
      );
    }

    final turnLimit = _useTurnLimit ? _turnLimitSeconds : 0;
    final stubGame = Game(
      id: '',
      startTime: DateTime.now(),
      turnLimitSeconds: turnLimit,
      firstMoveTeam: _firstMoveTeam!,
      players: players,
    );

    try {
      final created = await _gameService.createGame(stubGame);
      if (!mounted) return;
      GameManager.instance.setActiveGameFromApi(created);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ActiveGamePage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось создать игру: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Новая партия',
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey[900],
        elevation: 4,
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _teamsExpanded = !_teamsExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Icon(
                            _teamsExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Распределение по командам',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                              onPressed: _randomizeTeams,
                              icon: const Icon(Icons.shuffle),
                              color: Colors.amber[800],
                              style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3))))
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    _buildTeamSection(
                        title: 'Команда 1',
                        teamNumber: 1,
                        selectedUsers: _team1),
                    const Divider(),
                    _buildTeamSection(
                        title: 'Команда 2',
                        teamNumber: 2,
                        selectedUsers: _team2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildFirstMoveSection(),
            const SizedBox(height: 32),
            _buildUserDeckSelectionSection(),
            const SizedBox(height: 32),
            _buildTurnSettingsSection(),
          ])),
    );
  }

  Widget _buildTeamSection(
      {required String title,
      required int teamNumber,
      required List<User> selectedUsers}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      if (_teamsExpanded) ...[
        const SizedBox(height: 5),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3,
          ),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            final isSelected = selectedUsers.contains(user);
            final isDisabled = !isSelected && !_canSelectUser(user, teamNumber);

            return FilterChip(
              label: Text(
                user.name,
                overflow: TextOverflow.ellipsis,
              ),
              padding: const EdgeInsets.all(20.0),
              selected: isSelected,
              onSelected: isDisabled
                  ? null
                  : (selected) {
                      setState(() {
                        if (isSelected) {
                          selectedUsers.remove(user);
                        } else if (selectedUsers.length < 2) {
                          selectedUsers.add(user);
                        }
                      });
                    },
              selectedColor: teamNumber == 1
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
              checkmarkColor: teamNumber == 1 ? Colors.blue : Colors.green,
              labelStyle: TextStyle(
                color: isDisabled ? Colors.grey : null,
              ),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            );
          },
        ),
      ],
      if (!_teamsExpanded)
        if (selectedUsers.isEmpty)
          const Text('Игроки не выбраны')
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: selectedUsers
                .map((user) => Chip(
                      label: Text(user.name),
                      backgroundColor: teamNumber == 1
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.green.withValues(alpha: 0.2),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          selectedUsers.remove(user);
                        });
                      },
                    ))
                .toList(),
          ),
    ]);
  }

  Widget _buildFirstMoveSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Text(
                    'Какая команда ходит первой?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                      onPressed: _randomizeMoveFirst,
                      icon: const Icon(Icons.shuffle),
                      color: Colors.amber[800],
                      style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3)))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTeamChoiceCard(
                  teamNumber: 1,
                  isSelected: _firstMoveTeam == 1,
                  color: Colors.blue.withValues(alpha: 0.6),
                ),
                _buildTeamChoiceCard(
                  teamNumber: 2,
                  isSelected: _firstMoveTeam == 2,
                  color: Colors.green.withValues(alpha: 0.6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnSettingsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Настройка времени хода',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _useTurnLimit,
              onChanged: (value) {
                setState(() {
                  _useTurnLimit = value ?? false;
                });
              },
              title: const Text('Использовать ограничение время хода'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_useTurnLimit) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Максимальное время хода (сек):'),
                  Text(
                    '$_turnLimitSeconds',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _turnLimitSeconds.toDouble().clamp(10, 300),
                min: 10,
                max: 300,
                divisions: 29,
                label: '$_turnLimitSeconds сек',
                onChanged: (value) {
                  setState(() {
                    _turnLimitSeconds = value.round();
                  });
                },
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Начать игру'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamChoiceCard({
    required int teamNumber,
    required bool isSelected,
    required Color color,
  }) {
    final teamMembers = teamNumber == 1 ? _team1 : _team2;
    String membersText = teamMembers.map((user) => user.name).join(', ');

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _firstMoveTeam = teamNumber;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isSelected ? color.withValues(alpha: 0.2) : Colors.grey[100],
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.group,
                  size: 40,
                  color: isSelected ? color : Colors.grey,
                ),
                const SizedBox(height: 5),
                Text(
                  'Команда $teamNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : Colors.grey,
                  ),
                ),
                if (teamMembers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      membersText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canSelectUser(User user, int teamNumber) {
    if (teamNumber == 1) {
      return !_team2.contains(user);
    } else {
      return !_team1.contains(user);
    }
  }

  Widget _buildUserDeckSelectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Выбор колоды для игроков',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: (_secureInitialized &&
                          !_isRolling &&
                          _allDecks.isNotEmpty)
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
            const SizedBox(height: 12),
            if (_isDecksLoading)
              const Center(child: CircularProgressIndicator())
            else if (_isDecksError || _allDecks.isEmpty)
              const Text(
                'Колоды недоступны. Проверьте подключение или создайте колоды на экране "Колоды".',
                style: TextStyle(color: Colors.redAccent),
              )
            else ...[
              _buildUserSelector(),
              const SizedBox(height: 16),
              _buildDeckDiceSection(),
              const SizedBox(height: 16),
              _buildUserDecksSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelector() {
    final orderedUsers = <User>[..._team1, ..._team2];
    for (final u in _users) {
      if (!orderedUsers.contains(u)) orderedUsers.add(u);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: orderedUsers.map((user) {
            final isSelected = _selectedUserId == user.id;
            final inTeam1 = _team1.contains(user);
            final inTeam2 = _team2.contains(user);
            final teamNumber = inTeam1 ? 1 : (inTeam2 ? 2 : null);
            return FilterChip(
              label: Text(
                user.name,
                overflow: TextOverflow.ellipsis,
              ),
              padding: const EdgeInsets.all(8.0),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedUserId = user.id;
                });
              },
              selectedColor: teamNumber == 1
                  ? Colors.blue.withValues(alpha: 0.2)
                  : teamNumber == 2
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
              checkmarkColor: teamNumber == 1
                  ? Colors.blue
                  : teamNumber == 2
                      ? Colors.green
                      : Colors.grey,
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDeckDiceSection() {
    final sum = _firstDiceValue + _secondDiceValue;

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Column(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ElevatedButton.icon(
                            onPressed: (_isRolling || !_secureInitialized)
                                ? null
                                : _rollDiceForDeck,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isRolling ? Colors.grey : Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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
                            label: const Text(
                              'Бросить кубики',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton.icon(
                            onPressed: _isRolling ? null : _manualSumInput,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text(
                              'Ввести вручную',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: ElevatedButton.icon(
                            onPressed: (_allDecks.isEmpty ||
                                    _selectedUserId == null ||
                                    _isRolling)
                                ? null
                                : _showManualDeckPicker,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.collections_bookmark, size: 18),
                            label: const Text(
                              'Выбрать вручную',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diceOperator(String symbol) {
    return Column(
      children: [
        SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Center(
            child: Text(
              symbol,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        )
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
            color: _isRolling ? Colors.grey[600]! : Colors.black,
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

  void _rollDiceForDeck() {
    if (_isRolling || !_secureInitialized) return;

    setState(() {
      _isRolling = true;
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
        _performFinalRollForDeck();
      }
    }

    performRoll();
  }

  void _performFinalRollForDeck() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_secureRandom != null) {
        setState(() {
          _firstDiceValue = _secureRandom!.nextInt(20) + 1;
        });

        Future.delayed(const Duration(milliseconds: 30), () {
          setState(() {
            _secondDiceValue = _secureRandom!.nextInt(20) + 1;
            _isRolling = false;
          });
          _applyCurrentDiceToDeckSelection();
        });
      } else {
        setState(() {
          _firstDiceValue = _fastRandom.nextInt(20) + 1;
          _secondDiceValue = _fastRandom.nextInt(20) + 1;
          _isRolling = false;
        });
        _applyCurrentDiceToDeckSelection();
      }
    });
  }

  void _applyCurrentDiceToDeckSelection() {
    final sum = _firstDiceValue + _secondDiceValue;
    _selectDeckBySum(sum);
  }

  void _selectDeckBySum(int sum) {
    if (_allDecks.isEmpty || _selectedUserId == null) return;

    final startIndex = (sum - 1) % _allDecks.length;
    final takenDeckIds = _userDecks.entries
        .where((e) => e.key != _selectedUserId)
        .map((e) => e.value.id)
        .toSet();

    Deck? deckToAssign;
    for (int i = 0; i < _allDecks.length; i++) {
      final idx = (startIndex + i) % _allDecks.length;
      if (!takenDeckIds.contains(_allDecks[idx].id)) {
        deckToAssign = _allDecks[idx];
        break;
      }
    }

    if (deckToAssign == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Все колоды уже выбраны другими игроками. Освободите колоду или добавьте новую.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _userDecks[_selectedUserId!] = deckToAssign!;
    });
  }

  void _manualSumInput() {
    String? errorText;
    _manualSumController.text = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Введите сумму'),
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
                        if (sum != null) {
                          _processManualSum(sum);
                          Navigator.of(context).pop();
                        }
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
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: errorText == null &&
                          _manualSumController.text.isNotEmpty
                      ? () {
                          final sum = int.tryParse(_manualSumController.text);
                          if (sum != null) {
                            _processManualSum(sum);
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

  void _processManualSum(int sum) {
    if (sum < 2 || sum > 40) return;

    setState(() {
      _firstDiceValue = min(20, sum ~/ 2);
      _secondDiceValue = sum - _firstDiceValue;
      if (_secondDiceValue > 20) {
        _secondDiceValue = 20;
        _firstDiceValue = sum - 20;
      }
    });

    _selectDeckBySum(sum);
  }

  void _showManualDeckPicker() {
    if (_allDecks.isEmpty || _selectedUserId == null) return;

    final user = _users.firstWhere(
      (u) => u.id == _selectedUserId,
      orElse: () => _users.first,
    );
    final disabledDeckIds = _userDecks.entries
        .where((e) => e.key != _selectedUserId)
        .map((e) => e.value.id)
        .toSet();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DeckPickerPage(
          userName: user.name,
          userId: user.id,
          decks: List.from(_allDecks),
          disabledDeckIds: disabledDeckIds,
          selectedDeck: _userDecks[_selectedUserId],
          onDeckSelected: (deck) {
            setState(() {
              _userDecks[_selectedUserId!] = deck;
            });
          },
        ),
      ),
    );
  }

  void _shuffleDecksForGame() {
    if (!_secureInitialized || _allDecks.isEmpty) return;
    setState(() {
      if (_secureRandom != null) {
        final list = List<Deck>.from(_allDecks);
        for (int i = list.length - 1; i > 0; i--) {
          final j = _secureRandom!.nextInt(i + 1);
          final temp = list[i];
          list[i] = list[j];
          list[j] = temp;
        }
        _allDecks = list;
      } else {
        _allDecks = List.from(_allDecks)..shuffle(_fastRandom);
      }
    });
  }

  Widget _buildUserDecksSummary() {
    if (_userDecks.isEmpty) {
      return const Text(
        'Колоды ещё не выбраны. Бросьте кубики, чтобы назначить колоду выбранному игроку.',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Назначенные колоды:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _userDecks.entries.map((entry) {
            final user = _users.firstWhere((u) => u.id == entry.key,
                orElse: () => _users.first);
            final deck = entry.value;
            return Chip(
              label: Text('${user.name}: ${deck.name}'),
              avatar: const Icon(Icons.person, size: 16),
            );
          }).toList(),
        ),
      ],
    );
  }
}
