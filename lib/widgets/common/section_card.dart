import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double elevation;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: elevation,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
