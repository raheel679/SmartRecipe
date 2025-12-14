
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smart_recipe_app/MealRecommendationPage%20.dart';
import 'weekly_plan_page.dart';

class AnalyticsPage extends StatefulWidget {
   final String goal;
  final String dietType;
  final String dislikes;
  final Map<String, dynamic> userPreferences;
   const AnalyticsPage({super.key,
    required this.goal,
    required this.dietType,
    required this.dislikes,
    required this.userPreferences,});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late Future<UserAnalytics> _analyticsFuture;
  DateTime? _userStartDate;
  UserAbsenceInfo? _absenceInfo;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _loadUserAnalytics();
  }

  Future<UserAnalytics> _loadUserAnalytics() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get user's start date from progress data
    final progressDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('progress')
        .doc('current_week')
        .get();

    if (progressDoc.exists) {
      final data = progressDoc.data()!;
      _userStartDate = (data['planStartDate'] as Timestamp).toDate();
    } else {
      // If no progress data, use account creation date
      _userStartDate = user.metadata.creationTime;
    }

    // Get user's cooking history
    final historySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('cookedAt', descending: true)
        .get();

    // Get user preferences for goals
    final prefsSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('questionnaires')
        .get();

    // Check for user absence
    _absenceInfo = await _checkUserAbsence(historySnapshot.docs);

    return _calculateAnalytics(historySnapshot.docs, prefsSnapshot.docs);
  }

  Future<UserAbsenceInfo?> _checkUserAbsence(List<QueryDocumentSnapshot> historyDocs) async {
    if (historyDocs.isEmpty) {
      return UserAbsenceInfo(
        isAbsent: true,
        absentDays: 1,
        lastActivityDate: null,
        message: "Welcome! Start your nutrition journey by cooking your first meal.",
        suggestion: "Try cooking a recipe from your plan today!",
      );
    }

    final now = DateTime.now();
    final lastActivityDoc = historyDocs.first;
    final lastActivityData = lastActivityDoc.data() as Map<String, dynamic>;
    final lastActivityTimestamp = lastActivityData['cookedAt'] as Timestamp;
    final lastActivityDate = lastActivityTimestamp.toDate();
    
    final daysSinceLastActivity = now.difference(lastActivityDate).inDays;
    
    if (daysSinceLastActivity >= 1) {
      String message;
      String suggestion;
      Color cardColor;
      
      if (daysSinceLastActivity == 1) {
        message = "You haven't cooked anything yesterday. Let's get back on track!";
        suggestion = "Cook a meal today to maintain your streak.";
        cardColor = Colors.orange.shade100;
      } else if (daysSinceLastActivity <= 3) {
        message = "You've been absent for $daysSinceLastActivity days. Consistency is key to success!";
        suggestion = "Try cooking a simple recipe to restart your habit.";
        cardColor = Colors.orange.shade200;
      } else {
        message = "It's been $daysSinceLastActivity days since your last cooked meal. Don't give up!";
        suggestion = "Try cooking a simple recipe to restart your habit.";
        cardColor = Colors.red.shade100;
      }
      
      return UserAbsenceInfo(
        isAbsent: true,
        absentDays: daysSinceLastActivity,
        lastActivityDate: lastActivityDate,
        message: message,
        suggestion: suggestion,
        cardColor: cardColor,
      );
    }
    
    return null;
  }

  UserAnalytics _calculateAnalytics(
    List<QueryDocumentSnapshot> historyDocs,
    List<QueryDocumentSnapshot> prefsDocs,
  ) {
    final now = DateTime.now();
    final daysSinceStart = _userStartDate != null 
        ? now.difference(_userStartDate!).inDays
        : 0;
    
    // Determine analysis period based on days since start
    final analysisPeriod = _getAnalysisPeriod(daysSinceStart);
    final periodDays = analysisPeriod.days;

    // Calculate start date for analysis
    final analysisStartDate = now.subtract(Duration(days: periodDays - 1));

    // Filter history for analysis period
    final recentHistory = historyDocs.where((doc) {
      final cookedAt = (doc.data() as Map<String, dynamic>)['cookedAt'] as Timestamp;
      return cookedAt.toDate().isAfter(analysisStartDate.subtract(const Duration(days: 1)));
    }).toList();

    // Extract user goals from preferences
    final userGoals = _extractUserGoals(prefsDocs);

    // Calculate daily nutrition data
    final dailyData = _calculateDailyData(recentHistory, analysisStartDate, periodDays);

    // Calculate averages and totals
    final averages = _calculateAverages(dailyData);
    final totals = _calculateTotals(dailyData);

    // Calculate goal achievement
    final goalAchievement = _calculateGoalAchievement(averages, userGoals, dailyData.length);

    // Generate insights including absence insights
    final insights = _generateInsights(dailyData, userGoals, daysSinceStart, _absenceInfo);

    return UserAnalytics(
      analysisPeriod: analysisPeriod,
      daysSinceStart: daysSinceStart,
      dailyData: dailyData,
      averages: averages,
      totals: totals,
      userGoals: userGoals,
      goalAchievement: goalAchievement,
      insights: insights,
      absenceInfo: _absenceInfo,
    );
  }

  AnalysisPeriod _getAnalysisPeriod(int daysSinceStart) {
    if (daysSinceStart < 2) {
      return AnalysisPeriod('Today Only', 1, 'Starting your journey!');
    } else if (daysSinceStart < 7) {
      return AnalysisPeriod('Last $daysSinceStart Days', daysSinceStart, 'Early progress tracking');
    } else if (daysSinceStart < 30) {
      final days = daysSinceStart.clamp(7, 30);
      return AnalysisPeriod('Last $days Days', days, 'Building consistent habits');
    } else {
      return AnalysisPeriod('Last 30 Days', 30, 'Long-term progress view');
    }
  }

  UserGoals _extractUserGoals(List<QueryDocumentSnapshot> prefsDocs) {
    // Default goals
    var goals = UserGoals(
      dailyCalories: 2000,
      dailyProtein: 50,
      dailyCarbs: 250,
      dailyFats: 70,
      weeklyMeals: 21,
    );

    // Extract goals from preferences
    for (final doc in prefsDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final goal = data['goalQuestion']?.toString() ?? '';
      
      if (goal.contains('Weight Loss') || goal.contains('Feeling full')) {
        goals = goals.copyWith(dailyCalories: 1800, dailyProtein: 60);
      } else if (goal.contains('Muscle Gain') || goal.contains('Maximum protein')) {
        goals = goals.copyWith(dailyCalories: 2500, dailyProtein: 80);
      } else if (goal.contains('Healthy Lifestyle') || goal.contains('Nutritional balance')) {
        goals = goals.copyWith(dailyCalories: 2200, dailyProtein: 65);
      }
    }

    return goals;
  }

  List<DailyNutrition> _calculateDailyData(
    List<QueryDocumentSnapshot> historyDocs,
    DateTime startDate,
    int periodDays,
  ) {
    final dailyData = <DailyNutrition>[];
    
    for (int i = 0; i < periodDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dayHistory = historyDocs.where((doc) {
        final cookedAt = (doc.data() as Map<String, dynamic>)['cookedAt'] as Timestamp;
        return _isSameDay(cookedAt.toDate(), date);
      }).toList();

      final dayNutrition = _calculateDayNutrition(dayHistory);
      dailyData.add(DailyNutrition(
        date: date,
        calories: dayNutrition['calories'] ?? 0,
        protein: dayNutrition['protein'] ?? 0,
        carbs: dayNutrition['carbs'] ?? 0,
        fats: dayNutrition['fats'] ?? 0,
        fiber: dayNutrition['fiber'] ?? 0,
        mealsCount: dayHistory.length,
      ));
    }

    return dailyData;
  }

  Map<String, int> _calculateDayNutrition(List<QueryDocumentSnapshot> dayHistory) {
    int calories = 0;
    int protein = 0;
    int carbs = 0;
    int fats = 0;
    int fiber = 0;

    for (final doc in dayHistory) {
      final data = doc.data() as Map<String, dynamic>;
      final recipe = data['recipe'] as Map<String, dynamic>? ?? {};
      
      calories += (recipe['calories'] as int? ?? 0);
      protein += (recipe['protein'] as int? ?? 0);
      carbs += (recipe['carbs'] as int? ?? 0);
      fats += (recipe['fats'] as int? ?? 0);
      fiber += (recipe['fiber'] as int? ?? 0);
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'fiber': fiber,
    };
  }

  NutritionAverages _calculateAverages(List<DailyNutrition> dailyData) {
    final daysWithData = dailyData.where((day) => day.mealsCount > 0).toList();
    
    if (daysWithData.isEmpty) {
      return NutritionAverages(
        calories: 0,
        protein: 0,
        carbs: 0,
        fats: 0,
        fiber: 0,
        mealsPerDay: 0,
      );
    }

    return NutritionAverages(
      calories: (daysWithData.map((e) => e.calories).reduce((a, b) => a + b) / daysWithData.length).round(),
      protein: (daysWithData.map((e) => e.protein).reduce((a, b) => a + b) / daysWithData.length).round(),
      carbs: (daysWithData.map((e) => e.carbs).reduce((a, b) => a + b) / daysWithData.length).round(),
      fats: (daysWithData.map((e) => e.fats).reduce((a, b) => a + b) / daysWithData.length).round(),
      fiber: (daysWithData.map((e) => e.fiber).reduce((a, b) => a + b) / daysWithData.length).round(),
      mealsPerDay: (daysWithData.map((e) => e.mealsCount).reduce((a, b) => a + b) / daysWithData.length),
    );
  }

  NutritionTotals _calculateTotals(List<DailyNutrition> dailyData) {
    return NutritionTotals(
      totalCalories: dailyData.map((e) => e.calories).reduce((a, b) => a + b),
      totalProtein: dailyData.map((e) => e.protein).reduce((a, b) => a + b),
      totalCarbs: dailyData.map((e) => e.carbs).reduce((a, b) => a + b),
      totalFats: dailyData.map((e) => e.fats).reduce((a, b) => a + b),
      totalFiber: dailyData.map((e) => e.fiber).reduce((a, b) => a + b),
      totalMeals: dailyData.map((e) => e.mealsCount).reduce((a, b) => a + b),
      daysTracked: dailyData.where((day) => day.mealsCount > 0).length,
    );
  }

  GoalAchievement _calculateGoalAchievement(
    NutritionAverages averages,
    UserGoals goals,
    int totalDays,
  ) {
    final trackedDays = totalDays;
    
    // Calculate achievement rates (0.0 to 1.0)
    final calorieRate = goals.dailyCalories > 0 
        ? (averages.calories / goals.dailyCalories).clamp(0.0, 1.0)
        : 0.0;
    
    final proteinRate = goals.dailyProtein > 0
        ? (averages.protein / goals.dailyProtein).clamp(0.0, 1.0)
        : 0.0;

    final trackingRate = trackedDays / totalDays;

    // Overall achievement (weighted average)
    final overallRate = (calorieRate * 0.4 + proteinRate * 0.4 + trackingRate * 0.2);

    return GoalAchievement(
      calorieAchievement: calorieRate,
      proteinAchievement: proteinRate,
      trackingConsistency: trackingRate,
      overallAchievement: overallRate,
    );
  }

  AnalyticsInsights _generateInsights(
    List<DailyNutrition> dailyData,
    UserGoals goals,
    int daysSinceStart,
    UserAbsenceInfo? absenceInfo,
  ) {
    final insights = <String>[];
    final trends = <String>[];
    final recommendations = <String>[];
    final actions = <String>[];

    final trackedDays = dailyData.where((day) => day.mealsCount > 0).length;
    final averages = _calculateAverages(dailyData);

    // Add absence message as first insight if user is absent
    if (absenceInfo != null && absenceInfo.isAbsent) {
      insights.add(absenceInfo.message);
      actions.add(absenceInfo.suggestion);
      
      if (absenceInfo.absentDays >= 2) {
        actions.add('View quick recipes');
        actions.add('Set daily reminder');
      }
    }

    // Basic insights
    if (daysSinceStart < 3 && absenceInfo == null) {
      insights.add('Welcome! You\'ve just started your nutrition journey.');
      recommendations.add('Try to log at least one meal per day to build the habit.');
    } else if (trackedDays == 0 && absenceInfo == null) {
      insights.add('Start tracking your meals to see personalized analytics.');
      recommendations.add('Mark recipes as cooked after you prepare them.');
    } else if (absenceInfo == null) {
      insights.add('You\'ve tracked $trackedDays ${trackedDays == 1 ? 'day' : 'days'} of meals.');
      
      // Calorie insights
      if (averages.calories > 0) {
        final calorieDiff = (averages.calories - goals.dailyCalories).abs();
        final caloriePct = (calorieDiff / goals.dailyCalories * 100).round();
        
        if (averages.calories < goals.dailyCalories * 0.8) {
          insights.add('Your calorie intake is $caloriePct% below your goal.');
          recommendations.add('Consider adding healthy snacks to meet your energy needs.');
        } else if (averages.calories > goals.dailyCalories * 1.2) {
          insights.add('Your calorie intake is $caloriePct% above your goal.');
          recommendations.add('Focus on portion control and nutrient-dense foods.');
        } else {
          insights.add('Great! Your calorie intake aligns well with your goals.');
        }
      }

      // Protein insights
      if (averages.protein > 0) {
        if (averages.protein < goals.dailyProtein * 0.7) {
          insights.add('Your protein intake could be increased for better results.');
          recommendations.add('Include protein-rich foods like chicken, fish, or legumes.');
        } else if (averages.protein >= goals.dailyProtein) {
          insights.add('Excellent protein intake! Keep it up.');
        }
      }

      // Consistency insights
      final consistencyRate = trackedDays / dailyData.length;
      if (consistencyRate < 0.5) {
        insights.add('Try to track meals more consistently for better insights.');
        recommendations.add('Set a daily reminder to log your meals.');
      } else if (consistencyRate >= 0.8) {
        insights.add('Great tracking consistency! This provides reliable data.');
      }
    }

    // Progress-based recommendations
    if (daysSinceStart >= 7 && trackedDays >= 5) {
      recommendations.add('Review your weekly patterns to identify areas for improvement.');
    }
    
    if (daysSinceStart >= 30) {
      recommendations.add('Consider adjusting your goals based on your month-long progress.');
    }

    return AnalyticsInsights(
      insights: insights,
      trends: trends,
      recommendations: recommendations,
      actions: actions,
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  void _refreshAnalytics() {
    setState(() {
      _analyticsFuture = _loadUserAnalytics();
    });
  }

  void _handleAbsenceAction(String action, BuildContext context) {
    if (action.contains('quick recipes')) {
      // Navigate to quick recipes page
      Navigator.pushNamed(context, '/recipes', arguments: {'filter': 'quick'});
    } else if (action.contains('reminder')) {
      // Open reminder dialog
      _showReminderDialog(context);
    } else if (action.contains('cook')) {
      // Navigate to plan page
      Navigator.pushNamed(context, '/plan');
    }
  }

  void _showReminderDialog(BuildContext context) {
    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     //title: const Text('Set Daily Reminder'),
    //     //content: const Text('Would you like to set a daily reminder to cook your meals?'),
    //     actions: [
    //       TextButton(
    //         onPressed: () => Navigator.pop(context),
    //         child: const Text('Cancel'),
    //       ),
    //       ElevatedButton(
    //         onPressed: () {
    //           // Implement reminder logic here
    //           Navigator.pop(context);
    //           ScaffoldMessenger.of(context).showSnackBar(
    //             const SnackBar(content: Text('Daily reminder set!')),
    //           );
    //         },
    //         child: const Text('Set Reminder'),
    //       ),
    //     ],
    //   ),
   // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Nutrition Analytics'),
        backgroundColor: const Color(0xFFF8F8F8),
        foregroundColor: const Color(0xFF1C4322),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAnalytics,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: FutureBuilder<UserAnalytics>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return _buildEmptyState();
          }

          final analytics = snapshot.data!;
          return _buildAnalyticsDashboard(analytics, context);
        },
      ),
    );
  }

  Widget _buildAnalyticsDashboard(UserAnalytics analytics, BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPeriodHeader(analytics),
          if (analytics.absenceInfo != null) ...[
            const SizedBox(height: 16),
            _buildAbsenceCard(analytics.absenceInfo!, context),
          ],
          const SizedBox(height: 20),
          _buildOverviewCard(analytics),
          const SizedBox(height: 20),
          _buildNutritionAverages(analytics),
          const SizedBox(height: 20),
          _buildGoalProgress(analytics),
          const SizedBox(height: 20),
          _buildDailyChart(analytics),
          const SizedBox(height: 20),
          _buildInsightsCard(analytics, context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAbsenceCard(UserAbsenceInfo absenceInfo, BuildContext context) {
    return Card(
      elevation: 3,
      color: absenceInfo.cardColor ?? Colors.orange.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: absenceInfo.absentDays > 3 ? Colors.red.shade300 : Colors.orange.shade300,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  absenceInfo.absentDays > 3 ? Icons.warning_amber : Icons.info_outline,
                  color: absenceInfo.absentDays > 3 ? Colors.red : Colors.orange.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        absenceInfo.absentDays == 1 
                            ? 'Missed Yesterday'
                            : 'Absent for ${absenceInfo.absentDays} days',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: absenceInfo.absentDays > 3 ? Colors.red.shade800 : Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        absenceInfo.message,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (absenceInfo.suggestion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  '💡 ${absenceInfo.suggestion}',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (absenceInfo.absentDays >= 2)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealRecommendationPage(goal: widget.goal)
      ),
    );
  },
  icon: const Icon(Icons.fastfood, size: 18),
  label: const Text('Quick Recipes'),
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF1C4322),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
),


                  // OutlinedButton.icon(
                  //   onPressed: () => _handleAbsenceAction('Set daily reminder', context),
                  //   icon: const Icon(Icons.notifications, size: 18),
                  //   label: const Text('Set Reminder'),
                  //   style: OutlinedButton.styleFrom(
                  //     side: const BorderSide(color: Color(0xFF1C4322)),
                  //     foregroundColor: const Color(0xFF1C4322),
                  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  //   ),
                  // ),
                  if (absenceInfo.absentDays >= 3)
                   OutlinedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeeklyPlanPage(
          goal: widget.goal,
          dietType: widget.dietType,
          dislikes: widget.dislikes,
          userPreferences: widget.userPreferences,
        ),
      ),
    );
  },
  icon: const Icon(Icons.restaurant, size: 18),
  label: const Text('Cook Now'),
  style: OutlinedButton.styleFrom(
    side: BorderSide(color: Colors.red.shade700),
    foregroundColor: Colors.red.shade700,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodHeader(UserAnalytics analytics) {
    return Card(
      color:   const Color(0xFFF8F8F8)
,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analytics.analysisPeriod.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C4322),
                    ),
                  ),
                  Text(
                    analytics.analysisPeriod.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(
                'Day ${analytics.daysSinceStart + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: const Color(0xFF1C4322),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(UserAnalytics analytics) {
    return Card(
color:   const Color(0xFFF8F8F8)
,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Progress Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C4322),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOverviewStat(
                  'Days Tracked',
                  '${analytics.totals.daysTracked}',
                  Icons.check_circle,
                  analytics.totals.daysTracked > 0 ? Colors.green : Colors.grey,
                ),
                _buildOverviewStat(
                  'Total Meals',
                  '${analytics.totals.totalMeals}',
                  Icons.restaurant,
                  analytics.totals.totalMeals > 0 ? Colors.blue : Colors.grey,
                ),
                _buildOverviewStat(
                  'Avg Meals/Day',
                  analytics.averages.mealsPerDay.toStringAsFixed(1),
                  Icons.trending_up,
                  analytics.averages.mealsPerDay > 0 ? Colors.orange : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildNutritionAverages(UserAnalytics analytics) {
    return Card(
      color:   const Color(0xFFF8F8F8)
,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Averages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C4322),
              ),
            ),
            const SizedBox(height: 16),
            _buildNutritionRow('Calories', '${analytics.averages.calories}', Icons.local_fire_department),
            _buildNutritionRow('Protein', '${analytics.averages.protein}g', Icons.fitness_center),
            _buildNutritionRow('Carbs', '${analytics.averages.carbs}g', Icons.grain),
            _buildNutritionRow('Fats', '${analytics.averages.fats}g', Icons.water_drop),
            _buildNutritionRow('Fiber', '${analytics.averages.fiber}g', Icons.forest),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1C4322)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGoalProgress(UserAnalytics analytics) {
    final achievement = analytics.goalAchievement;
    
    return Card(
      color:   const Color(0xFFF8F8F8)
,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Goal Achievement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C4322),
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: achievement.overallAchievement,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(_getAchievementColor(achievement.overallAchievement)),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${(achievement.overallAchievement * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getAchievementColor(achievement.overallAchievement),
                      ),
                    ),
                    Text(
                      _getAchievementLabel(achievement.overallAchievement),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getAchievementColor(achievement.overallAchievement),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGoalProgressBar('Calories', achievement.calorieAchievement),
            _buildGoalProgressBar('Protein', achievement.proteinAchievement),
            _buildGoalProgressBar('Consistency', achievement.trackingConsistency),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgressBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text('${(value * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value,
    backgroundColor: Colors.grey.shade200,
    color: _getAchievementColor(value),
    minHeight: 6,
    borderRadius: BorderRadius.circular(3),
  ),
],
),
);
}

