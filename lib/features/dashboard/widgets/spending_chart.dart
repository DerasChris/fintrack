// lib/features/dashboard/widgets/spending_chart.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/transaction.dart';

class SpendingChart extends StatefulWidget {
  final Map<Category, double> categoryTotals;

  const SpendingChart({super.key, required this.categoryTotals});

  @override
  State<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Dona centrada
          SizedBox(
            height: 80,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response?.touchedSection == null) {
                        _touchedIndex = -1;
                      } else {
                        _touchedIndex =
                            response!.touchedSection!.touchedSectionIndex;
                      }
                    });
                  },
                ),
                sections: entries.asMap().entries.map((e) {
                  final isTouched = e.key == _touchedIndex;
                  final color = categoryColor(e.value.key);
                  final pct = (e.value.value / total * 100);

                  return PieChartSectionData(
                    value: e.value.value,
                    color: color,
                    radius: isTouched ? 32 : 26,
                    title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    borderSide: isTouched
                        ? BorderSide(color: color.withValues(alpha: 0.8), width: 2)
                        : BorderSide.none,
                  );
                }).toList(),
                centerSpaceRadius: 18,
                sectionsSpace: 2,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Leyendas abajo en Wrap horizontal
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: entries.take(6).map((entry) {
              final color = categoryColor(entry.key);
              final pct = (entry.value / total * 100);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.key.label.split(' ').last} ${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),

          const Divider(color: AppColors.border, height: 24),

          // Top categorías con montos
          ...entries.take(4).map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: categoryColor(entry.key).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.key.label,
                    style: TextStyle(
                      color: categoryColor(entry.key),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${entry.value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
