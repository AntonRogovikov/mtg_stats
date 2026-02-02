import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/models/deck.dart';

/// API колод: создание, обновление, получение списка и удаление.
class DeckService {
  static const String baseUrl =
      'https://mtg-stats-backend-production-1a71.up.railway.app';

  Future<Deck> createDeck(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/decks'),
      body: json.encode({'name': name}),
      headers: {'Content-Type': 'application/json'},
    );

    return Deck.fromJson(json.decode(response.body));
  }

  Future<Deck> updateDeck(Deck deck) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/decks/${deck.id}'),
      body: json.encode(deck.toJsonForUpdate()),
      headers: {'Content-Type': 'application/json'},
    );

    return Deck.fromJson(json.decode(response.body));
  }

  Future<Deck> getDeck(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/decks/$id'),
    );

    return Deck.fromJson(json.decode(response.body));
  }

  Future<List<Deck>> getAllDecks() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/decks'),
    );

    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Deck.fromJson(json)).toList();
  }

  Future<void> deleteDeck(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/decks/$id'),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete deck: ${response.statusCode}');
    }
  }
}
