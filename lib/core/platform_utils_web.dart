// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// true, если приложение открыто в браузере на iOS (Safari, Chrome и др. на iPhone/iPad).
bool get isIOSWeb {
  final ua = html.window.navigator.userAgent;
  return ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod');
}
