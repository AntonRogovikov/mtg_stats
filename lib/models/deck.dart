/// Модель колоды: идентификатор, название, даты создания и обновления.
class Deck {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

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

  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck._(
      id: json['id'] as int,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Тело запроса для PUT: только изменяемые поля (имя).
  Map<String, dynamic> toJsonForUpdate() {
    return {
      'name': name,
    };
  }
}