Widget _buildDailyChart(UserAnalytics analytics) {
final nonZeroDays = analytics.dailyData.where((day) => day.calories > 0).toList();
final maxCalories = nonZeroDays.isNotEmpty
? nonZeroDays.map((e) => e.calories).reduce((a, b) => a > b ? a : b)
: 2000;

return Card(
  color:   const Color(0xFFF8F8F8)
,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Daily Calorie Intake',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: Color(0xFF1C4322),
),
),
const SizedBox(height: 8),
Text(
analytics.analysisPeriod.name,
style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
),
const SizedBox(height: 16),
SizedBox(
height: 200,
child: nonZeroDays.isEmpty
? _buildNoDataChart()
: ListView.builder(
scrollDirection: Axis.horizontal,
itemCount: analytics.dailyData.length,
itemBuilder: (context, index) {
final day = analytics.dailyData[index];
final hasData = day.calories > 0;
return Container(
width: 50,
margin: const EdgeInsets.symmetric(horizontal: 6),
child: Column(
mainAxisAlignment: MainAxisAlignment.end,
children: [
if (hasData)
Text(
'${day.calories}',
style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
)
else
const Text(
'No data',
style: TextStyle(fontSize: 8, color: Colors.grey),
),
const SizedBox(height: 4),
Container(
height: hasData ? (day.calories / maxCalories) * 120 : 4,
width: 30,
decoration: BoxDecoration(
color: hasData
? _getBarColor(day.calories, analytics.userGoals.dailyCalories)
: Colors.grey.shade300,
borderRadius: BorderRadius.circular(6),
),
),
const SizedBox(height: 4),
Text(
DateFormat('MMM d').format(day.date),
style: TextStyle(
fontSize: 10,
color: hasData ? Colors.black87 : Colors.grey,
),
),
],
),
);
},
),
),
],
),
),
);
}

