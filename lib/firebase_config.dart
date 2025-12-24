import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseConfig {
  static Future<void> initialize() async {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDUNOwizVbCsThEUiHHFraiUkG-Qg53Cno",
          authDomain: "mtg-decks-app.firebaseapp.com",
          projectId: "mtg-decks-app",
          storageBucket: "mtg-decks-app.firebasestorage.app",
          messagingSenderId: "828940332266",
          appId: "1:828940332266:web:af1fca5b38a73b95c53b93",
          measurementId: "G-537356VKY4",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  }
}
