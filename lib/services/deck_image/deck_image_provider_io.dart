import 'dart:io';

import 'package:flutter/material.dart';

import 'deck_image_url.dart';

ImageProvider? deckImageProvider(String? url) {
  final resolved = resolveDeckImageUrl(url);
  if (resolved == null || resolved.isEmpty) return null;
  if (resolved.startsWith('http') || resolved.startsWith('data:')) {
    return NetworkImage(resolved);
  }
  final path = resolved.startsWith('file:') ? resolved.replaceFirst('file:', '') : resolved;
  return FileImage(File(path));
}