Widget _buildInsightsCard(UserAnalytics analytics, BuildContext context) {
return Card(
  color:   const Color(0xFFF8F8F8)
,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
const SizedBox(width: 8),
const Text(
'Personalized Insights',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: Color(0xFF1C4322),
),
),
],
),
const SizedBox(height: 12),
...analytics.insights.insights.map((insight) => Padding(
padding: const EdgeInsets.symmetric(vertical: 6),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
const SizedBox(width: 8),
Expanded(
child: Text(
insight,
style: const TextStyle(fontSize: 14, height: 1.4),
),
),
],
),
)).toList(),
if (analytics.insights.recommendations.isNotEmpty) ...[
const SizedBox(height: 16),
const Text(
'Recommendations:',
style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C4322)),
),
const SizedBox(height: 8),
...analytics.insights.recommendations.map((recommendation) => Padding(
padding: const EdgeInsets.symmetric(vertical: 4),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(Icons.chevron_right, size: 16, color: Colors.green.shade600),
const SizedBox(width: 8),
Expanded(
child: Text(
recommendation,
style: const TextStyle(fontSize: 14, height: 1.4),
),
),
],
),
)).toList(),
],
if (analytics.insights.actions.isNotEmpty) ...[
const SizedBox(height: 16),
const Text(
'Quick Actions:',
style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C4322)),
),
const SizedBox(height: 8),
Wrap(
spacing: 8,
runSpacing: 8,
children: analytics.insights.actions.map((action) {
if (action == 'View quick recipes') {
return ActionChip(
  avatar: const Icon(Icons.fastfood, size: 18),
  label: const Text('Quick Recipes'),
  backgroundColor: const Color(0xFF1C4322).withOpacity(0.1),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>MealRecommendationPage(goal: widget.goal)
      ),
    );
  },
);

// } else if (action == 'Set daily reminder') {
// return ActionChip(
// // avatar: const Icon(Icons.notifications, size: 18),
// // label: const Text('Set Reminder'),
// onPressed: () => _handleAbsenceAction(action, context),
// backgroundColor: Colors.orange.shade100,
// );
} else if (action == 'Cook Now') {
return ActionChip(
  avatar: const Icon(Icons.restaurant, size: 18),
  label: const Text('Cook Now'),
  backgroundColor: Colors.red.shade100,
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeeklyPlanPage(
          goal: widget.goal,
          dietType: widget.dietType,
          dislikes: widget.dislikes,
          userPreferences: widget.userPreferences,
        ),
      ),
    );
  },
);

}
return ActionChip(
label: Text(action),
onPressed: () {},
);
}).toList(),
),
],
],
),
),
);
}

