import 'package:flutter/material.dart';
import 'firebase_config.dart';
import 'pages/decks_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FirebaseConfig.initialize();
    print('✅ Firebase инициализирован');
  } catch (e) {
    print('❌ Ошибка Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
      routes: {'/decks': (context) => DeckListPage()},
    );
  }
}
