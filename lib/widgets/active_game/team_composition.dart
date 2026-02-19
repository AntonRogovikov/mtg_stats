import 'package:flutter/material.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/game.dart';

/// Состав команды: как в карточке игры — иконка, имя, колода (по нажатию — увеличенное изображение).
class TeamComposition extends StatelessWidget {
  final List<GamePlayer> teamPlayers;
  final MaterialColor color;
  final Map<int, Deck> decksById;
  final void Function(Deck deck)? onDeckTap;

  const TeamComposition({
    super.key,
    required this.teamPlayers,
    required this.color,
    required this.decksById,
    this.onDeckTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        ...teamPlayers.map(
          (p) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.userName,
                    style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DeckTapTarget(
                  deck: decksById[p.deckId],
                  deckName: decksById[p.deckId]?.name ?? p.deckName,
                  onDeckTap: onDeckTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Кликабельная колода: при нажатии — увеличенное изображение (как в карточке игры по виду).
class DeckTapTarget extends StatelessWidget {
  final Deck? deck;
  final String deckName;
  final void Function(Deck deck)? onDeckTap;

  const DeckTapTarget({
    super.key,
    required this.deck,
    required this.deckName,
    this.onDeckTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLink = deck != null && onDeckTap != null;
    return GestureDetector(
      onTap: isLink ? () => onDeckTap!(deck!) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLink) Icon(Icons.badge, size: 16, color: Colors.blue[700]),
          if (isLink) const SizedBox(width: 4),
          Text(
            deckName,
            style: TextStyle(
              fontSize: 13,
              color: isLink ? Colors.blue[700] : Colors.grey[600],
              decoration: isLink ? TextDecoration.underline : null,
              decorationColor: Colors.blue[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
