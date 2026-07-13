import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/deck_history.dart';
import 'package:mtg_stats/core/format_utils.dart';
import 'package:mtg_stats/core/timezone_utils.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/pages/games_history_page.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/widgets/common/async_state_views.dart';

/// Список партий, сыгранных конкретной колодой. Тап по партии открывает
/// детальный просмотр (`GameDetailPage`).
class DeckGamesPage extends ConsumerWidget {
  final int deckId;
  final String deckName;

  const DeckGamesPage({
    super.key,
    required this.deckId,
    required this.deckName,
  });

  static const _team1Color = Colors.blue;
  static const _team2Color = Colors.green;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gamesHistoryProvider);
    final tzOffset = ref.watch(currentTimezoneOffsetProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Игры колоды «$deckName»', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        elevation: 4,
      ),
      body: gamesAsync.when(
        loading: () => const AsyncLoadingView(),
        error: (error, _) => AsyncErrorView(message: error.toString()),
        data: (games) {
          final deckGames = gamesForDeck(games, deckId);
          if (deckGames.isEmpty) {
            return const EmptyStateView(
              icon: Icons.history,
              title: 'Эта колода ещё не участвовала в играх',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deckGames.length,
            itemBuilder: (context, index) =>
                _buildGameCard(context, deckGames[index], tzOffset),
          );
        },
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, Game game, int tzOffset) {
    final localDate = TimezoneUtils.toConfiguredTimezone(
      game.startTime,
      timezoneOffsetMinutes: tzOffset,
    );
    final won = deckWon(game, deckId);
    final half = (game.players.length / 2).ceil();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Text(
              FormatUtils.formatDateRu(localDate),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            _resultBadge(won),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < game.players.length; i++)
                _playerLine(game.players[i], i < half),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameDetailPage(
              game: game,
              timezoneOffsetMinutes: tzOffset,
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBadge(bool? won) {
    if (won == null) return const SizedBox.shrink();
    final color = won ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        won ? 'Победа' : 'Поражение',
        style: TextStyle(
          color: color[800],
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _playerLine(GamePlayer player, bool isTeam1) {
    final teamColor = isTeam1 ? _team1Color : _team2Color;
    final isThisDeck = player.deckId == deckId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              '${player.userName} — ${player.deckName}',
              style: TextStyle(
                fontWeight: isThisDeck ? FontWeight.bold : FontWeight.normal,
                color: isThisDeck ? Colors.deepPurple[700] : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
