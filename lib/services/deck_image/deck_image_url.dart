import 'package:mtg_stats/services/api_config.dart';

String? resolveDeckImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http') || url.startsWith('data:') || url.startsWith('file:')) {
    return url;
  }
  final base = ApiConfig.baseUrl;
  return url.startsWith('/') ? '$base$url' : '$base/$url';
}
