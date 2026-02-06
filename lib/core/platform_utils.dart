import 'platform_utils_web.dart' if (dart.library.io) 'platform_utils_stub.dart' as impl;

/// true, если приложение запущено в браузере на iOS (любой браузер на iPhone/iPad).
/// На iOS Web автовоспроизведение второго трека (overtime) блокируется без жеста пользователя.
bool get isIOSWeb => impl.isIOSWeb;
