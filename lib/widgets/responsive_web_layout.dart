import 'package:flutter/material.dart';
import 'package:mtg_stats/core/constants.dart';

/// Обёртка для веб/десктоп: на широких экранах центрирует контент и ограничивает
/// максимальную ширину, чтобы интерфейс не растягивался на весь экран.
class ResponsiveWebLayout extends StatelessWidget {
  const ResponsiveWebLayout({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useDesktopLayout = width > AppConstants.desktopBreakpoint;

    if (!useDesktopLayout) {
      return child;
    }

    return Container(
      width: double.infinity,
      color: Colors.grey[200],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
          child: Material(
            elevation: 4,
            shadowColor: Colors.black26,
            child: child,
          ),
        ),
      ),
    );
  }
}
