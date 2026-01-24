class Deck {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Приватный конструктор - нельзя создать Deck вручную
  Deck._({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

   Deck copyWith({String? name}) {
    return Deck._(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Фабрика ТОЛЬКО для парсинга ответа сервера
  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck._(
      id: json['id'] as int,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // Для обновления (PUT запрос)
  Map<String, dynamic> toJsonForUpdate() {
    return {
      'name': name,
    };
  }
}
