import 'package:flutter/material.dart';

/// Кнопка на главном экране для перехода к разделу приложения.
class HomeButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const HomeButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        shadowColor: Color.fromRGBO(13, 71, 161, 0.5),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue[900]!, width: 2),
        ),
      ),
    );
  }
}