Widget _buildNoDataChart() {
return Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade400),
const SizedBox(height: 8),
const Text(
'No meal data yet',
style: TextStyle(color: Colors.grey),
),
const SizedBox(height: 4),
const Text(
'Mark recipes as cooked to see your progress',
style: TextStyle(fontSize: 12, color: Colors.grey),
),
],
),
);
}

// Helper methods
Color _getAchievementColor(double rate) {
if (rate >= 0.8) return Colors.green;
if (rate >= 0.6) return Colors.blue;
if (rate >= 0.4) return Colors.orange;
return Colors.red;
}

String _getAchievementLabel(double rate) {
if (rate >= 0.8) return 'Excellent';
if (rate >= 0.6) return 'Good';
if (rate >= 0.4) return 'Fair';
return 'Needs Work';
}

Color _getBarColor(int calories, int goal) {
if (goal == 0) return Colors.blue;
final ratio = calories / goal;
if (ratio >= 0.9 && ratio <= 1.1) return Colors.green;
if (ratio < 0.7) return Colors.orange;
if (ratio > 1.3) return Colors.red;
return Colors.blue;
}

Widget _buildLoadingState() {
return const Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
CircularProgressIndicator(),
SizedBox(height: 16),
Text('Analyzing your nutrition data...'),
],
),
);
}

