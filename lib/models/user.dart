/// Модель пользователя для выбора игроков в партии.
class User {
  final String id;
  final String name;
  final bool isAdmin;

  const User({
    required this.id,
    required this.name,
    this.isAdmin = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return User(
      id: id?.toString() ?? '',
      name: json['name'] as String? ?? '',
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
