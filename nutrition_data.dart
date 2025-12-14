class NutritionData {
  final DateTime date;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final int fiber;


  const NutritionData({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
  });


  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'fiber': fiber,
    };
  }


  factory NutritionData.fromMap(Map<String, dynamic> map) {
    return NutritionData(
      date: DateTime.parse(map['date']),
      calories: map['calories'] ?? 0,
      protein: map['protein'] ?? 0,
      carbs: map['carbs'] ?? 0,
      fats: map['fats'] ?? 0,
      fiber: map['fiber'] ?? 0,
    );
  }


  // Helper method to check if this day has any data
  bool get hasData => calories > 0 || protein > 0 || carbs > 0 || fats > 0 || fiber > 0;


  // Helper method to create an empty day
  factory NutritionData.empty(DateTime date) {
    return NutritionData(
      date: date,
      calories: 0,
      protein: 0,
      carbs: 0,
      fats: 0,
      fiber: 0,
    );
  }
}


class NutritionGoals {
  final int dailyCalories;
  final int dailyProtein;
  final int dailyCarbs;
  final int dailyFats;
  final int dailyFiber;


  const NutritionGoals({
    required this.dailyCalories,
    required this.dailyProtein,
    required this.dailyCarbs,
    required this.dailyFats,
    required this.dailyFiber,
  });


  factory NutritionGoals.fromGoal(String goal) {
    switch (goal.toLowerCase()) {
      case 'weight loss':
        return const NutritionGoals(
          dailyCalories: 1800,
          dailyProtein: 120,
          dailyCarbs: 180,
          dailyFats: 50,
          dailyFiber: 25,
        );
      case 'muscle gain':
        return const NutritionGoals(
          dailyCalories: 2500,
          dailyProtein: 180,
          dailyCarbs: 280,
          dailyFats: 70,
          dailyFiber: 30,
        );
      case 'healthy lifestyle':
      default:
        return const NutritionGoals(
          dailyCalories: 2200,
          dailyProtein: 150,
          dailyCarbs: 230,
          dailyFats: 60,
          dailyFiber: 25,
        );
    }
  }


  // Helper method to get goal description
  String get description {
    switch (dailyCalories) {
      case 1800:
        return 'Weight Loss Plan';
      case 2500:
        return 'Muscle Gain Plan';
      case 2200:
        return 'Healthy Lifestyle Plan';
      default:
        return 'Custom Nutrition Plan';
    }
  }
}


class NutritionSummary {
  final List<NutritionData> weeklyData;
  final NutritionGoals goals;
  final NutritionData currentWeekAverage;
  final double goalAchievementRate;
  final int daysWithData;
  final String userGoal;


  const NutritionSummary({
    required this.weeklyData,
    required this.goals,
    required this.currentWeekAverage,
    required this.goalAchievementRate,
    required this.daysWithData,
    required this.userGoal,
  });


  // Helper method to get progress insights
  Map<String, dynamic> get insights {
    final trackedDays = daysWithData;
    final completionRate = (trackedDays / 7) * 100;


    return {
      'trackedDays': trackedDays,
      'completionRate': completionRate.round(),
      'goal': userGoal,
      'isOnTrack': goalAchievementRate >= 0.7,
    };
  }
}