Widget _buildErrorState(String error) {
return Center(
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
const SizedBox(height: 16),
const Text(
'Unable to Load Analytics',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 8),
Text(
error,
textAlign: TextAlign.center,
style: const TextStyle(color: Colors.grey),
),
const SizedBox(height: 20),
ElevatedButton.icon(
onPressed: _refreshAnalytics,
icon: const Icon(Icons.refresh),
label: const Text('Try Again'),
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF1C4322),
foregroundColor: Colors.white,
),
),
],
),
),
);
}

Widget _buildEmptyState() {
return Center(
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.shade400),
const SizedBox(height: 16),
const Text(
'No Analytics Data Yet',
style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
),
const SizedBox(height: 12),
const Padding(
padding: EdgeInsets.symmetric(horizontal: 20),
child: Text(
'Mark recipes as cooked after preparing them to start building your nutrition analytics.',
textAlign: TextAlign.center,
style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
),
),
],
),
),
);
}
}

// Data Models
class UserAnalytics {
final AnalysisPeriod analysisPeriod;
final int daysSinceStart;
final List<DailyNutrition> dailyData;
final NutritionAverages averages;
final NutritionTotals totals;
final UserGoals userGoals;
final GoalAchievement goalAchievement;
final AnalyticsInsights insights;
final UserAbsenceInfo? absenceInfo;

UserAnalytics({
required this.analysisPeriod,
required this.daysSinceStart,
required this.dailyData,
required this.averages,
required this.totals,
required this.userGoals,
required this.goalAchievement,
required this.insights,
this.absenceInfo,
});
}

