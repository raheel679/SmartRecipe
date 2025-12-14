
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// Import local files
import 'analytics_dashboard.dart';
import 'analytics_repository.dart';
import 'favorites_repository.dart';
import 'reminder_scheduler.dart';
import 'feedback_analyzer.dart';
import 'favorites_page.dart';
import 'history_page.dart';
import 'daily_feedback.dart';
import 'NotificationService.dart';

class WeeklyPlanPage extends StatefulWidget {
  final String goal;
  final String dietType;
  final String dislikes;
  final Map<String, dynamic> userPreferences;

  const WeeklyPlanPage({
    super.key,
    required this.goal,
    required this.dietType,
    required this.dislikes,
    required this.userPreferences,
  });

  @override
  State<WeeklyPlanPage> createState() => _WeeklyPlanPageState();
}

class _WeeklyPlanPageState extends State<WeeklyPlanPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Future<Map<String, dynamic>> _weeklyPlanFuture;
  List<Map<String, dynamic>> _allRecipes = [];
 
  // Enhanced tracking properties
  int _currentWeekNumber = 1;
  int _currentDayNumber = 1;
  bool _weekCompleted = false;
  double _dailyBudget = 50.0;
  double _totalBudgetUsed = 0.0;
  List<String> _completedDays = [];
  DateTime _planStartDate = DateTime.now();
  
  // Track recipe usage to prevent repeats
  final Set<String> _usedRecipeIdsThisWeek = {};
  final Set<String> _allTimeUsedRecipeIds = {};

  // Track current week to detect week changes
  String? _lastGeneratedWeekKey;
 
  // Real-time preferences tracking
  StreamSubscription<DocumentSnapshot>? _preferencesSubscription;
  Map<String, dynamic> _currentUserPreferences = {};

  // New feature services
  final FavoritesRepository _favoritesRepository = FavoritesRepository();
  final ReminderScheduler _reminderScheduler = ReminderScheduler();
  final FeedbackAnalyzer _feedbackAnalyzer = FeedbackAnalyzer();
  final AnalyticsRepository _analyticsRepository = AnalyticsRepository();

  // Navigation state
  int _currentIndex = 0;

  // Ratings cache
  final _ratingsCache = <String, Map<String, dynamic>>{};

  // Track recently marked as cooked recipes to prevent duplicates
  final Set<String> _recentlyMarkedRecipes = {};

  @override
  void initState() {
    super.initState();
    _currentUserPreferences = widget.userPreferences;
    _loadUserProgress();
    _initializeWeekTracking();
    _weeklyPlanFuture = _generateWeeklyPlan();
    _startPreferencesListener();
    _initializeServices();
  }

  @override
  void dispose() {
    _preferencesSubscription?.cancel();
    super.dispose();
  }

  void _initializeServices() async {
    await NotificationService().initialize();
   
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleReminders();
    });

    _checkForDailyFeedback();
  }

  void _scheduleReminders() async {
    final planData = await _weeklyPlanFuture;
    if (planData['weeklyPlan'] != null) {
      await _reminderScheduler.scheduleWeeklyReminders(planData['weeklyPlan']);
    }
  }

  void _checkForDailyFeedback() {
    final now = DateTime.now();
    if (now.hour >= 18 && now.hour < 20) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDailyFeedback();
      });
    }
  }

  // Enhanced Week and Day Tracking Methods
  void _initializeWeekTracking() {
    final now = DateTime.now();
    _currentWeekNumber = _calculateWeekNumber(now);
    _currentDayNumber = _calculateCurrentDayNumber(now);
    _checkWeekCompletion();
    
    // Debug output to verify calculations
    print('=== DAY CALCULATION DEBUG ===');
    print('Plan Start Date: $_planStartDate');
    print('Current Date: $now');
    print('Days Difference: ${now.difference(_planStartDate).inDays}');
    print('Calculated Week: $_currentWeekNumber');
    print('Calculated Day: $_currentDayNumber');
    print('============================');
  }

  int _calculateWeekNumber(DateTime date) {
    final start = _planStartDate;
    final difference = date.difference(start).inDays;
    return (difference ~/ 7) + 1;
  }

  int _calculateCurrentDayNumber(DateTime date) {
    final start = _planStartDate;
    final difference = date.difference(start).inDays;
    // Ensure day number is between 1-7
    return (difference % 7) + 1;
  }

  void _checkWeekCompletion() {
    _weekCompleted = _completedDays.length >= 7;
    
    if (_weekCompleted) {
      _advanceToNextWeek();
    }
  }

  void _advanceToNextWeek() {
    setState(() {
      _currentWeekNumber++;
      _currentDayNumber = 1;
      _weekCompleted = false;
      _completedDays.clear();
      _usedRecipeIdsThisWeek.clear();
      _totalBudgetUsed = 0.0;
      
      _recordWeekCompletion();
      _showWeekCompletionMessage();
    });
    
    _rebuildPlan();
  }

  Future<void> _loadUserProgress() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final progressDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('progress')
          .doc('current_week')
          .get();

      if (progressDoc.exists) {
        final data = progressDoc.data()!;
        setState(() {
          _currentWeekNumber = data['weekNumber'] ?? 1;
          _currentDayNumber = data['dayNumber'] ?? 1;
          _completedDays = List<String>.from(data['completedDays'] ?? []);
          _totalBudgetUsed = (data['totalBudgetUsed'] ?? 0).toDouble();
          _planStartDate = (data['planStartDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          _weekCompleted = data['weekCompleted'] ?? false;
        });
      }
      
      final prefsDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('preferences')
          .doc('budget')
          .get();
          
      if (prefsDoc.exists) {
        setState(() {
          _dailyBudget = (prefsDoc.data()?['dailyBudget'] ?? 50.0).toDouble();
        });
      }
    } catch (e) {
      print('Error loading user progress: $e');
    }
  }

  Future<void> _saveUserProgress() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('progress')
          .doc('current_week')
          .set({
        'weekNumber': _currentWeekNumber,
        'dayNumber': _currentDayNumber,
        'completedDays': _completedDays,
        'totalBudgetUsed': _totalBudgetUsed,
        'planStartDate': Timestamp.fromDate(_planStartDate),
        'weekCompleted': _weekCompleted,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      print('Error saving user progress: $e');
    }
  }

  void _completeDay(String dayName) {
    if (!_completedDays.contains(dayName)) {
      setState(() {
        _completedDays.add(dayName);
        final todayBudgetUsed = _calculateTodaysBudget(dayName);
        _totalBudgetUsed += todayBudgetUsed;
      });
      
      _saveUserProgress();
      _checkWeekCompletion();
      _showDayCompletionMessage(dayName);
      _recordDayCompletion(dayName);
    }
  }

  double _calculateTodaysBudget(String dayName) {
    return _dailyBudget * 0.8;
  }

  void _showDayCompletionMessage(String dayName) {
    final tomorrowBudget = _getNextDayBudget();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✅ Day $_currentDayNumber ($dayName) completed!'),
            Text('💰 Budget for tomorrow: \$${tomorrowBudget.toStringAsFixed(2)}'),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View Progress',
          onPressed: () => _showProgressSummary(),
        ),
      ),
    );
  }

  void _showWeekCompletionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉 Week Completed!'),
            Text('Advancing to Week $_currentWeekNumber with new recipes'),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View New Plan',
          onPressed: () {},
        ),
      ),
    );
  }

  double _getNextDayBudget() {
    final daysCompleted = _completedDays.length;
    final totalBudget = _dailyBudget * 7;
    final remainingBudget = totalBudget - _totalBudgetUsed;
    final remainingDays = 7 - daysCompleted;
    
    return remainingDays > 0 ? remainingBudget / remainingDays : 0.0;
  }

  void _showProgressSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Progress'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 Week $_currentWeekNumber', 
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('📊 Day $_currentDayNumber of 7'),
            Text('✅ ${_completedDays.length} days completed'),
            const SizedBox(height: 8),
            Text('💰 Budget used: \$${_totalBudgetUsed.toStringAsFixed(2)}'),
            Text('💵 Remaining today: \$${(_dailyBudget - _calculateTodaysBudget(_getCurrentDayName())).toStringAsFixed(2)}'),
            Text('🎯 Next day budget: \$${_getNextDayBudget().toStringAsFixed(2)}'),
            if (_weekCompleted) ...[
              const SizedBox(height: 8),
              const Text('🎉 Week completed! New recipes coming up!',
                   style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getCurrentDayName() {
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return _currentDayNumber <= 7 ? days[_currentDayNumber - 1] : 'Unknown';
  }

  Future<void> _recordWeekCompletion() async {
    await _favoritesRepository.recordWeekCompletion(
      _currentWeekNumber,
      widget.goal,
      _currentUserPreferences['goalQuestion']?.toString() ?? '',
    );
  }

  Future<void> _recordDayCompletion(String dayName) async {
    final budgetUsed = _calculateTodaysBudget(dayName);
    await _favoritesRepository.recordDayCompletion(
      dayName,
      _currentWeekNumber,
      widget.goal,
      budgetUsed,
    );
  }

  // Listen for real-time preference updates
  void _startPreferencesListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _preferencesSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('questionnaires')
        .doc(widget.goal)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists && mounted) {
        final updatedPreferences = snapshot.data() as Map<String, dynamic>;
       
        if (_havePreferencesChanged(updatedPreferences)) {
          setState(() {
            _currentUserPreferences = updatedPreferences;
            _weeklyPlanFuture = _generateWeeklyPlan();
          });
         
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔄 Plan updated with new preferences!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }, onError: (error) {
      print('Error listening to preferences: $error');
    });
  }

  bool _havePreferencesChanged(Map<String, dynamic> newPreferences) {
    final criticalFields = ['goalQuestion', 'meals', 'prepTimePreference', 'cookingSkill'];
    for (final field in criticalFields) {
      if (_currentUserPreferences[field] != newPreferences[field]) {
        return true;
      }
    }
    return false;
  }

  bool _shouldRegeneratePlan() {
    final now = DateTime.now();
    final currentWeek = _calculateWeekNumber(now);
    return currentWeek != _currentWeekNumber;
  }

  // ==================== NEW: Mark as Cooked Functionality ====================
  void _markAsCooked(Map<String, dynamic> recipe) {
    // Check if recipe was recently marked to prevent duplicates
    final recipeId = recipe['id'] ?? '';
    if (_recentlyMarkedRecipes.contains(recipeId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe already marked as cooked recently'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Cooked'),
        content: const Text('Would you like to rate this recipe?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add to history without rating
              _addToHistoryWithConfirmation(recipe);
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showRatingDialog(recipe);
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _addToHistoryWithConfirmation(Map<String, dynamic> recipe) async {
    try {
      await _favoritesRepository.addToHistory(recipe);
      
      // Add to recently marked set to prevent duplicates
      final recipeId = recipe['id'] ?? '';
      _recentlyMarkedRecipes.add(recipeId);
      
      // Remove from recently marked after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        _recentlyMarkedRecipes.remove(recipeId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Recipe added to cooking history!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error adding to history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRatingDialog(Map<String, dynamic> recipe) {
    int rating = 0;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rate this Recipe'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How was your cooking experience?'),
                const SizedBox(height: 16),
                // Star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 30,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Comment field
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comments (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (rating > 0) {
                    try {
                      // Add to history with rating
                      await _favoritesRepository.addToHistory(
                        recipe,
                        userRating: rating,
                        userComment: commentController.text
                      );
                      
                      // Add to recently marked set
                      final recipeId = recipe['id'] ?? '';
                      _recentlyMarkedRecipes.add(recipeId);
                      Future.delayed(const Duration(seconds: 30), () {
                        _recentlyMarkedRecipes.remove(recipeId);
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Rated $rating stars and added to history!'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      print('Error rating recipe: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    // Add without rating if user doesn't rate
                    await _addToHistoryWithConfirmation(recipe);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
  // ==================== END: Mark as Cooked Functionality ====================

  // Enhanced meal item with ratings, favorites, and actions
  Widget _buildMealItemWithActions(String mealType, Map<String, dynamic> recipe) {
    return FutureBuilder<bool>(
      future: _favoritesRepository.isFavorite(recipe['id']),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;
       
        return Dismissible(
          key: Key('${recipe['id']}-$mealType'),
          background: Container(color: Colors.green),
          secondaryBackground: Container(color: Colors.red),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              _showSwapMealDialog(mealType, recipe);
              return false;
            } else {
              await _favoritesRepository.toggleFavorite(recipe);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isFavorite ? 'Removed from favorites' : 'Added to favorites!')),
              );
              return false;
            }
          },
          child: GestureDetector(
            onTap: () => _showMealDetails(recipe),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getMealTypeColor(mealType),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mealType,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    recipe['name'] ?? 'Recipe',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                // Cooked, Rating and Favorite buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // NEW: Cooked button
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_outline, size: 20),
                                      onPressed: () => _markAsCooked(recipe),
                                      tooltip: 'Mark as cooked',
                                      color: Colors.green,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.star_rate, size: 20),
                                      onPressed: () => _showRecipeRatingDialog(recipe),
                                      tooltip: 'Rate this recipe',
                                      color: Colors.amber.shade600,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isFavorite ? Icons.favorite : Icons.favorite_border,
                                        color: isFavorite ? Colors.red : Colors.grey,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        await _favoritesRepository.toggleFavorite(recipe);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (recipe['description'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                recipe['description']!,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Recipe ratings and reviews section
                  _buildRecipeRatingsAndReviews(recipe),
                  
                  // Nutrition and time info
                  Wrap(
                    spacing: 8,
                    children: [
                      if (recipe['totalTime'] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text(
                              '${recipe['totalTime']} min',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      if (recipe['calories'] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department, size: 12, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text(
                              '${recipe['calories']} cal',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      if (recipe['protein'] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fitness_center, size: 12, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text(
                              '${recipe['protein']}g protein',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Enhanced Reviews System with View Reviews Button
  Widget _buildRecipeRatingsAndReviews(Map<String, dynamic> recipe) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getRecipeRatings(recipe['id']),
      builder: (context, ratingsSnapshot) {
        if (ratingsSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 20,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (ratingsSnapshot.hasError) {
          print('Error loading ratings: ${ratingsSnapshot.error}');
          return const SizedBox();
        }

        final ratingsData = ratingsSnapshot.data ?? {};
        final averageRating = ratingsData['averageRating'] ?? 0.0;
        final totalRatings = ratingsData['totalRatings'] ?? 0;

        // If no ratings, show "Be the first to rate" button
        if (totalRatings == 0) {
          return Column(
            children: [
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.star_border, size: 16),
                label: const Text('Be the first to rate'),
                onPressed: () => _showRecipeRatingDialog(recipe),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating summary row with view reviews button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Star rating display
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        Icons.star,
                        size: 16,
                        color: index < averageRating.floor()
                            ? Colors.amber
                            : Colors.grey.shade300,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($totalRatings)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                
                // View Reviews Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.reviews, size: 14),
                  label: const Text('View Reviews'),
                  onPressed: () => _showAllReviews(recipe['id']),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Recent reviews preview
            _buildRecentReviewsPreview(recipe['id']),
          ],
        );
      },
    );
  }

  // Recent reviews preview (shows 2 most recent reviews)
  Widget _buildRecentReviewsPreview(String recipeId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('recipeId', isEqualTo: recipeId)
          .orderBy('createdAt', descending: true)
          .limit(2)
          .snapshots(),
      builder: (context, reviewSnapshot) {
        if (reviewSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 1.5),
          );
        }

        if (reviewSnapshot.hasError) {
          print('Error loading reviews: ${reviewSnapshot.error}');
          return const SizedBox();
        }

        if (!reviewSnapshot.hasData || reviewSnapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        final reviews = reviewSnapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Recent Reviews",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            ...reviews.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username + rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['userName'] ?? "User",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),

                        Row(
                          children: List.generate(5, (i) {
                            return Icon(
                              Icons.star,
                              size: 14,
                              color: i < (data['rating'] as int)
                                  ? Colors.amber
                                  : Colors.grey.shade300,
                            );
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Review text (optional)
                    if (data['review'] != null &&
                        data['review'].toString().isNotEmpty)
                      Text(
                        data['review'].toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),

            // Show "View all reviews" if there are more than 2
            if (reviews.length >= 2) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showAllReviews(recipeId),
                child: const Text(
                  'View all reviews →',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // Method to show all reviews in a dialog
  void _showAllReviews(String recipeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Reviews'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('recipeId', isEqualTo: recipeId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No reviews yet'));
              }

              final reviews = snapshot.data!.docs;

              return ListView.builder(
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  final data = reviews[index].data() as Map<String, dynamic>;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              data['userName'] ?? "User",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  Icons.star,
                                  size: 16,
                                  color: i < (data['rating'] as int)
                                      ? Colors.amber
                                      : Colors.grey.shade300,
                                );
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (data['review'] != null && data['review'].toString().isNotEmpty)
                          Text(data['review'].toString()),
                        const SizedBox(height: 6),
                        if (data['createdAt'] != null)
                          Text(
                            DateFormat('MMM d, yyyy').format(
                              (data['createdAt'] as Timestamp).toDate()
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Enhanced Recipe Rating System
  void _showRecipeRatingDialog(Map<String, dynamic> recipe) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecipeRatingDialog(
        recipe: recipe,
        onRatingSubmitted: (rating, review) {
          _submitRecipeRating(recipe, rating, review);
        },
      ),
    );
  }

  Future<void> _submitRecipeRating(Map<String, dynamic> recipe, int rating, String review) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to rate recipes')),
        );
        return;
      }

      final recipeId = recipe['id'] ?? '';
      if (recipeId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid recipe')),
        );
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(width: 12),
              Text('Submitting rating...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Get user name
      final userName = await _getUserName(user.uid);

      // Save rating to 'reviews' collection
      await _firestore
          .collection('reviews')
          .add({
        'recipeId': recipeId,
        'recipeName': recipe['name'] ?? 'Unknown Recipe',
        'userId': user.uid,
        'userEmail': user.email,
        'userName': userName,
        'rating': rating,
        'review': review.isNotEmpty ? review : null,
        'createdAt': Timestamp.now(),
        'goal': widget.goal,
        'dietType': widget.dietType,
      });

      // Save rating to user's history (this also adds to history)
      await _favoritesRepository.addToHistory(
        recipe,
        userRating: rating,
        userComment: review,
      );

      // Clear cache for this recipe
      _ratingsCache.remove(recipeId);

      // Refresh the UI to show updated ratings
      if (mounted) {
        setState(() {});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Thanks for your rating!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error submitting rating: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error submitting rating: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _getRecipeRatings(String recipeId) async {
    // Return cached data if available
    if (_ratingsCache.containsKey(recipeId)) {
      return _ratingsCache[recipeId]!;
    }

    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('recipeId', isEqualTo: recipeId)
          .get();

      if (snapshot.docs.isEmpty) {
        final result = {'averageRating': 0.0, 'totalRatings': 0};
        _ratingsCache[recipeId] = result;
        return result;
      }

      double totalRating = 0;
      for (final doc in snapshot.docs) {
        totalRating += (doc.data()['rating'] as int).toDouble();
      }

      final averageRating = totalRating / snapshot.docs.length;
      final result = {
        'averageRating': averageRating,
        'totalRatings': snapshot.docs.length,
      };
      
      // Cache the result
      _ratingsCache[recipeId] = result;
      
      return result;
    } catch (e) {
      print('Error fetching recipe ratings: $e');
      return {'averageRating': 0.0, 'totalRatings': 0};
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['name'] ?? 'Anonymous User';
    } catch (e) {
      return 'Anonymous User';
    }
  }

  void _showSwapMealDialog(String mealType, Map<String, dynamic> currentRecipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Swap $mealType'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getAlternativeRecipes(mealType, currentRecipe),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              final alternatives = snapshot.data ?? [];
              if (alternatives.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No alternative recipes found for this meal type.'),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: alternatives.length,
                itemBuilder: (context, index) {
                  final recipe = alternatives[index];
                  return ListTile(
                    leading: recipe['imageUrl'] != null
                      ? Image.network(recipe['imageUrl'], width: 40, height: 40, fit: BoxFit.cover)
                      : const Icon(Icons.fastfood),
                    title: Text(recipe['name'] ?? 'Recipe'),
                    subtitle: Text('${recipe['calories'] ?? 0} cal • ${recipe['totalTime'] ?? 0} min'),
                    onTap: () {
                      Navigator.pop(context);
                      _swapMealInPlan(mealType, recipe);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAlternativeRecipes(String mealType, Map<String, dynamic> currentRecipe) async {
    return _allRecipes.where((recipe) {
      return recipe['mealType']?.toString().toLowerCase().contains(mealType.toLowerCase()) ?? false &&
             _matchesUserPreferences(recipe) &&
             recipe['id'] != currentRecipe['id'] &&
             !_usedRecipeIdsThisWeek.contains(recipe['id']);
    }).toList();
  }

  void _swapMealInPlan(String mealType, Map<String, dynamic> newRecipe) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Swapped $mealType for ${newRecipe['name']}')),
    );
  }

  void _showDailyFeedback() {
    final now = DateTime.now();
    final today = DateFormat('EEEE').format(now);
   
    _weeklyPlanFuture.then((planData) {
      final weeklyPlan = planData['weeklyPlan'] as Map<String, dynamic>?;
      if (weeklyPlan != null && weeklyPlan.containsKey(today)) {
        final todayPlan = weeklyPlan[today];
        showDialog(
          context: context,
          builder: (context) => DailyFeedback(
            dailyMeals: todayPlan,
            onFeedbackSubmitted: (rating, comment, recipe) {
              _feedbackAnalyzer.recordMealRating(recipe, rating, comment);
              _addToMealHistory(recipe);
            },
          ),
        );
      }
    });
  }

  void _addToMealHistory(Map<String, dynamic> recipe) {
    _favoritesRepository.addToHistory(recipe);
  }

  // Recipe matching logic
  bool _matchesUserPreferences(Map<String, dynamic> recipe) {
    if (_containsDislikedIngredients(recipe)) return false;
    if (!_matchesUserGoal(recipe)) return false;
    if (!_matchesGoalQuestionCriteria(recipe)) return false;
    return true;
  }

  bool _containsDislikedIngredients(Map<String, dynamic> recipe) {
    final planIngredients = recipe['ingredients'] as List<dynamic>? ?? [];
    final expandedDislikes = _expandDislikes(_parseDislikes(widget.dislikes));
   
    for (var ingredient in planIngredients) {
      String ing = '';
      if (ingredient is Map) {
        ing = ingredient['name']?.toString().toLowerCase() ?? '';
      } else {
        ing = ingredient.toString().toLowerCase();
      }
     
      for (var dislike in expandedDislikes) {
        if (ing.contains(dislike.toLowerCase())) return true;
      }
    }
    return false;
  }

  bool _matchesUserGoal(Map<String, dynamic> recipe) {
    final planGoalTags = (recipe['goalTags'] as List<dynamic>? ?? [])
        .map((e) => e.toString().toLowerCase().trim())
        .toList();
    final userGoal = widget.goal.toLowerCase().trim();
    return planGoalTags.contains(userGoal);
  }

  bool _matchesGoalQuestionCriteria(Map<String, dynamic> recipe) {
    final userGoalQuestion = _currentUserPreferences['goalQuestion']?.toString() ?? '';
    final recipeTags = (recipe['tags'] as List<dynamic>? ?? [])
        .map((e) => e.toString().toLowerCase())
        .toList();
    final recipeDesc = recipe['description']?.toString().toLowerCase() ?? '';
    final recipeName = recipe['name']?.toString().toLowerCase() ?? '';
    final fullText = '$recipeName $recipeDesc ${recipeTags.join(' ')}';

    if (widget.goal == 'Weight Loss') {
      if (userGoalQuestion == 'Feeling full and satisfied') {
        return _matchesFullAndSatisfied(recipe, fullText, recipeTags);
      }
      if (userGoalQuestion == 'Quick and easy to make') {
        return _matchesQuickAndEasy(recipe, fullText, recipeTags);
      }
      if (userGoalQuestion == 'Low calorie density') {
        return _matchesLowCalorieDensity(recipe, fullText, recipeTags);
      }
    }

    if (widget.goal == 'Muscle Gain') {
      if (userGoalQuestion == 'Maximum protein intake') {
        return _matchesMaximumProtein(recipe, fullText, recipeTags);
      }
      if (userGoalQuestion == 'Post-workout recovery') {
        return _matchesPostWorkoutRecovery(recipe, fullText, recipeTags);
      }
      if (userGoalQuestion == 'Convenient eating') {
        return _matchesConvenientEating(recipe, fullText, recipeTags);
      }
    }

    if (widget.goal == 'Healthy Lifestyle') {
      if (userGoalQuestion == 'Nutritional balance') {
        return _matchesNutritionalBalance(recipe, fullText, recipeTags);
      }
      if (userGoalQuestion == 'Fresh ingredients') {
        return _matchesFreshIngredients(recipe, fullText, recipeTags);
      }
      if (userGoalQuestion == 'Easy preparation') {
        return _matchesEasyPreparation(recipe, fullText, recipeTags);
      }
    }

    return true;
  }

  // Matching helper methods
  bool _matchesFullAndSatisfied(Map<String, dynamic> recipe, String fullText, List<String> recipeTags) {
    return fullText.contains('filling') ||
           fullText.contains('satisfying') ||
           fullText.contains('keeps you full') ||
           recipeTags.any((tag) => tag.contains('high fiber') || tag.contains('fiber')) ||
           (recipe['fiber'] as int? ?? 0) > 8 ||
           (recipe['protein'] as int? ?? 0) > 20;
  }

  bool _matchesQuickAndEasy(Map<String, dynamic> recipe, String fullText, List<String> recipeTags) {
    return fullText.contains('quick') ||
           fullText.contains('easy') ||
           fullText.contains('simple') ||
           fullText.contains('fast') ||
           recipeTags.any((tag) => tag.contains('quick') || tag.contains('easy') || tag.contains('simple')) ||
           (recipe['totalTime'] as int? ?? 0) <= 25;
  }

  bool _matchesLowCalorieDensity(Map<String, dynamic> recipe, String fullText, List<String> recipeTags) {
    return fullText.contains('low calorie') ||
           fullText.contains('light') ||
           fullText.contains('low cal') ||
           recipeTags.any((tag) => tag.contains('low calorie') || tag.contains('light')) ||
           (recipe['calories'] as int? ?? 0) < 400;
  }

  bool _matchesMaximumProtein(Map<String, dynamic> recipe, String fullText, List<String> recipeTags) {
    return fullText.contains('high protein') ||
           fullText.contains('protein packed') ||
           fullText.contains('protein rich') ||
           recipeTags.any((tag) => tag.contains('high protein') || tag.contains('protein')) ||
           (recipe['protein'] as int? ?? 0) >= 30;
  }

  bool _matchesPostWorkoutRecovery(Map<String, dynamic> recipe, String fullText, List<String> recipeTags) {
    return fullText.contains('recovery') ||
           fullText.contains('post workout') ||
           fullText.contains('carbs') ||
           recipeTags.any((tag) => tag.contains('recovery') || tag.contains('carbs')) ||
           ((recipe['carbs'] as int? ?? 0) >= 40 && (recipe['protein'] as int? ?? 0) >= 20);
  }

  bool _matchesConvenientEating(Map<String, dynamic> recipe, String fullText, List<String> recipeTags) {
    return fullText.contains('convenient') ||
           fullText.contains('easy') ||
           fullText.contains('quick') ||
           recipeTags.any((tag) => tag.contains('convenient') || tag.contains('easy')) ||
           (recipe['totalTime'] as int? ?? 0) <= 30;
  }

  bool _matchesNutritionalBalance(Map<String, dynamic> recipe, String fullText, List<String> recipeTags) {
    return fullText.contains('balanced') ||
           fullText.contains('nutritious') ||
           fullText.contains('well rounded') ||
           recipeTags.any((tag) => tag.contains('balanced') || tag.contains('nutritious'));
  }

  bool _matchesFreshIngredients(Map<String, dynamic> recipe, String fullText, List<String> recipeTags) {
    return fullText.contains('fresh') ||
           fullText.contains('whole') ||
           fullText.contains('natural') ||
           recipeTags.any((tag) => tag.contains('fresh') || tag.contains('whole food'));
  }

  bool _matchesEasyPreparation(Map<String, dynamic> recipe, String fullText, List<String> recipeTags) {
    return fullText.contains('easy') ||
           fullText.contains('simple') ||
           fullText.contains('quick') ||
           recipeTags.any((tag) => tag.contains('easy') || tag.contains('simple')) ||
           (recipe['totalTime'] as int? ?? 0) <= 25;
  }

  double _calculateRecipeScore(Map<String, dynamic> recipe) {
    double score = 100.0;
    score += _calculateGoalQuestionScore(recipe);
   
    final userPrepTime = _currentUserPreferences['prepTimePreference']?.toString() ?? '15-30 mins';
    final recipeTotalTime = recipe['totalTime'] as int? ?? 0;
    if (_matchesPrepTime(recipeTotalTime, userPrepTime)) {
      score += 30;
    }

    final userCookingSkill = _currentUserPreferences['cookingSkill']?.toString() ?? 'Easy Recipes';
    final recipeComplexity = recipe['complexity']?.toString().toLowerCase() ?? 'easy';
   
    if (userCookingSkill == "Easy Recipes" && recipeComplexity == "easy") {
      score += 20;
    } else if (userCookingSkill == "Some Experience" && recipeComplexity == "medium") {
      score += 15;
    } else if (userCookingSkill == "Confident Cook" && recipeComplexity == "hard") {
      score += 10;
    }

    return score;
  }

  double _calculateGoalQuestionScore(Map<String, dynamic> recipe) {
    final userGoalQuestion = _currentUserPreferences['goalQuestion']?.toString() ?? '';
    final recipeTags = (recipe['tags'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase()).toList();
    final recipeDesc = recipe['description']?.toString().toLowerCase() ?? '';
    final recipeName = recipe['name']?.toString().toLowerCase() ?? '';
    final fullText = '$recipeName $recipeDesc ${recipeTags.join(' ')}';

    if (widget.goal == 'Weight Loss') {
      if (userGoalQuestion == 'Feeling full and satisfied') {
        if ((recipe['fiber'] as int? ?? 0) > 10) return 50;
        if ((recipe['protein'] as int? ?? 0) > 25) return 40;
        if (fullText.contains('filling') || fullText.contains('satisfying')) return 30;
      }
      if (userGoalQuestion == 'Quick and easy to make') {
        if ((recipe['totalTime'] as int? ?? 0) <= 15) return 50;
        if ((recipe['totalTime'] as int? ?? 0) <= 25) return 35;
        if (recipe['complexity'] == 'easy') return 25;
      }
      if (userGoalQuestion == 'Low calorie density') {
        if ((recipe['calories'] as int? ?? 0) < 350) return 50;
        if ((recipe['calories'] as int? ?? 0) < 450) return 35;
      }
    }

    if (widget.goal == 'Muscle Gain') {
      if (userGoalQuestion == 'Maximum protein intake') {
        if ((recipe['protein'] as int? ?? 0) >= 35) return 60;
        if ((recipe['protein'] as int? ?? 0) >= 25) return 45;
      }
      if (userGoalQuestion == 'Post-workout recovery') {
        if ((recipe['carbs'] as int? ?? 0) >= 50 && (recipe['protein'] as int? ?? 0) >= 25) return 55;
        if ((recipe['carbs'] as int? ?? 0) >= 40) return 35;
      }
      if (userGoalQuestion == 'Convenient eating') {
        if ((recipe['totalTime'] as int? ?? 0) <= 20) return 45;
        if (recipe['complexity'] == 'easy') return 30;
      }
    }

    if (widget.goal == 'Healthy Lifestyle') {
      if (userGoalQuestion == 'Nutritional balance') {
        final protein = recipe['protein'] as int? ?? 0;
        final carbs = recipe['carbs'] as int? ?? 0;
        final fats = recipe['fats'] as int? ?? 0;
        if (protein >= 15 && carbs >= 30 && fats >= 5) return 50;
      }
      if (userGoalQuestion == 'Fresh ingredients') {
        if (fullText.contains('fresh') || recipeTags.any((tag) => tag.contains('fresh'))) return 45;
        if (recipeTags.any((tag) => tag.contains('whole food'))) return 35;
      }
      if (userGoalQuestion == 'Easy preparation') {
        if ((recipe['totalTime'] as int? ?? 0) <= 15) return 45;
        if (recipe['complexity'] == 'easy') return 30;
      }
    }

    return 0;
  }

  bool _matchesPrepTime(int recipeTime, String userPreference) {
    switch (userPreference.toLowerCase()) {
      case 'under 15 mins': return recipeTime <= 20;
      case '15-30 mins': return recipeTime >= 10 && recipeTime <= 35;
      case 'over 30 mins': return recipeTime > 25;
      default: return true;
    }
  }

  // Enhanced Weekly Plan Generation with No Repeats
  Future<Map<String, dynamic>> _generateWeeklyPlan() async {
    try {
      if (_shouldRegeneratePlan()) {
        _initializeWeekTracking();
      }

      final snapshot = await _firestore.collection('recipes').get();
      _allRecipes = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      print('=== GENERATING WEEKLY PLAN ===');
      print('Week: $_currentWeekNumber, Day: $_currentDayNumber');
      print('User Goal: ${widget.goal}');
      print('User Goal Question: ${_currentUserPreferences['goalQuestion']}');
      print('Total recipes available: ${_allRecipes.length}');

      final matchingRecipes = _allRecipes.where((recipe) {
        return _matchesUserPreferences(recipe);
      }).toList();

      print('Essential matching recipes found: ${matchingRecipes.length}');

      if (matchingRecipes.isNotEmpty) {
        final scoredRecipes = matchingRecipes.map((recipe) {
          return {
            'recipe': recipe,
            'score': _calculateRecipeScore(recipe),
          };
        }).toList();

        scoredRecipes.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

        final prioritizedRecipes = scoredRecipes
            .map((item) => item['recipe'] as Map<String, dynamic>)
            .toList();

        return _generateCompleteWeeklyPlan(prioritizedRecipes);
      }

      return _generatePlanWithFlexibleMatching();
    } catch (e) {
      print('Error generating weekly plan: $e');
      throw Exception('Failed to generate weekly plan: $e');
    }
  }

  Map<String, dynamic> _generateCompleteWeeklyPlan(List<Map<String, dynamic>> matchingRecipes) {
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final weeklyPlan = <String, dynamic>{};
    final usedRecipeIdsThisGeneration = <String>{};

    // Filter out recipes used in previous weeks
    final availableRecipes = matchingRecipes.where((recipe) {
      final recipeId = recipe['id']?.toString() ?? '';
      return !_allTimeUsedRecipeIds.contains(recipeId);
    }).toList();

    // If we don't have enough unique recipes, allow some repeats from older weeks
    final finalRecipePool = availableRecipes.length >= 21 
        ? availableRecipes 
        : matchingRecipes;

    final preferredMealTypes = _getUserMealTypes();
    final totalMealsNeeded = days.length * preferredMealTypes.length;

    for (final day in days) {
      final dailyMeals = <String, dynamic>{};
     
      for (final mealType in preferredMealTypes) {
        Map<String, dynamic>? selectedRecipe;
       
        // Find recipes that match meal type and haven't been used this week
        final candidateRecipes = finalRecipePool.where((recipe) {
          final recipeMealType = recipe['mealType']?.toString().toLowerCase() ?? '';
          final isMatchingMeal = recipeMealType.contains(mealType.toLowerCase()) ||
                                _matchesMealType(recipeMealType, mealType);
          final isUsedThisWeek = _usedRecipeIdsThisWeek.contains(recipe['id']);
          final isUsedThisGeneration = usedRecipeIdsThisGeneration.contains(recipe['id']);
          
          return isMatchingMeal && !isUsedThisWeek && !isUsedThisGeneration;
        }).toList();

        if (candidateRecipes.isNotEmpty) {
          // Sort by score and pick the best one
          candidateRecipes.sort((a, b) {
            final scoreA = _calculateRecipeScore(a);
            final scoreB = _calculateRecipeScore(b);
            return scoreB.compareTo(scoreA);
          });
          selectedRecipe = candidateRecipes.first;
        } else {
          // Fallback: use any available recipe that hasn't been used this week
          final fallbackRecipes = finalRecipePool.where((recipe) {
            return !_usedRecipeIdsThisWeek.contains(recipe['id']) && 
                   !usedRecipeIdsThisGeneration.contains(recipe['id']);
          }).toList();
          
          if (fallbackRecipes.isNotEmpty) {
            selectedRecipe = fallbackRecipes.first;
          } else {
            // Last resort: use any recipe
            selectedRecipe = finalRecipePool.isNotEmpty ? finalRecipePool.first : {};
          }
        }

        if (selectedRecipe['id'] != null) {
          dailyMeals[mealType] = selectedRecipe;
          usedRecipeIdsThisGeneration.add(selectedRecipe['id']);
          _usedRecipeIdsThisWeek.add(selectedRecipe['id']);
          _allTimeUsedRecipeIds.add(selectedRecipe['id']);
        }
      }

      weeklyPlan[day] = {
        'meals': dailyMeals,
        'totalCalories': _calculateDailyCalories(dailyMeals),
        'totalProtein': _calculateDailyProtein(dailyMeals),
        'dayCompleted': _completedDays.contains(day),
      };
    }

    // Update tracking
    _lastGeneratedWeekKey = '${widget.goal}_${_currentUserPreferences['goalQuestion']}_$_currentWeekNumber';

    final planQuality = _getPlanQuality(finalRecipePool.length, totalMealsNeeded);

    return {
      'weeklyPlan': weeklyPlan,
      'summary': {
        'totalRecipes': usedRecipeIdsThisGeneration.length,
        'uniqueRecipes': usedRecipeIdsThisGeneration.length,
        'averageDailyCalories': _calculateAverageCalories(weeklyPlan),
        'averageDailyProtein': _calculateAverageProtein(weeklyPlan),
        'goal': widget.goal,
        'goalQuestion': _currentUserPreferences['goalQuestion'],
        'weekNumber': _currentWeekNumber,
        'currentDay': _currentDayNumber,
        'weekCompleted': _weekCompleted,
        'daysCompleted': _completedDays.length,
        'generatedOn': DateTime.now().toIso8601String(),
        'planQuality': planQuality['text'],
        'planQualityLevel': planQuality['level'],
        'matchingRecipes': finalRecipePool.length,
        'mealsNeeded': totalMealsNeeded,
        'noRepeatRecipes': true,
        'autoUpdated': true,
      },
      'matchingRecipesCount': finalRecipePool.length,
    };
  }

  Map<String, dynamic> _getPlanQuality(int matchingCount, int mealsNeeded) {
    if (matchingCount >= mealsNeeded) {
      return {'text': 'Excellent - Perfect match with your preferences', 'level': 'excellent'};
    } else if (matchingCount >= mealsNeeded * 0.7) {
      return {'text': 'Very Good - Strong match with preferences', 'level': 'very-good'};
    } else if (matchingCount >= mealsNeeded * 0.5) {
      return {'text': 'Good - Good match with some flexibility', 'level': 'good'};
    } else {
      return {'text': 'Fair - Used available recipes that avoid disliked ingredients', 'level': 'fair'};
    }
  }

  Map<String, dynamic> _generatePlanWithFlexibleMatching() {
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final weeklyPlan = <String, dynamic>{};
    final usedRecipeIds = <String>{};
   
    var availableRecipes = _allRecipes.where((recipe) {
      return !_containsDislikedIngredients(recipe);
    }).toList();
   
    availableRecipes.sort((a, b) {
      final scoreA = _calculateRecipeScore(a);
      final scoreB = _calculateRecipeScore(b);
      return scoreB.compareTo(scoreA);
    });

    final preferredMealTypes = _getUserMealTypes();
    final totalMealsNeeded = days.length * preferredMealTypes.length;
    final allowReuse = availableRecipes.length < totalMealsNeeded;

    for (final day in days) {
      final dailyMeals = <String, dynamic>{};
     
      for (final mealType in preferredMealTypes) {
        Map<String, dynamic> recipe;
       
        try {
          final unusedRecipes = availableRecipes
              .where((recipe) => !usedRecipeIds.contains(recipe['id']))
              .toList();
             
          if (unusedRecipes.isNotEmpty) {
            recipe = unusedRecipes.first;
          } else if (allowReuse && availableRecipes.isNotEmpty) {
            recipe = availableRecipes.first;
          } else {
            recipe = _allRecipes.isNotEmpty ? _allRecipes.first : {};
          }
        } catch (e) {
          recipe = _allRecipes.isNotEmpty ? _allRecipes.first : {};
        }

        dailyMeals[mealType] = recipe;
        usedRecipeIds.add(recipe['id']);
        _usedRecipeIdsThisWeek.add(recipe['id']);
        _allTimeUsedRecipeIds.add(recipe['id']);
      }

      weeklyPlan[day] = {
        'meals': dailyMeals,
        'totalCalories': _calculateDailyCalories(dailyMeals),
        'totalProtein': _calculateDailyProtein(dailyMeals),
        'dayCompleted': _completedDays.contains(day),
      };
    }

    _lastGeneratedWeekKey = '${widget.goal}_${_currentUserPreferences['goalQuestion']}_$_currentWeekNumber';

    final planQuality = _getPlanQuality(availableRecipes.length, totalMealsNeeded);

    return {
      'weeklyPlan': weeklyPlan,
      'summary': {
        'totalRecipes': usedRecipeIds.length,
        'uniqueRecipes': usedRecipeIds.length,
        'averageDailyCalories': _calculateAverageCalories(weeklyPlan),
        'averageDailyProtein': _calculateAverageProtein(weeklyPlan),
        'goal': widget.goal,
        'goalQuestion': _currentUserPreferences['goalQuestion'],
        'weekNumber': _currentWeekNumber,
        'currentDay': _currentDayNumber,
        'weekCompleted': _weekCompleted,
        'daysCompleted': _completedDays.length,
        'generatedOn': DateTime.now().toIso8601String(),
        'planQuality': planQuality['text'],
        'planQualityLevel': planQuality['level'],
        'matchingRecipes': availableRecipes.length,
        'mealsNeeded': totalMealsNeeded,
        'note': 'Some recipes may not perfectly match all preferences',
        'autoUpdated': true,
      },
      'matchingRecipesCount': availableRecipes.length,
    };
  }

  void _rebuildPlan() {
    setState(() {
      _weeklyPlanFuture = _generateWeeklyPlan();
    });
   
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Generating new weekly plan...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Navigation between features
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(     
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentIndex == 0) _buildWeeklyPlanHeader(),
            Expanded(
              child: _buildCurrentTab(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromARGB(255, 248, 252, 249),
        selectedItemColor: const Color.fromARGB(255, 206, 145, 14),          
        unselectedItemColor: Colors.grey,            
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Weekly Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPlanHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Your Weekly Meal Plan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C4322),
              backgroundColor: Color(0xFFF8F8F8),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _rebuildPlan,
            tooltip: 'Generate new plan for this week',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildWeeklyPlanContent();
      case 1:
        return  AnalyticsPage(goal: widget.goal, dietType: widget.dietType, 
        dislikes: widget.dislikes, userPreferences: widget.userPreferences);
      case 2:
        return const FavoritesPage();
      case 3:
        return const HistoryPage();
      default:
        return _buildWeeklyPlanContent();
    }
  }

  Widget _buildWeeklyPlanContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _weeklyPlanFuture,
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

        final planData = snapshot.data!;
        final weeklyPlan = planData['weeklyPlan'] as Map<String, dynamic>;
        final summary = planData['summary'] as Map<String, dynamic>;

        return _buildWeeklyPlan(weeklyPlan, summary, planData);
      },
    );
  }

  Widget _buildWeeklyPlan(
    Map<String, dynamic> weeklyPlan,
    Map<String, dynamic> summary,
    Map<String, dynamic> planData
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlanSummary(summary, planData),
          const SizedBox(height: 24),
          ...weeklyPlan.entries.map((entry) {
            final day = entry.key;
            final dayData = entry.value as Map<String, dynamic>;
            return _buildDayPlan(day, dayData);
          }),
        ],
      ),
    );
  }

  Widget _buildDayPlan(String day, Map<String, dynamic> dayData) {
    final meals = dayData['meals'] as Map<String, dynamic>;
    final isCompleted = _completedDays.contains(day);
    final isCurrentDay = day == _getCurrentDayName();
    
    return Card(
      color: const Color(0xFFF8F8F8),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isCompleted)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    if (!isCompleted && isCurrentDay)
                      const Icon(Icons.today, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? Colors.green : const Color(0xFF1C4322),
                      ),
                    ),
                  ],
                ),
                if (!isCompleted && isCurrentDay)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.done, size: 16),
                    label: const Text('Complete Day'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C4322),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _completeDay(day),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...meals.entries.map((mealEntry) {
              final mealType = mealEntry.key;
              final recipe = mealEntry.value as Map<String, dynamic>;
              return _buildMealItemWithActions(mealType, recipe);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummary(Map<String, dynamic> summary, Map<String, dynamic> planData) {
    final weekNumber = summary['weekNumber'] ?? _currentWeekNumber;
    final currentDay = summary['currentDay'] ?? _currentDayNumber;
    final daysCompleted = summary['daysCompleted'] ?? _completedDays.length;
    final weekCompleted = summary['weekCompleted'] ?? _weekCompleted;
    final generatedOn = summary['generatedOn'] != null
        ? DateTime.parse(summary['generatedOn'])
        : DateTime.now();
    final planQuality = summary['planQuality'] ?? 'Good';
    final qualityColor = _getPlanQualityColor(summary['planQualityLevel'] ?? 'good');
    final goalQuestion = summary['goalQuestion'] ?? 'Not specified';

    return Card(
      color: const Color(0xFFF8F8F8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Quality
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: qualityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: qualityColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getPlanQualityIcon(summary['planQualityLevel'] ?? 'good'),
                    size: 16,
                    color: qualityColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    planQuality,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: qualityColor,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // No Repeat Guarantee
            if (summary['noRepeatRecipes'] == true) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.food_bank, size: 16, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No recipe repeats this week • ${summary['uniqueRecipes']} unique recipes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
           
            if (goalQuestion != 'Not specified') ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.psychology, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Priority: $goalQuestion',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
           
            Row(
              children: [
                _buildSummaryItem('Goal', summary['goal']?.toString() ?? ''),
                _buildSummaryItem('Priority', summary['goalQuestion']?.toString() ?? ''),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryItem('Avg. Calories', '${summary['averageDailyCalories']} cal'),
                _buildSummaryItem('Avg. Protein', '${summary['averageDailyProtein']}g'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryItem('Matching Recipes', '${summary['matchingRecipes']}'),
                _buildSummaryItem('Meals Needed', '${summary['mealsNeeded']}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Generated: ${DateFormat('MMM d, yyyy').format(generatedOn)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (summary['note'] != null) ...[
              const SizedBox(height: 8),
              Text(
                summary['note']!,
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int daysCompleted) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: CircularProgressIndicator(
                value: daysCompleted / 7,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  daysCompleted == 7 ? Colors.green : const Color(0xFF1C4322),
                ),
                strokeWidth: 4,
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  '$daysCompleted/7',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Days',
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            "Creating your personalized weekly plan...",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Error creating plan",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _weeklyPlanFuture = _generateWeeklyPlan();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C4322),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "No matching plans found",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "We couldn't find enough recipes that match your preferences.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C4322),
              ),
              child: const Text('Adjust Preferences'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPlanQualityColor(String qualityLevel) {
    switch (qualityLevel) {
      case 'excellent': return Colors.green;
      case 'very-good': return Colors.blue;
      case 'good': return Colors.blue.shade400;
      case 'fair': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getPlanQualityIcon(String qualityLevel) {
    switch (qualityLevel) {
      case 'excellent': return Icons.star;
      case 'very-good': return Icons.star_half;
      case 'good': return Icons.check_circle;
      case 'fair': return Icons.info;
      default: return Icons.help;
    }
  }

  List<String> _getUserMealTypes() {
    final mealsPreference = _currentUserPreferences['meals']?.toString() ?? '3 Meals';
    switch (mealsPreference) {
      case '2 Meals + Snacks': return ['Breakfast', 'Dinner', 'Snack'];
      case '3 Meals': return ['Breakfast', 'Lunch', 'Dinner'];
      case '3 Meals + Snacks': return ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
      default: return ['Breakfast', 'Lunch', 'Dinner'];
    }
  }

  bool _matchesMealType(String recipeMealType, String userMealType) {
    final mapping = {
      'breakfast': ['breakfast', 'morning'],
      'lunch': ['lunch', 'midday'],
      'dinner': ['dinner', 'evening', 'supper'],
      'snack': ['snack', 'bite'],
    };
    final userMealLower = userMealType.toLowerCase();
    final allowedTypes = mapping[userMealLower] ?? [userMealLower];
    return allowedTypes.any((type) => recipeMealType.contains(type));
  }

  List<String> _expandDislikes(List<String> dislikes) {
    List<String> expanded = [];
    for (String dislike in dislikes) {
      expanded.add(dislike);
      if (dislike.contains('sea food') || dislike.contains('seafood')) {
        expanded.addAll(['fish', 'shrimp', 'lobster', 'crab', 'salmon', 'tuna']);
      } else if (dislike.contains('nuts') || dislike.contains('nut')) {
        expanded.addAll(['peanuts', 'almonds', 'walnuts', 'cashews']);
      } else if (dislike.contains('dairy')) {
        expanded.addAll(['milk', 'cheese', 'yogurt', 'butter']);
      }
    }
    return expanded.toSet().toList();
  }

  List<String> _parseDislikes(String dislikes) {
    return dislikes.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
  }

  int _calculateDailyCalories(Map<String, dynamic> dailyMeals) {
    int total = 0;
    dailyMeals.forEach((mealType, recipe) {
      total += (recipe['calories'] as int? ?? 0);
    });
    return total;
  }

  int _calculateDailyProtein(Map<String, dynamic> dailyMeals) {
    int total = 0;
    dailyMeals.forEach((mealType, recipe) {
      total += (recipe['protein'] as int? ?? 0);
    });
    return total;
  }

  int _calculateAverageCalories(Map<String, dynamic> weeklyPlan) {
    int total = 0;
    int days = 0;
    weeklyPlan.forEach((day, dayData) {
      total += (dayData['totalCalories'] as int? ?? 0);
      days++;
    });
    return days > 0 ? total ~/ days : 0;
  }

  int _calculateAverageProtein(Map<String, dynamic> weeklyPlan) {
    int total = 0;
    int days = 0;
    weeklyPlan.forEach((day, dayData) {
      total += (dayData['totalProtein'] as int? ?? 0);
      days++;
    });
    return days > 0 ? total ~/ days : 0;
  }

  void _showMealDetails(Map<String, dynamic> recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MealDetailsBottomSheet(recipe: recipe),
    );
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return Colors.orange.shade600;
      case 'lunch': return Colors.blue.shade600;
      case 'dinner': return Colors.purple.shade600;
      case 'snack': return Colors.green.shade600;
      default: return Colors.grey.shade600;
    }
  }
}

// Recipe Rating Dialog
class RecipeRatingDialog extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final Function(int rating, String review) onRatingSubmitted;

  const RecipeRatingDialog({
    super.key,
    required this.recipe,
    required this.onRatingSubmitted,
  });

  @override
  State<RecipeRatingDialog> createState() => _RecipeRatingDialogState();
}

class _RecipeRatingDialogState extends State<RecipeRatingDialog> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate this Recipe'),
      content: _isSubmitting
          ? _buildLoadingContent()
          : _buildRatingContent(),
      actions: _isSubmitting
          ? []
          : _buildDialogActions(),
    );
  }

  Widget _buildLoadingContent() {
    return SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Submitting your rating...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ));
  }

  Widget _buildRatingContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.recipe['name'] ?? 'Recipe',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('How would you rate this recipe?'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _rating = index + 1;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reviewController,
            decoration: const InputDecoration(
              labelText: 'Your review (optional)',
              border: OutlineInputBorder(),
              hintText: 'Share your experience with this recipe...',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDialogActions() {
    return [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _rating > 0 && !_isSubmitting ? _submitRating : null,
        child: const Text('Submit Rating'),
      ),
    ];
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onRatingSubmitted(_rating, _reviewController.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }
}

// MealDetailsBottomSheet class
class MealDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const MealDetailsBottomSheet({super.key, required this.recipe});

  @override
  State<MealDetailsBottomSheet> createState() => _MealDetailsBottomSheetState();
}

class _MealDetailsBottomSheetState extends State<MealDetailsBottomSheet> {
  final FavoritesRepository _favoritesRepository = FavoritesRepository();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  void _checkIfFavorite() async {
    final isFav = await _favoritesRepository.isFavorite(widget.recipe['id']);
    setState(() {
      _isFavorite = isFav;
    });
  }

  void _toggleFavorite() async {
    await _favoritesRepository.toggleFavorite(widget.recipe);
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  void _markAsCooked() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Cooked'),
        content: const Text('Would you like to rate this recipe?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add to history without rating
              _favoritesRepository.addToHistory(widget.recipe);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Added to cooking history!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // You would need to implement rating dialog here
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header with image and basic info
          _buildRecipeHeader(recipe),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nutrition Information
                  _buildNutritionSection(recipe),
                  const SizedBox(height: 20),
                  
                  // Ingredients Section
                  _buildIngredientsSection(recipe),
                  const SizedBox(height: 20),
                  
                  // Instructions Section
                  _buildInstructionsSection(recipe),
                  const SizedBox(height: 20),
                  
                  // Tags and Additional Info
                  _buildTagsSection(recipe),
                  
                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeHeader(Map<String, dynamic> recipe) {
    return Stack(
      children: [
        // Recipe Image
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            image: recipe['imageUrl'] != null
                ? DecorationImage(
                    image: NetworkImage(recipe['imageUrl']!),
                    fit: BoxFit.cover,
                  )
                : const DecorationImage(
                    image: AssetImage('assets/recipes-placeholder.jpg'),
                    fit: BoxFit.cover,
                  ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),
        
        // Close Button and Favorite Button
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                  size: 28,
                ),
                onPressed: _toggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        
        // Recipe Title and Basic Info Overlay
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe['name'] ?? 'Recipe',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (recipe['totalTime'] != null)
                    _buildInfoChip(
                      Icons.schedule,
                      '${recipe['totalTime']} min',
                    ),
                  const SizedBox(width: 8),
                  if (recipe['complexity'] != null)
                    _buildInfoChip(
                      Icons.psychology,
                      '${recipe['complexity']}',
                    ),
                  const SizedBox(width: 8),
                  if (recipe['mealType'] != null)
                    _buildInfoChip(
                      Icons.restaurant,
                      '${recipe['mealType']}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSection(Map<String, dynamic> recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nutrition Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C4322),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _buildNutritionItem('Calories', '${recipe['calories'] ?? 0} cal', Icons.local_fire_department),
            _buildNutritionItem('Protein', '${recipe['protein'] ?? 0}g', Icons.fitness_center),
            _buildNutritionItem('Carbs', '${recipe['carbs'] ?? 0}g', Icons.grain),
            _buildNutritionItem('Fat', '${recipe['fats'] ?? 0}g', Icons.water_drop),
            if (recipe['fiber'] != null)
              _buildNutritionItem('Fiber', '${recipe['fiber']}g', Icons.forest),
            if (recipe['sugar'] != null)
              _buildNutritionItem('Sugar', '${recipe['sugar']}g', Icons.cake),
          ],
        ),
        if (recipe['description'] != null) ...[
          const SizedBox(height: 12),
          Text(
            recipe['description']!,
            style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _buildNutritionItem(String label, String value, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1C4322)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C4322),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(Map<String, dynamic> recipe) {
    final ingredients = recipe['ingredients'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredients',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C4322),
          ),
        ),
        const SizedBox(height: 12),
        if (ingredients.isEmpty)
          const Text(
            'No ingredients listed',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          )
        else
          ...ingredients.asMap().entries.map((entry) {
            final index = entry.key;
            final ingredient = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 12, top: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C4322),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatIngredient(ingredient),
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _formatIngredient(dynamic ingredient) {
    if (ingredient is Map) {
      final amount = ingredient['amount'];
      final unit = ingredient['unit'];
      final name = ingredient['name'];
      
      if (amount != null && unit != null && name != null) {
        return '$amount $unit $name';
      } else if (amount != null && name != null) {
        return '$amount $name';
      } else if (name != null) {
        return name.toString();
      }
    }
    return ingredient.toString();
  }

  Widget _buildInstructionsSection(Map<String, dynamic> recipe) {
    final instructions = recipe['instructions'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Instructions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C4322),
          ),
        ),
        const SizedBox(height: 12),
        if (instructions.isEmpty)
          const Text(
            'No instructions available',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          )
        else
          ...instructions.asMap().entries.map((entry) {
            final index = entry.key;
            final instruction = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 12, top: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C4322),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      instruction.toString(),
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTagsSection(Map<String, dynamic> recipe) {
    final tags = recipe['tags'] as List<dynamic>? ?? [];
    final goalTags = recipe['goalTags'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty) ...[
          const Text(
            'Tags',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C4322),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return Chip(
                label: Text(
                  tag.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.blue.shade50,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        
        if (goalTags.isNotEmpty) ...[
          const Text(
            'Goal Tags',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C4322),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: goalTags.map((tag) {
              return Chip(
                label: Text(
                  tag.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.green.shade50,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Mark as Cooked'),
              onPressed: _markAsCooked,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
              ),
              label: Text(_isFavorite ? 'Favorited' : 'Add to Favorites'),
              onPressed: _toggleFavorite,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFavorite ? Colors.red : Colors.grey.shade300,
                foregroundColor: _isFavorite ? Colors.white : Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
