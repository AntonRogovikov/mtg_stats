import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/data/fun_team_names.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/user.dart';
import 'package:mtg_stats/pages/active_game_page.dart';
import 'package:mtg_stats/pages/deck_selection_page.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/services/game_manager.dart';
import 'package:mtg_stats/services/api_config.dart';

/// Настройка новой партии: команды, первый ход, колоды игроков.
class GamePage extends ConsumerStatefulWidget {
  const GamePage({super.key});

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  final Random _random = Random();
  final Map<String, Deck> _userDecks = {};

  final List<User> _team1 = [];
  final List<User> _team2 = [];

  bool _teamsExpanded = false;

  int? _firstMoveTeam;
  bool _useTurnLimit = false;
  int _turnLimitSeconds = 300;
  bool _useTeamTimeLimit = false;
  int _teamTimeLimitSeconds = 1800; // 30 мин по умолчанию
  static const _teamTimeLimitOptions = [
    60, 1800, 3600, 5400, 7200, 9000, 10800,
  ]; // 60 сек — тест, потом убрать; 30мин..3ч

  /// Пока true — показываем загрузку вместо формы, чтобы не мелькала страница настроек при редиректе на активную игру.
  bool _isCheckingActiveGame = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (GameManager.instance.hasActiveGame) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ActiveGamePage(),
          ),
        );
        return;
      }
      try {
        final active = await ref.read(gameServiceProvider).getActiveGame();
        if (mounted && active != null) {
          GameManager.instance.setActiveGameFromApi(active);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ActiveGamePage(),
            ),
          );
          return;
        }
        if (mounted && GameManager.instance.hasActiveGame) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ActiveGamePage(),
            ),
          );
          return;
        }
      } catch (_) {
        // Ошибка проверки активной игры не блокирует форму — пользователь может создать новую.
      }
      if (mounted) {
        setState(() => _isCheckingActiveGame = false);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _randomizeTeams(List<User> users) {
    setState(() {
      _team1.clear();
      _team2.clear();
      final usersCopy = List<User>.from(users);
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

  Future<void> _startGame(List<User> users) async {
    if (GameManager.instance.hasActiveGame) {
      Navigator.of(context).pushReplacement(
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

    for (final user in users) {
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
    final teamTimeLimit = _useTeamTimeLimit ? _teamTimeLimitSeconds : 0;
    // Автоматическая генерация названий команд при старте игры.
    var team1Name = getRandomTeamName(_random);
    var team2Name = getRandomTeamName(_random);
    while (team1Name == team2Name) {
      team2Name = getRandomTeamName(_random);
    }
    final stubGame = Game(
      id: '',
      startTime: DateTime.now(),
      turnLimitSeconds: turnLimit,
      teamTimeLimitSeconds: teamTimeLimit,
      firstMoveTeam: _firstMoveTeam!,
      players: players,
      team1Name: team1Name,
      team2Name: team2Name,
    );

    try {
      final gameService = ref.read(gameServiceProvider);
      final created = await gameService.createGame(stubGame);
      if (!mounted) return;
      GameManager.instance.setActiveGameFromApi(created);
      GameManager.instance.setTeamNames(
        team1Name: team1Name,
        team2Name: team2Name,
      );
      // Автоматически начинаем первый ход, чтобы время команд пошло сразу.
      try {
        final withTurn = await gameService.startTurn();
        if (mounted && withTurn != null) {
          GameManager.instance.setActiveGameFromApi(withTurn);
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
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

  Widget _buildAdminRequired() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Новая партия', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        elevation: 4,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings, size: 64, color: Colors.orange[400]),
              const SizedBox(height: 16),
              Text(
                'Требуются права администратора',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Создавать и вести партии могут только администраторы.\nВойдите под учётной записью администратора в настройках.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final decksAsync = ref.watch(decksProvider);
    final users = usersAsync.asData?.value ?? const <User>[];
    final allDecks = decksAsync.asData?.value ?? const <Deck>[];
    final isUsersLoading = usersAsync.isLoading;
    final isUsersError = usersAsync.hasError;
    final isDecksLoading = decksAsync.isLoading;
    final isDecksError = decksAsync.hasError;

    if (!ApiConfig.isAdmin) {
      return _buildAdminRequired();
    }
    if (_isCheckingActiveGame) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Новая партия', style: AppTheme.appBarTitle),
          backgroundColor: AppTheme.appBarBackground,
          foregroundColor: AppTheme.appBarForeground,
          elevation: 4,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Новая партия', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        elevation: 4,
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (isUsersLoading)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 16),
                      Text(
                        'Загрузка пользователей...',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              )
            else if (isUsersError)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Не удалось загрузить пользователей',
                        style: TextStyle(
                          color: Colors.red[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(usersProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              )
            else if (users.isEmpty)
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Нет пользователей. Добавьте пользователей в настройках.',
                    style: TextStyle(color: Colors.orange[900]),
                  ),
                ),
              )
            else ...[
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
                              onPressed: () => _randomizeTeams(users),
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
                        users: users,
                        selectedUsers: _team1),
                    const Divider(),
                    _buildTeamSection(
                        title: 'Команда 2',
                        teamNumber: 2,
                        users: users,
                        selectedUsers: _team2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildFirstMoveSection(),
            const SizedBox(height: 32),
            _buildUserDeckSelectionSection(
              users: users,
              isDecksLoading: isDecksLoading,
              isDecksError: isDecksError,
              allDecks: allDecks,
            ),
            const SizedBox(height: 32),
            _buildTurnSettingsSection(users),
            ],
          ])),
    );
  }

  Widget _buildTeamSection(
      {required String title,
      required int teamNumber,
      required List<User> users,
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
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
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

  Widget _buildTurnSettingsSection(List<User> users) {
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
            const SizedBox(height: 16),
            const Text(
              'Общее время на команду',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _useTeamTimeLimit,
              onChanged: (value) {
                setState(() {
                  _useTeamTimeLimit = value ?? false;
                });
              },
              title: const Text('Ограничение общего времени на команду'),
              subtitle: _useTeamTimeLimit
                  ? Text(
                      _formatTeamTimeLimit(_teamTimeLimitSeconds),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    )
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_useTeamTimeLimit) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Максимальное время на команду:'),
                  Text(
                    _formatTeamTimeLimit(_teamTimeLimitSeconds),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _teamTimeLimitOptions
                    .indexOf(_teamTimeLimitSeconds)
                    .clamp(0, _teamTimeLimitOptions.length - 1)
                    .toDouble(),
                min: 0,
                max: (_teamTimeLimitOptions.length - 1).toDouble(),
                divisions: _teamTimeLimitOptions.length - 1,
                label: _formatTeamTimeLimit(_teamTimeLimitSeconds),
                onChanged: (value) {
                  final idx = value.round().clamp(0, _teamTimeLimitOptions.length - 1);
                  setState(() {
                    _teamTimeLimitSeconds = _teamTimeLimitOptions[idx];
                  });
                },
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startGame(users),
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

  static String _formatTeamTimeLimit(int seconds) {
    if (seconds < 60) return '$seconds сек';
    final m = seconds ~/ 60;
    if (m < 60) return '$m мин';
    final h = m ~/ 60;
    final rest = m % 60;
    if (rest == 0) return '$h ч';
    return '$h ч $rest мин';
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

  Future<void> _openDeckSelectionPage(List<Deck> allDecks) async {
    if (_team1.length != 2 || _team2.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала распределите по 2 игрока в каждую команду'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (allDecks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных колод. Создайте колоды на экране "Колоды".'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<Map<String, Deck>>(
      MaterialPageRoute(
        builder: (context) => DeckSelectionPage(
          team1: List.from(_team1),
          team2: List.from(_team2),
          allDecks: List.from(allDecks),
          initialUserDecks: Map.from(_userDecks),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _userDecks.clear();
        _userDecks.addAll(result);
      });
    }
  }

  Widget _buildUserDeckSelectionSection({
    required List<User> users,
    required bool isDecksLoading,
    required bool isDecksError,
    required List<Deck> allDecks,
  }) {
    final teamsReady = _team1.length == 2 && _team2.length == 2;
    final canSelectDecks = teamsReady && !isDecksLoading && allDecks.isNotEmpty;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выбор колоды для игроков',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (isDecksLoading)
              const Center(child: CircularProgressIndicator())
            else if (isDecksError || allDecks.isEmpty)
              const Text(
                'Колоды недоступны. Проверьте подключение или создайте колоды на экране "Колоды".',
                style: TextStyle(color: Colors.redAccent),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canSelectDecks ? () => _openDeckSelectionPage(allDecks) : null,
                  icon: const Icon(Icons.collections_bookmark),
                  label: const Text('Выбрать колоды'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSelectDecks ? Colors.blueGrey[700] : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (!teamsReady)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Сначала распределите игроков по командам',
                    style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                  ),
                ),
              const SizedBox(height: 16),
              _buildUserDecksSummary(users),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserDecksSummary(List<User> users) {
    if (_userDecks.isEmpty) {
      return const Text(
        'Колоды ещё не выбраны. Нажмите «Выбрать колоды» для назначения.',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      );
    }

    final userById = {for (final u in users) u.id: u};
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
            final userName = userById[entry.key]?.name ?? '?';
            final deck = entry.value;
            return Chip(
              label: Text('$userName: ${deck.name}'),
              avatar: const Icon(Icons.person, size: 16),
            );
          }).toList(),
        ),
      ],
    );
  }
}
