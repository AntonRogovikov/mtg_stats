import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/services/api_config.dart';

/// API колод: CRUD, загрузка и удаление изображений.
class DeckService {
  Future<Deck> createDeck(String name) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/decks'),
      body: json.encode({'name': name}),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );

    return Deck.fromJson(json.decode(response.body));
  }

  Future<Deck> updateDeck(Deck deck) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/decks/${deck.id}'),
      body: json.encode(deck.toJsonForUpdate()),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );

    return Deck.fromJson(json.decode(response.body));
  }

  Future<List<Deck>> getAllDecks() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/decks'),
      headers: ApiConfig.authHeaders,
    );

    final List<dynamic> data = json.decode(response.body);
    return data.map((j) => Deck.fromJson(j)).toList();
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

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Ошибка загрузки изображения: ${response.statusCode}');
    }

    return Deck.fromJson(json.decode(response.body));
  }

  Future<Deck> deleteDeckImage(Deck deck) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/decks/${deck.id}/image'),
      headers: ApiConfig.authHeaders,
    );

    final cleared = deck.copyWith(imageUrl: null, avatarUrl: null);
    if (response.statusCode == 204 || response.body.isEmpty) {
      return cleared;
    }
    if (response.statusCode == 200) {
      try {
        return Deck.fromJson(json.decode(response.body) as Map<String, dynamic>);
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
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/decks/$id'),
      headers: ApiConfig.authHeaders,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete deck: ${response.statusCode}');
    }
  }
}
