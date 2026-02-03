import 'package:flutter/material.dart';
import 'package:mtg_stats/services/deck_image/deck_image_provider.dart';

/// Полноэкранный просмотр изображения (URL, data URL или ассет).
class FullScreenImagePage extends StatelessWidget {
  final String? imagePathOrUrl;
  final String? assetFallback;

  const FullScreenImagePage({
    super.key,
    this.imagePathOrUrl,
    this.assetFallback,
  });

  @override
  Widget build(BuildContext context) {
    final pathOrUrl = imagePathOrUrl?.isNotEmpty == true ? imagePathOrUrl! : null;
    final provider = deckImageProvider(pathOrUrl);
    final useAsset = provider == null && assetFallback != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: useAsset
                  ? Image.asset(assetFallback!, fit: BoxFit.contain)
                  : provider == null
                      ? const Icon(Icons.image_not_supported, color: Colors.white, size: 64)
                      : Image(
                          image: provider,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, color: Colors.white, size: 64),
                        ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
