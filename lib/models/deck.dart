/// Модель колоды: id, название, даты, URL полного изображения и аватара.
class Deck {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  final String? avatarUrl;

  Deck._({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.avatarUrl,
  });

  Deck copyWith({
    String? name,
    String? imageUrl,
    String? avatarUrl,
  }) {
    return Deck._(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck._(
      id: _parseInt(json['id'], 0),
      name: json['name'] as String? ?? '',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      imageUrl: json['image_url'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  Map<String, dynamic> toJsonForUpdate() {
    return <String, dynamic>{'name': name};
  }
}
