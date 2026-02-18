import 'package:flutter/material.dart';

/// Элемент для подиума (топ-N).
class StatsPodiumItem {
  final String label;
  final double value;
  final String subtitle;

  const StatsPodiumItem({
    required this.label,
    required this.value,
    required this.subtitle,
  });
}

/// Подиум для отображения топа (например, топ игроков или колод).
class StatsPodiumView extends StatelessWidget {
  final String title;
  final List<StatsPodiumItem> items;

  const StatsPodiumView({
    super.key,
    required this.title,
    required this.items,
  });

  static const _medals = ['🥇', '🥈', '🥉'];
  static const _placeColors = [
    Color(0xFFD4AF37),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final top3 = items.take(3).toList();
    final rest = items.length > 3 ? items.sublist(3) : <StatsPodiumItem>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (top3.length > 1)
                        Expanded(
                          child: _PodiumPlace(
                            place: 2,
                            medal: _medals[1],
                            item: top3[1],
                            color: _placeColors[1],
                            height: 85,
                          ),
                        ),
                      if (top3.isNotEmpty) ...[
                        if (top3.length > 1) const SizedBox(width: 8),
                        Expanded(
                          child: _PodiumPlace(
                            place: 1,
                            medal: _medals[0],
                            item: top3[0],
                            color: _placeColors[0],
                            height: 110,
                          ),
                        ),
                      ],
                      if (top3.length > 2) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PodiumPlace(
                            place: 3,
                            medal: _medals[2],
                            item: top3[2],
                            color: _placeColors[2],
                            height: 65,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    ...rest.asMap().entries.map((entry) {
                      final idx = entry.key + 4;
                      final item = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey[100],
                            child: Text(
                              '$idx',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                            ),
                          ),
                          title: Text(
                            item.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(item.subtitle),
                          trailing: Text(
                            '${item.value.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final int place;
  final String medal;
  final StatsPodiumItem item;
  final Color color;
  final double height;

  const _PodiumPlace({
    required this.place,
    required this.medal,
    required this.item,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          medal,
          style: const TextStyle(fontSize: 36),
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${item.value.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              '$place',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
