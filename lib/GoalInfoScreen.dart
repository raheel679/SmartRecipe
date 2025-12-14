import 'package:flutter/material.dart';
import 'MainNavigation.dart';

class GoalInfoScreen extends StatelessWidget {
  final String goal;
  final double? bmi;

  const GoalInfoScreen({super.key, required this.goal, this.bmi});

  String _getBmiNote(double? bmi) {
    if (bmi == null) return "BMI info not available.";
    if (bmi < 18.5) return "You are underweight. Focus on nutrient-rich meals.";
    if (bmi >= 18.5 && bmi < 25) return "You are in the normal weight range.";
    if (bmi >= 25 && bmi < 30) return "You are overweight. A balanced diet will help.";
    return "You are in the obese range. Focus on healthy weight management.";
  }

  List<String> _getTips(String goal) {
    switch (goal) {
      case "Weight Loss":
        return [
          "Drink water before meals",
          "Avoid sugary drinks",
          "Focus on lean proteins"
        ];
      case "Muscle Gain":
        return [
          "Eat 5–6 smaller meals",
          "Don’t skip carbs",
          "Increase protein intake"
        ];
      case "Healthy Lifestyle":
        return [
          "Add more vegetables",
          "Eat on time",
          "Reduce processed foods"
        ];
      default:
        return ["Stay consistent with your meals"];
    }
  }

  IconData _getGoalIcon(String goal) {
    switch (goal) {
      case "Weight Loss":
        return Icons.trending_down;
      case "Muscle Gain":
        return Icons.fitness_center;
      case "Healthy Lifestyle":
        return Icons.eco;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tips = _getTips(goal);
    const primaryColor = Color(0xFF1C4322); // Dark green
    const lightGreen = Color(0xFFE8F5E8); // Light green

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 249, 249),
      // appBar: AppBar(
      //   title: const Text(
      //     "Your Goal Plan",
      //     style: TextStyle(
      //       fontWeight: FontWeight.bold,
      //       color: Colors.white,
      //     ),
      //   ),
      //   centerTitle: true,
      //   backgroundColor: primaryColor,
      //   elevation: 0,
      // ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [lightGreen, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _getGoalIcon(goal),
                    size: 40,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Your Plan:",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          goal,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BMI Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fitness_center, color: primaryColor, size: 24),
                      SizedBox(width: 12),
                      Text(
                        "BMI Assessment",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C4322),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getBmiNote(bmi),
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tips Section
            const Text(
              "Tips & Guidelines",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ...tips.map(
              (tip) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(width: 4, color: primaryColor),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: Color(0xFF1C4322),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: primaryColor.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MainNavigation(goal: goal),
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Continue to Your Plan",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