class UserAbsenceInfo {
final bool isAbsent;
final int absentDays;
final DateTime? lastActivityDate;
final String message;
final String suggestion;
final Color? cardColor;

UserAbsenceInfo({
required this.isAbsent,
required this.absentDays,
this.lastActivityDate,
required this.message,
required this.suggestion,
this.cardColor,
});
}

class AnalysisPeriod {
final String name;
final int days;
final String description;

AnalysisPeriod(this.name, this.days, this.description);
}

class DailyNutrition {
final DateTime date;
final int calories;
final int protein;
final int carbs;
final int fats;
final int fiber;
final int mealsCount;

DailyNutrition({
required this.date,
required this.calories,
required this.protein,
required this.carbs,
required this.fats,
required this.fiber,
required this.mealsCount,
});
}

class NutritionAverages {
final int calories;
final int protein;
final int carbs;
final int fats;
final int fiber;
final double mealsPerDay;

NutritionAverages({
required this.calories,
required this.protein,
required this.carbs,
required this.fats,
required this.fiber,
required this.mealsPerDay,
});
}

class NutritionTotals {
final int totalCalories;
final int totalProtein;
final int totalCarbs;
final int totalFats;
final int totalFiber;
final int totalMeals;
final int daysTracked;

NutritionTotals({
required this.totalCalories,
required this.totalProtein,
required this.totalCarbs,
required this.totalFats,
required this.totalFiber,
required this.totalMeals,
required this.daysTracked,
});
}

