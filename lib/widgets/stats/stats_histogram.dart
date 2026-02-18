import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Элемент для гистограммы статистики.
class StatsHistogramItem {
  final String label;
  final double value;
  final List<String> tooltipLines;

  const StatsHistogramItem({
    required this.label,
    required this.value,
    required this.tooltipLines,
  });
}

/// Гистограмма для отображения статистики (например, % побед).
class StatsHistogramBar extends StatefulWidget {
  final String title;
  final List<StatsHistogramItem> items;
  final double maxY;
  final String valueSuffix;
  final Color barColor;
  final IconData axisIcon;

  const StatsHistogramBar({
    super.key,
    required this.title,
    required this.items,
    required this.maxY,
    required this.valueSuffix,
    required this.barColor,
    required this.axisIcon,
  });

  @override
  State<StatsHistogramBar> createState() => _StatsHistogramBarState();
}

class _StatsHistogramBarState extends State<StatsHistogramBar> {
  int? _touchedGroupIndex;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final maxVal = items.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMaxY =
        (maxVal > 0 ? maxVal * 1.15 : widget.maxY).clamp(1.0, widget.maxY);

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
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56.0 * items.length.clamp(2, 12).toDouble(),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: effectiveMaxY,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchCallback: (event, response) {
                            setState(() {
                              _touchedGroupIndex =
                                  response?.spot?.touchedBarGroupIndex;
                            });
                          },
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              if (groupIndex >= 0 &&
                                  groupIndex < items.length) {
                                final item = items[groupIndex];
                                return BarTooltipItem(
                                  item.tooltipLines.join('\n'),
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return null;
                            },
                            getTooltipColor: (_) =>
                                Colors.blueGrey.shade800,
                            tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            tooltipMargin: 8,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i >= 0 && i < items.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Icon(
                                      widget.axisIcon,
                                      size: 24,
                                      color: Colors.grey[700],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}${widget.valueSuffix}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[700],
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: effectiveMaxY / 5,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withValues(alpha: 0.2),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: items.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          final isTouched = _touchedGroupIndex == i;
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: item.value.clamp(0.0, effectiveMaxY),
                                color: isTouched
                                    ? widget.barColor.withValues(alpha: 0.8)
                                    : widget.barColor.withValues(alpha: 0.6),
                                width: 20,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ],
                            showingTooltipIndicators: isTouched ? [0] : [],
                          );
                        }).toList(),
                      ),
                      duration: const Duration(milliseconds: 200),
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
