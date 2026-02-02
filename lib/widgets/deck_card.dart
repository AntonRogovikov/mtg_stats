import 'package:flutter/material.dart';
import 'package:mtg_stats/models/deck.dart';

/// Карточка колоды: изображение, название, выделение при выборе, поддержка disabled.
class DeckCard extends StatelessWidget {
  final Deck deck;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const DeckCard({
    super.key,
    required this.deck,
    required this.isSelected,
    this.isDisabled = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Card(
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
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                color: isDisabled ? Colors.grey[400] : null,
                image: isDisabled
                    ? null
                    : const DecorationImage(
                        image: AssetImage('assets/images/back_card.jpg'),
                        fit: BoxFit.fill,
                      ),
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
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      deck.name,
                      style: TextStyle(
                        color: isDisabled ? Colors.grey[700] : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

