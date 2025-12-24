// models/deck.dart
class Deck {
  String name;

  Deck({required this.name});

  // Для работы с вашим существующим кодом
  Map<String, dynamic> toMap() {
    return {'name': name};
  }

  // Для создания из Map (если нужно)
  factory Deck.fromMap(Map<String, dynamic> map) {
    return Deck(name: map['name']);
  }

  @override
  String toString() {
    return name;
  }
}
