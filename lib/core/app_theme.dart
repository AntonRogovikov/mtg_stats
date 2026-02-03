import 'package:flutter/material.dart';

/// Цвета и стили приложения.
abstract class AppTheme {
  static Color get appBarBackground => Colors.blueGrey[900]!;
  static const Color appBarForeground = Colors.white;
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    color: Colors.white,
  );
}
