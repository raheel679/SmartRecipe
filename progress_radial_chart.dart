import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Example model – replace with your real one
class NutritionSummary {
  final NutritionData currentWeekAverage;
  final NutritionGoals goals;

  NutritionSummary({
    required this.currentWeekAverage,
    required this.goals,
  });
}

class NutritionData {
  final int calories;
  final int protein;

  NutritionData({
    required this.calories,
    required this.protein,
  });
}

class NutritionGoals {
  final int dailyCalories;
  final int dailyProtein;

  NutritionGoals({
    required this.dailyCalories,
    required this.dailyProtein,
  });
}

class ProgressRadialChart extends StatelessWidget {
  final NutritionSummary summary;

  const ProgressRadialChart({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final calorieProgress = (summary.currentWeekAverage.calories /
            summary.goals.dailyCalories)
        .clamp(0.0, 1.0);

    final proteinProgress = (summary.currentWeekAverage.protein /
            summary.goals.dailyProtein)
        .clamp(0.0, 1.0);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Goal Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRadialChart(
                  'Calories',
                  calorieProgress,
                  summary.currentWeekAverage.calories,
                  summary.goals.dailyCalories,
                  Colors.orange,
                ),
                _buildRadialChart(
                  'Protein',
                  proteinProgress,
                  summary.currentWeekAverage.protein,
                  summary.goals.dailyProtein,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- Radial Chart Builder -------------------

  Widget _buildRadialChart(
    String label,
    double progress,
    int current,
    int goal,
    Color color,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: progress * 100,
                      color: color,
                      radius: 40,
                      title: '${(progress * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: (1 - progress) * 100,
                      color: Colors.grey.shade200,
                      radius: 40,
                      title: '',
                    ),
                  ],
                  sectionsSpace: 0,
                  centerSpaceRadius: 30,
                  startDegreeOffset: -90,
                ),
              ),

              // Center text
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$current',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C4322),
                      ),
                    ),
                    Text(
                      '/ $goal',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
