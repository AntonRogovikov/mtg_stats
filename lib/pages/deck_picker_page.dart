import 'package:flutter/material.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/pages/full_screen_image_page.dart';
import 'package:mtg_stats/widgets/deck_card.dart';

/// Выбор колоды для игрока в партии (сетка колод).
class DeckPickerPage extends StatefulWidget {
  final String userName;
  final String userId;
  final List<Deck> decks;
  final Set<int> disabledDeckIds;
  /// Для отключённых колод: id колоды → имя игрока, который её выбрал.
  final Map<int, String>? disabledDeckIdToPlayerName;
  final Deck? selectedDeck;
  final void Function(Deck) onDeckSelected;

  const DeckPickerPage({
    super.key,
    required this.userName,
    required this.userId,
    required this.decks,
    this.disabledDeckIds = const {},
    this.disabledDeckIdToPlayerName,
    required this.selectedDeck,
    required this.onDeckSelected,
  });

  @override
  State<DeckPickerPage> createState() => _DeckPickerPageState();
}

class _DeckPickerPageState extends State<DeckPickerPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Deck> get _filteredDecks {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.decks;
    return widget.decks
        .where((d) => d.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decks = widget.decks;
    final filteredDecks = _filteredDecks;

    final bool decksEmpty = decks.isEmpty;
    final bool filteredEmpty = filteredDecks.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Выбор колоды для ${widget.userName}'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: decksEmpty
          ? const Center(
              child: Text(
                'Нет доступных колод',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchField(),
                if (filteredEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'Ничего не найдено',
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.63,
                        ),
                        itemCount: filteredDecks.length,
                        itemBuilder: (context, index) {
                          final deck = filteredDecks[index];
                          final bool isSelected = widget.selectedDeck != null &&
                              widget.selectedDeck!.id == deck.id;
                          final bool isDisabled =
                              widget.disabledDeckIds.contains(deck.id);
                          final String? disabledLabel =
                              (isDisabled && widget.disabledDeckIdToPlayerName != null)
                                  ? widget.disabledDeckIdToPlayerName![deck.id]
                                  : null;
                          return DeckCard(
                            key: ValueKey<int>(deck.id),
                            deck: deck,
                            isSelected: isSelected,
                            isDisabled: isDisabled,
                            disabledSelectedByPlayerName: disabledLabel,
                            onTap: isDisabled
                                ? () {}
                                : () {
                                    widget.onDeckSelected(deck);
                                    Navigator.of(context).pop();
                                  },
                            onLongPress: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImagePage(
                                    imagePathOrUrl:
                                        deck.imageUrl ?? deck.avatarUrl,
                                    assetFallback:
                                        AppConstants.defaultDeckImageAsset,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    final bool hasSearch = _searchController.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Поиск по названию колоды',
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: hasSearch
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
        ),
      ),
    );
  }
}
