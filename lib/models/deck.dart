import 'package:cloud_firestore/cloud_firestore.dart';

class Deck {
  String? id;
  String name;
  DateTime createdAt;
  DateTime? updatedAt; // Добавляем поле для отслеживания обновлений

  Deck({this.id, required this.name, DateTime? createdAt, this.updatedAt})
    : createdAt = createdAt ?? DateTime.now();

  factory Deck.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Deck(
      id: doc.id,
      name: data['name'] ?? 'Без названия',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {'name': name, 'createdAt': Timestamp.fromDate(createdAt)};

    if (updatedAt != null) {
      map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }

    return map;
  }

  // ... остальные методы без изменений
}
