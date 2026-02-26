import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/core/api_error.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/services/api_config.dart';

/// API колод: CRUD, загрузка и удаление изображений.
class DeckService {
  DeckService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Deck> createDeck(String name) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/decks'),
      body: json.encode({'name': name}),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          ApiError.parse(response.body, 'Не удалось создать колоду'));
    }
    return Deck.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Deck> updateDeck(Deck deck) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/api/decks/${deck.id}'),
      body: json.encode(deck.toJsonForUpdate()),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception(
          ApiError.parse(response.body, 'Не удалось обновить колоду'));
    }
    return Deck.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Deck?> getDeckById(int id) async {
    if (id <= 0) return null;
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/decks/$id'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) return null;
    try {
      final body = json.decode(response.body);
      final deckJson = body is Map && body['deck'] != null
          ? body['deck'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      return Deck.fromJson(deckJson);
    } catch (_) {
      return null;
    }
  }

  Future<List<Deck>> getAllDecks() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/decks'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception(
          ApiError.parse(response.body, 'Не удалось загрузить колоды'));
    }
    final List<dynamic> data = json.decode(response.body);
    return data.map((j) => Deck.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Deck> uploadDeckImage(
    Deck deck,
    List<int> fullImageBytes,
    List<int> avatarBytes,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/decks/${deck.id}/image');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(ApiConfig.authHeaders)
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        fullImageBytes,
        filename: 'image.jpg',
      ))
      ..files.add(http.MultipartFile.fromBytes(
        'avatar',
        avatarBytes,
        filename: 'avatar.jpg',
      ));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Ошибка загрузки изображения: ${response.statusCode}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final deckJson = body['deck'] as Map<String, dynamic>?;
    return deckJson != null ? Deck.fromJson(deckJson) : Deck.fromJson(body);
  }

  Future<Deck> deleteDeckImage(Deck deck) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/decks/${deck.id}/image'),
      headers: ApiConfig.authHeaders,
    );

    final cleared = deck.copyWith(imageUrl: null, avatarUrl: null);
    if (response.statusCode == 204 || response.body.isEmpty) {
      return cleared;
    }
    if (response.statusCode == 200) {
      try {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final deckJson = body['deck'] as Map<String, dynamic>?;
        return deckJson != null ? Deck.fromJson(deckJson) : Deck.fromJson(body);
      } catch (_) {
        return cleared;
      }
    }
    if (response.statusCode == 404) {
      return cleared;
    }
    throw Exception('Ошибка удаления изображения: ${response.statusCode}');
  }

  Future<void> deleteDeck(int id) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/decks/$id'),
      headers: ApiConfig.authHeaders,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete deck: ${response.statusCode}');
    }
  }
}
