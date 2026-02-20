import 'package:mtg_stats/core/platform_utils_web.dart'
    if (dart.library.io) 'package:mtg_stats/core/platform_utils_stub.dart' as impl;

/// true, если приложение запущено в браузере на iOS.
/// На iOS Web автовоспроизведение overtime-трека блокируется без жеста пользователя.
bool get isIOSWeb => impl.isIOSWeb;
