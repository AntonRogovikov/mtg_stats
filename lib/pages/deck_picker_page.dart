import 'package:flutter/material.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/pages/full_screen_image_page.dart';
import 'package:mtg_stats/widgets/deck_card.dart';

/// Выбор колоды для игрока в партии (сетка колод).
class DeckPickerPage extends StatelessWidget {
  final String userName;
  final String userId;
  final List<Deck> decks;
  final Set<int> disabledDeckIds;
  final Deck? selectedDeck;
  final void Function(Deck) onDeckSelected;

  const DeckPickerPage({
    super.key,
    required this.userName,
    required this.userId,
    required this.decks,
    this.disabledDeckIds = const {},
    required this.selectedDeck,
    required this.onDeckSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Выбор колоды для $userName'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: decks.isEmpty
          ? const Center(
              child: Text(
                'Нет доступных колод',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: GridView.builder(
                 gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.63,
                  ),
                  itemCount: decks.length,
                  itemBuilder: (context, index) {
                    final deck = decks[index];
                    final isSelected = selectedDeck?.id == deck.id;
                    final isDisabled = disabledDeckIds.contains(deck.id);
                    return DeckCard(
                      deck: deck,
                      isSelected: isSelected,
                      isDisabled: isDisabled,
                      onTap: isDisabled
                          ? () {}
                          : () {
                        onDeckSelected(deck);
                        Navigator.of(context).pop();
                      },
                      onLongPress: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImagePage(
                              imagePathOrUrl: deck.imageUrl ?? deck.avatarUrl,
                              assetFallback: AppConstants.defaultDeckImageAsset,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ),
    );
  }

}
