import 'deck_image_provider_web.dart'
    if (dart.library.io) 'deck_image_provider_io.dart' as impl;

import 'package:flutter/material.dart';

ImageProvider? deckImageProvider(String? url) => impl.deckImageProvider(url);
