import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Элемент для круговой диаграммы.
class StatsPieItem {
  final String label;
  final double value;
  final String tooltip;

  const StatsPieItem({
    required this.label,
    required this.value,
    required this.tooltip,
  });
}

/// Цвета по умолчанию для круговой диаграммы.
const List<Color> statsPieDefaultColors = [
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
  Color(0xFFEF5350),
  Color(0xFFFFA726),
  Color(0xFFAB47BC),
  Color(0xFF66BB6A),
];

/// Круговая диаграмма для отображения статистики.
class StatsPieChartView extends StatefulWidget {
  final String title;
  final List<StatsPieItem> items;
  final List<Color> colors;

  const StatsPieChartView({
    super.key,
    required this.title,
    required this.items,
    required this.colors,
  });

  @override
  State<StatsPieChartView> createState() => _StatsPieChartViewState();
}

class _StatsPieChartViewState extends State<StatsPieChartView> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final total = items.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = math.min(constraints.maxWidth, constraints.maxHeight);
        final chartSize = maxSide.clamp(220.0, 420.0);
        final baseRadius = chartSize * 0.28;
        final touchedRadius = baseRadius * 1.15;

        final sections = items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final color = widget.colors[i % widget.colors.length];
          final isTouched = _touchedIndex == i;
          return PieChartSectionData(
            value: item.value,
            title: '${(item.value / total * 100).toStringAsFixed(0)}%',
            color: isTouched
                ? color.withValues(alpha: 0.9)
                : color.withValues(alpha: 0.75),
            radius: isTouched ? touchedRadius : baseRadius,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          );
        }).toList();

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
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: chartSize,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: chartSize * 0.16,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              _touchedIndex = response
                                  ?.touchedSection?.touchedSectionIndex;
                            });
                          },
                        ),
                        sectionsSpace: 2,
                      ),
                      duration: const Duration(milliseconds: 200),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final color =
                            widget.colors[i % widget.colors.length];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 500),
                                child: Text(
                                  item.label,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(item.value / total * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
