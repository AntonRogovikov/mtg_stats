import 'package:flutter/material.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/services/deck_image/deck_image_provider.dart';

/// Карточка колоды в списке: изображение, название под картинкой, выбор и меню.
class DeckCard extends StatelessWidget {
  final Deck deck;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onMenuTap;

  const DeckCard({
    super.key,
    required this.deck,
    required this.isSelected,
    this.isDisabled = false,
    required this.onTap,
    required this.onLongPress,
    this.onMenuTap,
  });

  static const String _defaultImageAsset = AppConstants.defaultDeckImageAsset;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Card(
                color: isDisabled ? Colors.grey[300] : null,
                elevation: isSelected ? 8 : 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: isSelected ? 3 : 0,
                  ),
                ),
                child: Container(
                  width: 130,
                  height: 182,
                  decoration: BoxDecoration(
                    color: isDisabled ? Colors.grey[400] : null,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Color.fromRGBO(33, 150, 243, 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!isDisabled)
                        _DeckCardImage(
                          avatarUrl: deck.avatarUrl,
                          defaultAsset: _defaultImageAsset,
                        ),
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        ),
                      if (onMenuTap != null && !isDisabled)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Material(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: onMenuTap,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.more_vert, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  deck.name,
                  style: TextStyle(
                    color: isDisabled ? Colors.grey[700] : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckCardImage extends StatelessWidget {
  final String? avatarUrl;
  final String defaultAsset;

  const _DeckCardImage({
    required this.avatarUrl,
    required this.defaultAsset,
  });

  @override
  Widget build(BuildContext context) {
    final provider = deckImageProvider(avatarUrl);
    if (provider == null) {
      return Image.asset(defaultAsset, fit: BoxFit.cover);
    }
    return Image(
      image: provider,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Image.asset(defaultAsset, fit: BoxFit.cover),
    );
  }
}

