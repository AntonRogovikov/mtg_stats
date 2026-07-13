import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/core/deck_history.dart';
import 'package:mtg_stats/core/format_utils.dart';
import 'package:mtg_stats/core/timezone_utils.dart';
import 'package:mtg_stats/core/ui_feedback.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/models/game.dart';
import 'package:mtg_stats/models/stats.dart';
import 'package:mtg_stats/pages/deck_games_page.dart';
import 'package:mtg_stats/pages/full_screen_image_page.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/providers/stats_providers.dart';
import 'package:mtg_stats/services/deck_image/deck_image_provider.dart';
import 'package:mtg_stats/services/deck_image/deck_image_service.dart';
import 'package:mtg_stats/services/deck_service.dart';

/// Экран редактирования колоды: название, загрузка и удаление изображения.
/// При readOnly=true — только просмотр (без редактирования).
class DeckCardPage extends ConsumerStatefulWidget {
  final Deck deck;
  final DeckService deckService;
  final bool readOnly;

  const DeckCardPage({
    super.key,
    required this.deck,
    required this.deckService,
    this.readOnly = false,
  });

  @override
  ConsumerState<DeckCardPage> createState() => _DeckCardPageState();
}

class _DeckCardPageState extends ConsumerState<DeckCardPage> {
  late TextEditingController _nameController;
  late Deck _deck;
  bool _isSaving = false;
  bool _isUploading = false;
  bool _isDeleting = false;
  final DeckImageService _imageService = DeckImageService();

  static const String _defaultImageAsset = AppConstants.defaultDeckImageAsset;

  @override
  void initState() {
    super.initState();
    _deck = widget.deck;
    _nameController = TextEditingController(text: _deck.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      UiFeedback.showWarning(context, 'Введите название колоды');
      return;
    }
    final deckToSave = _deck.copyWith(name: newName);
    if (deckToSave.name == widget.deck.name &&
        deckToSave.imageUrl == widget.deck.imageUrl &&
        deckToSave.avatarUrl == widget.deck.avatarUrl) {
      Navigator.of(context).pop(_deck);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await widget.deckService.updateDeck(deckToSave);
      if (mounted) {
        final merged = updated.copyWith(
          imageUrl: updated.imageUrl ?? _deck.imageUrl,
          avatarUrl: updated.avatarUrl ?? _deck.avatarUrl,
        );
        setState(() => _deck = merged);
        UiFeedback.showSuccess(context, 'Колода сохранена');
        Navigator.of(context).pop(merged);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        UiFeedback.showError(context, 'Ошибка при сохранении');
      }
    }
  }

  Future<void> _uploadAvatar() async {
    final xFile = await _imageService.pickImage();
    if (xFile == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final result = await _imageService.saveFullAndAvatar(xFile);
      if (result == null || !mounted) {
        setState(() => _isUploading = false);
        return;
      }
      final updated = await widget.deckService.uploadDeckImage(
        _deck,
        result.fullBytes,
        result.avatarBytes,
      );
      if (mounted) {
        setState(() {
          _deck = updated;
          _isUploading = false;
        });
        UiFeedback.showSuccess(context, 'Изображение загружено');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        UiFeedback.showError(context, 'Ошибка: $e');
      }
    }
  }

  Future<void> _deleteImage() async {
    if (_deck.imageUrl == null && _deck.avatarUrl == null) return;
    if (_isUploading) return;
    setState(() => _isDeleting = true);
    try {
      final updated = await widget.deckService.deleteDeckImage(_deck);
      if (mounted) {
        setState(() {
          _deck = updated;
          _isDeleting = false;
        });
        UiFeedback.showSuccess(context, 'Изображение удалено');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        UiFeedback.showError(context, 'Ошибка: $e');
      }
    }
  }

