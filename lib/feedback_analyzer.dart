import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackAnalyzer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Existing method for meal ratings (assuming this exists based on your code)
  Future<void> recordMealRating(Map<String, dynamic> recipe, int rating, String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('mealFeedback').add({
      'userId': user.uid,
      'recipeId': recipe['id'],
      'rating': rating,
      'comment': comment,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // New method for monthly feedback
  Future<void> recordMonthlyFeedback(Map<String, dynamic> feedbackData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Store in a global collection for analysis (e.g., aggregate ratings)
    await _firestore.collection('monthlyFeedbackAnalytics').add({
      'userId': user.uid,
      ...feedbackData,
      'analyzedAt': DateTime.now().toIso8601String(),
    });

    // Optional: Log or process for insights (e.g., average ratings)
    print('Monthly feedback recorded: $feedbackData');
    // You can add logic here to calculate averages, trends, etc., for analytics.
  }
}