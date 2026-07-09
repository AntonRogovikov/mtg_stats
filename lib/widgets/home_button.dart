import 'package:flutter/material.dart';

/// Кнопка на главном экране для перехода к разделу приложения.
/// [color] — акцентный цвет (обычно цвет текущего разреза); по умолчанию синий.
class HomeButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const HomeButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? const Color(0xFF1565C0);
    // Рамка — заметно темнее фона для читаемого контура на любом цвете.
    final borderColor =
        HSLColor.fromColor(baseColor).withLightness(0.25).toColor();
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 28, color: Colors.white),
      label: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(280, 65),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        backgroundColor: baseColor,
        foregroundColor: Colors.white,
        shadowColor: baseColor.withValues(alpha: 0.5),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 2),
        ),
      ),
    );
  }
}
