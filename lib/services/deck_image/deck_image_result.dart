import 'dart:typed_data';

/// Байты полного изображения и аватара для загрузки на API.
class DeckImageResult {
  final Uint8List fullBytes;
  final Uint8List avatarBytes;

  DeckImageResult({required this.fullBytes, required this.avatarBytes});
}
