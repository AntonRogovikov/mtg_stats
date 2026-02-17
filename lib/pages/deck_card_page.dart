import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/constants.dart';
import 'package:mtg_stats/models/deck.dart';
import 'package:mtg_stats/pages/full_screen_image_page.dart';
import 'package:mtg_stats/services/deck_image/deck_image_provider.dart';
import 'package:mtg_stats/services/deck_image/deck_image_service.dart';
import 'package:mtg_stats/services/deck_service.dart';

/// Экран редактирования колоды: название, загрузка и удаление изображения.
/// При readOnly=true — только просмотр (без редактирования).
class DeckCardPage extends StatefulWidget {
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
  State<DeckCardPage> createState() => _DeckCardPageState();
}

class _DeckCardPageState extends State<DeckCardPage> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название колоды'),
          backgroundColor: Colors.orange,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Колода сохранена'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(merged);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при сохранении'),
            backgroundColor: Colors.red,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Изображение загружено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Изображение удалено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
          ],
        ),
      ),
      ),
    );
  }
}
