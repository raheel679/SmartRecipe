import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// Example model — replace with your actual model
class NutritionData {
  final int protein;
  final int carbs;
  final int fats;
  final DateTime date;

  NutritionData({
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.date,
  });
}

class DailyMacroBarChart extends StatelessWidget {
  final List<NutritionData> weeklyData;

  const DailyMacroBarChart({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Macronutrient Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Protein, Carbs & Fats per Day',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.white,
                      tooltipBorder: BorderSide(color: Colors.grey.shade300),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = _getDayAbbreviation(weeklyData[groupIndex].date);
                        final nutrient = _getNutrientName(rodIndex);

                        return BarTooltipItem(
                          '$day - $nutrient\n${rod.toY.toInt()}g',
                          TextStyle(
                            color: _getNutrientColor(rodIndex),
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),

                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < weeklyData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _getDayAbbreviation(weeklyData[index].date),
                                style: const TextStyle(fontSize: 10),
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
                        reservedSize: 40,
                        interval: _getInterval(),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}g',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),

                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getInterval(),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                    ),
                  ),

                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade400),
                  ),

                  barGroups: _generateBarGroups(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Chart Helpers ----------------

  List<BarChartGroupData> _generateBarGroups() {
    return weeklyData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;

      return BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: data.protein.toDouble(),
            color: Colors.blue,
            width: 8,
            borderRadius: BorderRadius.circular(2),
          ),
          BarChartRodData(
            toY: data.carbs.toDouble(),
            color: Colors.green,
            width: 8,
            borderRadius: BorderRadius.circular(2),
          ),
          BarChartRodData(
            toY: data.fats.toDouble(),
            color: Colors.orange,
            width: 8,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    }).toList();
  }

  double _getMaxY() {
    final maxProtein = weeklyData.map((e) => e.protein).reduce(max);
    final maxCarbs = weeklyData.map((e) => e.carbs).reduce(max);
    final maxFats = weeklyData.map((e) => e.fats).reduce(max);

    final maxValue = [maxProtein, maxCarbs, maxFats].reduce(max);
    return (maxValue * 1.2).toDouble(); // Add padding for visual spacing
  }

  double _getInterval() {
    final maxY = _getMaxY();
    if (maxY <= 100) return 20;
    if (maxY <= 200) return 40;
    if (maxY <= 300) return 60;
    return 80;
  }

  String _getDayAbbreviation(DateTime date) => DateFormat('E').format(date);

  String _getNutrientName(int rodIndex) {
    switch (rodIndex) {
      case 0:
        return 'Protein';
      case 1:
        return 'Carbs';
      case 2:
        return 'Fats';
      default:
        return '';
    }
  }

  Color _getNutrientColor(int rodIndex) {
    switch (rodIndex) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      default:
        return Colors.black;
    }
  }
}
