import 'package:flutter/material.dart';

/// Цвета и стили приложения.
/// Базовая гамма — синяя; внутри разреза с заданным цветом AppBar
/// перекрашивается: MyApp вызывает [setSliceColor] при смене разреза.
abstract class AppTheme {
  static final Color _defaultAppBarBackground = Colors.blueGrey[900]!;
  static Color? _sliceColor;

  /// Цвет текущего разреза; null — стандартная гамма.
  static void setSliceColor(Color? color) => _sliceColor = color;

  static Color get appBarBackground => _sliceColor ?? _defaultAppBarBackground;
  static const Color appBarForeground = Colors.white;
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    color: Colors.white,
  );
}
