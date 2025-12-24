// database/firebase_database_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deck.dart';

class FirebaseDatabaseHelper {
  static const String _collectionName = 'decks';

  FirebaseDatabaseHelper._privateConstructor();
  static final FirebaseDatabaseHelper instance =
      FirebaseDatabaseHelper._privateConstructor();

  // Получить коллекцию колод
  CollectionReference<Map<String, dynamic>> get _decksCollection {
    return FirebaseFirestore.instance.collection(_collectionName);
  }

  // Получить все колоды
  Future<List<Deck>> getAllDecks() async {
    try {
      final snapshot = await _decksCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Deck.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('❌ Ошибка получения колод: $e');
      return [];
    }
  }

  Future<String> insertDeck(String name) async {
    try {
      final deck = Deck(name: name);
      final docRef = await _decksCollection.add(deck.toMap());
      return docRef.id;
    } catch (e) {
      print('❌ Ошибка добавления колоды: $e');
      rethrow;
    }
  }

  Future<void> updateDeck(String deckId, String newName) async {
    try {
      await _decksCollection.doc(deckId).update({
        'name': newName,
        'updatedAt': Timestamp.now(), // Можно добавить поле updatedAt в модель
      });
      print('✅ Колода обновлена: $deckId -> $newName');
    } catch (e) {
      print('❌ Ошибка обновления колоды: $e');
      rethrow;
    }
  }

  Future<void> deleteDeck(String deckId) async {
    try {
      await _decksCollection.doc(deckId).delete();
      print('✅ Колода удалена: $deckId');
    } catch (e) {
      print('❌ Ошибка удаления колоды: $e');
      rethrow;
    }
  }
}