class UserGoals {
final int dailyCalories;
final int dailyProtein;
final int dailyCarbs;
final int dailyFats;
final int weeklyMeals;

UserGoals({
required this.dailyCalories,
required this.dailyProtein,
required this.dailyCarbs,
required this.dailyFats,
required this.weeklyMeals,
});

UserGoals copyWith({
int? dailyCalories,
int? dailyProtein,
int? dailyCarbs,
int? dailyFats,
int? weeklyMeals,
}) {
return UserGoals(
dailyCalories: dailyCalories ?? this.dailyCalories,
dailyProtein: dailyProtein ?? this.dailyProtein,
dailyCarbs: dailyCarbs ?? this.dailyCarbs,
dailyFats: dailyFats ?? this.dailyFats,
weeklyMeals: weeklyMeals ?? this.weeklyMeals,
);
}
}

class GoalAchievement {
final double calorieAchievement;
final double proteinAchievement;
final double trackingConsistency;
final double overallAchievement;

GoalAchievement({
required this.calorieAchievement,
required this.proteinAchievement,
required this.trackingConsistency,
required this.overallAchievement,
});
}

class AnalyticsInsights {
final List<String> insights;
final List<String> trends;
final List<String> recommendations;
final List<String> actions;

AnalyticsInsights({
required this.insights,
required this.trends,
required this.recommendations,
this.actions = const [],
});
}
