/// Глобальные константы приложения.
abstract class AppConstants {
  static const String defaultDeckImageAsset = 'assets/images/back_card.jpg';

  /// Музыка во время хода команды (страница активной игры, режим по времени).
  /// Путь относительно папки assets для AssetSource.
  static const String turnMusicAsset = 'audio/turn_music.mp3';
  /// Музыка при перерасходе времени хода.
  static const String overtimeMusicAsset = 'audio/overtime_music.mp3';
}
