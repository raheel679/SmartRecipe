import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// Example models (replace with your real ones)
class NutritionData {
  final DateTime date;
  final int protein;
  final int carbs;
  final int fats;

  NutritionData({
    required this.date,
    required this.protein,
    required this.carbs,
    required this.fats,
  });
}

class NutritionGoals {
  final int protein;
  final int carbs;
  final int fats;

  NutritionGoals({
    required this.protein,
    required this.carbs,
    required this.fats,
  });
}

class MacroLineChart extends StatelessWidget {
  final List<NutritionData> weeklyData;
  final NutritionGoals goals;

  const MacroLineChart({
    super.key,
    required this.weeklyData,
    required this.goals,
  });

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
              'Weekly Macronutrients Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Protein, Carbs & Fats Over Time',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // LINE CHART
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: _getHorizontalInterval(),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),

                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
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
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: _getHorizontalInterval(),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}g',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),

                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade400, width: 1),
                  ),

                  minY: 0,
                  maxY: _getMaxY(),

                  lineBarsData: [
                    _buildProteinLine(),
                    _buildCarbsLine(),
                    _buildFatsLine(),
                  ],

                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.white,
                      tooltipBorder: BorderSide(color: Colors.grey.shade300),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final nutrient = _getNutrientName(spot.barIndex);
                          final value = spot.y.toInt();
                          return LineTooltipItem(
                            '$nutrient: ${value}g',
                            TextStyle(
                              color: _getNutrientColor(spot.barIndex),
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  // ------------------------ LINE BUILDERS ------------------------

  LineChartBarData _buildProteinLine() {
    return LineChartBarData(
      spots: weeklyData.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.protein.toDouble());
      }).toList(),
      isCurved: true,
      color: Colors.blue,
      barWidth: 3,
      belowBarData: BarAreaData(
        show: true,
        color: Colors.blue.withOpacity(0.1),
      ),
      dotData: const FlDotData(show: false),
    );
  }

  LineChartBarData _buildCarbsLine() {
    return LineChartBarData(
      spots: weeklyData.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.carbs.toDouble());
      }).toList(),
      isCurved: true,
      color: Colors.green,
      barWidth: 3,
      belowBarData: BarAreaData(
        show: true,
        color: Colors.green.withOpacity(0.1),
      ),
      dotData: const FlDotData(show: false),
    );
  }

  LineChartBarData _buildFatsLine() {
    return LineChartBarData(
      spots: weeklyData.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.fats.toDouble());
      }).toList(),
      isCurved: true,
      color: Colors.orange,
      barWidth: 3,
      belowBarData: BarAreaData(
        show: true,
        color: Colors.orange.withOpacity(0.1),
      ),
      dotData: const FlDotData(show: false),
    );
  }

  // ------------------------ LEGEND ------------------------

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem('Protein', Colors.blue),
        _buildLegendItem('Carbs', Colors.green),
        _buildLegendItem('Fats', Colors.orange),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // ------------------------ HELPERS ------------------------

  double _getMaxY() {
    final maxProtein = weeklyData.map((e) => e.protein).reduce(max);
    final maxCarbs = weeklyData.map((e) => e.carbs).reduce(max);
    final maxFats = weeklyData.map((e) => e.fats).reduce(max);

    final maxValue = [maxProtein, maxCarbs, maxFats].reduce(max);
    return (maxValue * 1.2).toDouble(); // padding
  }

  double _getHorizontalInterval() {
    final maxY = _getMaxY();
    if (maxY <= 100) return 20;
    if (maxY <= 200) return 40;
    if (maxY <= 300) return 60;
    return 80;
  }

  String _getDayAbbreviation(DateTime date) {
    return DateFormat('E').format(date); // Mon, Tue...
  }

  String _getNutrientName(int barIndex) {
    switch (barIndex) {
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

  Color _getNutrientColor(int barIndex) {
    switch (barIndex) {
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
