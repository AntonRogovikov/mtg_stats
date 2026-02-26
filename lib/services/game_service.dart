import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/core/api_error.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/services/api_config.dart';

/// API партий: создание, активная игра, обновление ходов, завершение, история.
class GameService {
  GameService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Game>> getGames() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/games'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Не удалось загрузить список игр: ${response.statusCode}');
    }
    final list = json.decode(response.body) as List<dynamic>;
    return list.map((e) => Game.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Game> getGame(String id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/games/$id'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode == 404) {
      throw Exception('Игра не найдена');
    }
    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить игру: ${response.statusCode}');
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Game> createGame(Game game) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/games');
    final response = await _client.post(
      uri,
      body: json.encode(game.toCreateRequest()),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 201) {
      final body = response.body.isNotEmpty ? response.body : 'empty';
      if (response.statusCode == 409) {
        throw Exception(ApiError.parse(body, 'Активная игра уже существует'));
      }
      throw Exception(ApiError.parse(body, 'Не удалось создать игру'));
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  /// Поставить партию на паузу. Возвращает обновлённую игру.
  Future<Game?> pauseGame() async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/games/active/pause'),
      body: '{}',
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
          ApiError.parse(response.body, 'Не удалось поставить на паузу'));
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  /// Снять паузу. Возвращает обновлённую игру.
  Future<Game?> resumeGame() async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/games/active/resume'),
      body: '{}',
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(ApiError.parse(response.body, 'Не удалось снять паузу'));
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  /// Начать ход — сервер устанавливает current_turn_start. Возвращает обновлённую игру.
  Future<Game?> startTurn() async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/games/active/start-turn'),
      body: '{}',
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(ApiError.parse(response.body, 'Не удалось начать ход'));
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Game?> getActiveGame() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/games/active'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
          ApiError.parse(response.body, 'Не удалось загрузить активную игру'));
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  /// Обновляет активную игру. Возвращает обновлённую игру с сервера (с серверным временем начала хода).
  Future<Game?> updateActiveGame(Game game, int currentTurnTeam,
      DateTime? currentTurnStart, List<GameTurn> turns) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/api/games/active'),
      body: json.encode({
        'current_turn_team': currentTurnTeam,
        'current_turn_start': currentTurnStart?.toIso8601String(),
        'turns': turns.map((e) => e.toJson()).toList(),
      }),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? response.body : 'empty';
      throw Exception(
          ApiError.parse(body, 'Не удалось обновить активную игру'));
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Game> finishGame(String gameId, int winningTeam,
      {bool isTechnicalDefeat = false}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/games/active/finish'),
      body: json.encode({
        'winning_team': winningTeam,
        'is_technical_defeat': isTechnicalDefeat,
      }),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception(
          ApiError.parse(response.body, 'Не удалось завершить игру'));
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Game> createRematch({
    required String sourceGameId,
    required RematchMode mode,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/games/rematch'),
      body: json.encode({
        'source_game_id': int.tryParse(sourceGameId) ?? 0,
        'mode': mode.apiValue,
      }),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 201) {
      throw Exception(
          ApiError.parse(response.body, 'Не удалось создать реванш'));
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Game> getPublicGameByToken(String token) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/public/games/$token'),
    );
    if (response.statusCode == 404) {
      throw Exception('Публичная игра не найдена');
    }
    if (response.statusCode != 200) {
      throw Exception(
          'Не удалось загрузить публичную игру: ${response.statusCode}');
    }
    return Game.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Stream<Game> streamPublicGameByToken(
    String token, {
    Duration interval = const Duration(seconds: 1),
  }) {
    late final StreamController<Game> controller;
    Timer? timer;
    var inFlight = false;

    Future<void> tick() async {
      if (inFlight || controller.isClosed) return;
      inFlight = true;
      try {
        final game = await getPublicGameByToken(token);
        if (!controller.isClosed) {
          controller.add(game);
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      } finally {
        inFlight = false;
      }
    }

    controller = StreamController<Game>(
      onListen: () {
        tick();
        timer = Timer.periodic(interval, (_) => tick());
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }
}
