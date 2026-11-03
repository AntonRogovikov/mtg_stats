import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mtg_stats/core/api_error.dart';
import 'package:mtg_stats/models/slice.dart';
import 'package:mtg_stats/services/api_config.dart';

/// API разрезов статистики: список, создание, обновление, удаление.
class SliceService {
  SliceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Slice>> getSlices() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/slices'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить разрезы: ${response.statusCode}');
    }
    final list = json.decode(response.body) as List<dynamic>;
    return list.map((e) => Slice.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Slice> createSlice(Slice slice) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/slices'),
      body: json.encode(slice.toRequestJson()),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 201) {
      throw Exception(ApiError.parse(response.body, 'Не удалось создать разрез'));
    }
    return Slice.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Slice> updateSlice(Slice slice) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/api/slices/${slice.id}'),
      body: json.encode(slice.toRequestJson()),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception(ApiError.parse(response.body, 'Не удалось обновить разрез'));
    }
    return Slice.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Slice> setExcludeFromDraw(int sliceId, int deckId, bool exclude) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/api/slices/$sliceId/decks/$deckId/draw'),
      body: json.encode({'exclude_from_draw': exclude}),
      headers: {...ApiConfig.authHeaders, 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception(ApiError.parse(response.body, 'Не удалось изменить пометку колоды'));
    }
    return Slice.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteSlice(int id) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/slices/$id'),
      headers: ApiConfig.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception(ApiError.parse(response.body, 'Не удалось удалить разрез'));
    }
  }
}
