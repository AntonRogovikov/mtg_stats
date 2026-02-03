import 'package:flutter/material.dart';

import 'deck_image_url.dart';

ImageProvider? deckImageProvider(String? url) {
  final resolved = resolveDeckImageUrl(url);
  if (resolved == null || resolved.isEmpty) return null;
  return NetworkImage(resolved);
}
