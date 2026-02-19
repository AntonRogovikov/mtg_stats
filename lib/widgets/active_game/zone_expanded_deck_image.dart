import 'package:flutter/material.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/services/deck_image/deck_image_provider.dart';

/// Развёрнутое изображение колоды на всю ширину зоны.
class ZoneExpandedDeckImage extends StatelessWidget {
  final Deck deck;
  final double maxWidth;

  const ZoneExpandedDeckImage({
    super.key,
    required this.deck,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final pathOrUrl = deck.imageUrl ?? deck.avatarUrl;
    final provider = deckImageProvider(
      pathOrUrl?.isNotEmpty == true ? pathOrUrl : null,
    );
    final useAsset = provider == null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: useAsset
          ? Image.asset(
              AppConstants.defaultDeckImageAsset,
              fit: BoxFit.contain,
            )
          : Image(
              image: provider,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, __, ___) => Image.asset(
                AppConstants.defaultDeckImageAsset,
                fit: BoxFit.contain,
              ),
            ),
    );
  }
}
