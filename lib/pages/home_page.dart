import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MTG Статистика',
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey[900],
        elevation: 4,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _HomeButton(
              text: 'КОЛОДЫ',
              icon: Icons.import_contacts,
              onPressed: () {
                //print('Открываем список колод');
                 Navigator.pushNamed(context, '/decks');
              },
            ),
            const SizedBox(height: 20),
            _HomeButton(
              text: 'СТАТИСТИКА',
              icon: Icons.bar_chart,
              onPressed: () {
                //print('Открываем статистику');
              },
            ),
            const SizedBox(height: 20),
            _HomeButton(
              text: 'ПАРТИИ',
              icon: Icons.sports_esports,
              onPressed: () {
                //print('Открываем историю матчей');
              },
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
    );
  }
}

class _HomeButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const _HomeButton({
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