  void _openFullScreenImage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(
          imagePathOrUrl: _deck.imageUrl ?? _deck.avatarUrl,
          assetFallback: _defaultImageAsset,
        ),
      ),
    );
  }

  Widget _buildDeckImage() {
    final url = _deck.imageUrl ?? _deck.avatarUrl;
    final provider = deckImageProvider(url);
    if (provider == null) {
      return Image.asset(_defaultImageAsset, fit: BoxFit.contain);
    }
    return Image(
      image: provider,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Image.asset(_defaultImageAsset, fit: BoxFit.contain),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_deck);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text('Карточка колоды', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          if (!readOnly) ...[
            if (_isSaving || _isUploading || _isDeleting)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _save,
                child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
              ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenSize = MediaQuery.sizeOf(context);
                      final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
                      const padding = 24.0 * 2;
                      const maxWidthFraction = 0.96;
                      const maxHeightFraction = 0.58;
                      final maxW = (screenSize.width - padding) * maxWidthFraction;
                      final maxH = (screenSize.height - padding) * maxHeightFraction;
                      // Пропорции карты MTG ~ 63:88 — контейнер подстраивается под них,
                      // чтобы не было серых полос по бокам при BoxFit.contain.
                      const cardAspect = 63.0 / 88.0;
                      double w = maxW;
                      double h = w / cardAspect;
                      if (h > maxH) {
                        h = maxH;
                        w = h * cardAspect;
                      }
                      return GestureDetector(
                        onLongPress: _openFullScreenImage,
                        child: Container(
                          width: w,
                          height: h,
                          decoration: BoxDecoration(
                            color: scaffoldBg,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildDeckImage(),
                              if (_isUploading || _isDeleting)
                                const Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(color: Colors.black38),
                                    child: Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (!readOnly) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: (_isUploading || _isDeleting) ? null : _uploadAvatar,
                          icon: const Icon(Icons.add_photo_alternate, size: 20),
                          label: const Text('Загрузить картинку'),
                        ),
                        if (_deck.imageUrl != null || _deck.avatarUrl != null) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: (_isUploading || _isDeleting) ? null : _deleteImage,
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            label: const Text('Удалить картинку', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Название колоды',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              readOnly: readOnly,
              decoration: InputDecoration(
                hintText: readOnly ? '' : 'Введите название',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
              ),
              textInputAction: readOnly ? null : TextInputAction.done,
              onSubmitted: readOnly ? null : (_) => _save(),
            ),
            const SizedBox(height: 24),
            _buildStatsSection(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final statsData = ref.watch(statsDataProvider).asData?.value;
    final tzOffset = ref.watch(currentTimezoneOffsetProvider);
    final games = ref.watch(gamesHistoryProvider).asData?.value ?? const <Game>[];

    DeckStats? deckStats;
    if (statsData != null) {
      for (final stat in statsData.deckStats) {
        if (stat.deckId == _deck.id) {
          deckStats = stat;
          break;
        }
      }
    }

    final deckGames = gamesForDeck(games, _deck.id);
    final gamesCount = deckStats?.gamesCount ?? deckGames.length;
    final winsCount = deckStats?.winsCount ?? 0;
    final winPercent = deckStats?.winPercent ?? 0;

    final firstDate = firstPlayedDate(deckGames);
    final lastDate = lastPlayedDate(deckGames);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика колоды',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statTile(Icons.casino, 'Игр', '$gamesCount', Colors.deepPurple),
              _statTile(
                  Icons.emoji_events, 'Побед', '$winsCount', Colors.amber[800]!),
              _statTile(Icons.percent, 'Винрейт',
                  '${winPercent.toStringAsFixed(0)}%', Colors.green[700]!),
            ],
          ),
          const SizedBox(height: 16),
          _dateRow(Icons.schedule, 'Последняя игра', lastDate, tzOffset,
              showDaysAgo: true),
          const SizedBox(height: 8),
          _dateRow(Icons.event, 'Первая игра', firstDate, tzOffset),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: deckGames.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DeckGamesPage(
                            deckId: _deck.id,
                            deckName: _deck.name,
                          ),
                        ),
                      ),
              icon: const Icon(Icons.history_edu),
              label: Text('Игры этой колоды (${deckGames.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(
    IconData icon,
    String label,
    DateTime? date,
    int tzOffset, {
    bool showDaysAgo = false,
  }) {
    String valueText;
    if (date == null) {
      valueText = '—';
    } else {
      final local = TimezoneUtils.toConfiguredTimezone(
        date,
        timezoneOffsetMinutes: tzOffset,
      );
      valueText = FormatUtils.formatDateRu(local);
      if (showDaysAgo) {
        final today = DateTime.now();
        final days = DateTime(today.year, today.month, today.day)
            .difference(DateTime(local.year, local.month, local.day))
            .inDays;
        valueText += ' (${FormatUtils.daysAgoRu(days)})';
      }
    }
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[700])),
        Expanded(
          child: Text(
            valueText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
