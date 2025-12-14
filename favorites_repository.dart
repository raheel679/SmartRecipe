
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  // Toggle favorite
  Future<void> toggleFavorite(Map<String, dynamic> recipe) async {
    if (user == null) return;

    final recipeId = recipe['id'] ?? '';
    if (recipeId.isEmpty) return;

    final favoritesRef = _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('favorites')
        .doc(recipeId);

    final doc = await favoritesRef.get();

    if (doc.exists) {
      await favoritesRef.delete();
    } else {
      await favoritesRef.set({
        'recipe': _normalizeRecipeData(recipe),
        'addedAt': Timestamp.now(),
        'recipeId': recipeId,
        'isAIRecipe': recipe['isAI'] ?? false,
        'name': recipe['name'] ?? recipe['title'] ?? 'Unknown Recipe',
        'imageUrl': recipe['imageUrl'] ?? '',
        'calories': recipe['calories'] ?? 0,
        'totalTime': recipe['totalTime'] ?? recipe['cookingTime'] ?? 0,
        'mealType': recipe['mealType'] ?? '',
        'protein': recipe['protein'] ?? 0,
        'carbs': recipe['carbs'] ?? 0,
        'fats': recipe['fats'] ?? 0,
        'description': recipe['description'] ?? '',
      });
    }
  }

  // Check if a recipe is favorite
  Future<bool> isFavorite(String recipeId) async {
    if (user == null || recipeId.isEmpty) return false;

    final doc = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('favorites')
        .doc(recipeId)
        .get();

    return doc.exists;
  }

  // Get all favorites - UPDATED for Settings Page
  Future<List<Map<String, dynamic>>> getFavorites() async {
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        
        // Use the stored recipe data or create from individual fields
        Map<String, dynamic> recipeData;
        if (data.containsKey('recipe') && data['recipe'] is Map) {
          recipeData = _normalizeRecipeData(Map<String, dynamic>.from(data['recipe']));
        } else {
          // Fallback to individual fields
          recipeData = {
            'id': data['recipeId'] ?? doc.id,
            'name': data['name'] ?? 'Unknown Recipe',
            'title': data['name'] ?? 'Unknown Recipe',
            'imageUrl': data['imageUrl'] ?? '',
            'calories': data['calories'] ?? 0,
            'totalTime': data['totalTime'] ?? 0,
            'cookingTime': data['totalTime'] ?? 0,
            'mealType': data['mealType'] ?? '',
            'protein': data['protein'] ?? 0,
            'carbs': data['carbs'] ?? 0,
            'fats': data['fats'] ?? 0,
            'description': data['description'] ?? '',
            'isAI': data['isAIRecipe'] ?? false,
          };
        }

        return {
          ...recipeData,
          'favoriteId': doc.id,
          'addedAt': (data['addedAt'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  // Remove from favorites
  Future<void> removeFromFavorite(String recipeId) async {
    if (user == null || recipeId.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('favorites')
        .doc(recipeId)
        .delete();
  }

  // CORRECTED: Add a recipe to history with proper parameter names
  Future<void> addToHistory(
    Map<String, dynamic> recipe, {
    int userRating = 0,
    String userComment = '',
  }) async {
    if (user == null) return;

    // Normalize recipe data
    final normalizedRecipe = _normalizeRecipeData(recipe);
   
    // Ensure we have a valid recipe ID
    final recipeId = normalizedRecipe['id'] ?? '';
    if (recipeId.isEmpty) {
      print('Error: Recipe ID is empty');
      return;
    }

    await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .add({
      'recipe': normalizedRecipe,
      'cookedAt': Timestamp.now(),
      'recipeId': recipeId,
      'rating': userRating,
      'comment': userComment,
      'recipeName': normalizedRecipe['name'] ?? normalizedRecipe['title'] ?? 'Recipe',
      'calories': normalizedRecipe['calories'] ?? 0,
      'totalTime': normalizedRecipe['totalTime'] ?? normalizedRecipe['cookingTime'] ?? 0,
      'imageUrl': normalizedRecipe['imageUrl'] ?? '',
      'mealType': normalizedRecipe['mealType'] ?? '',
      'protein': normalizedRecipe['protein'] ?? 0,
      'carbs': normalizedRecipe['carbs'] ?? 0,
      'fats': normalizedRecipe['fats'] ?? 0,
    });
  }

  // Get cooking history
  Future<List<Map<String, dynamic>>> getHistory() async {
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .orderBy('cookedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final recipeData = data['recipe'] as Map<String, dynamic>? ?? {};
     
      // Handle cookedAt timestamp conversion
      DateTime cookedAt;
      if (data['cookedAt'] is Timestamp) {
        cookedAt = (data['cookedAt'] as Timestamp).toDate();
      } else if (data['cookedAt'] is String) {
        cookedAt = DateTime.parse(data['cookedAt']);
      } else {
        cookedAt = DateTime.now();
      }

      return {
        ..._normalizeRecipeData(recipeData),
        'historyId': doc.id,
        'cookedAt': cookedAt,
        'userRating': data['rating'] ?? 0,
        'userComment': data['comment'] ?? '',
        'recipeId': data['recipeId'] ?? '',
      };
    }).toList();
  }

  // Update rating for a history item
  Future<void> updateHistoryRating(String historyId, int rating, String comment) async {
    if (user == null || historyId.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('history')
          .doc(historyId)
          .update({
        'rating': rating,
        'comment': comment,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating history rating: $e');
      throw Exception('Failed to update rating');
    }
  }

  // Get history by date range
  Future<List<Map<String, dynamic>>> getHistoryByDateRange(DateTime startDate, DateTime endDate) async {
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .where('cookedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('cookedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('cookedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final recipeData = data['recipe'] as Map<String, dynamic>? ?? {};
      final cookedAt = (data['cookedAt'] as Timestamp).toDate();

      return {
        ..._normalizeRecipeData(recipeData),
        'historyId': doc.id,
        'cookedAt': cookedAt,
        'userRating': data['rating'] ?? 0,
        'userComment': data['comment'] ?? '',
      };
    }).toList();
  }

  // Clear all history
  Future<void> clearHistory() async {
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Clear all favorites
  Future<void> clearFavorites() async {
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('favorites')
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Get favorite count
  Future<int> getFavoriteCount() async {
    if (user == null) return 0;

    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('favorites')
        .get();

    return snapshot.size;
  }

  // Get history count
  Future<int> getHistoryCount() async {
    if (user == null) return 0;

    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .get();

    return snapshot.size;
  }

  // Check if recipe is in history
  Future<bool> isInHistory(String recipeId) async {
    if (user == null || recipeId.isEmpty) return false;

    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .where('recipeId', isEqualTo: recipeId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // Get recent history (last 30 days)
  Future<List<Map<String, dynamic>>> getRecentHistory() async {
    if (user == null) return [];

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
   
    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .where('cookedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('cookedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final recipeData = data['recipe'] as Map<String, dynamic>? ?? {};
      final cookedAt = (data['cookedAt'] as Timestamp).toDate();

      return {
        ..._normalizeRecipeData(recipeData),
        'historyId': doc.id,
        'cookedAt': cookedAt,
        'userRating': data['rating'] ?? 0,
        'userComment': data['comment'] ?? '',
      };
    }).toList();
  }

  // Get most cooked recipes
  Future<List<Map<String, dynamic>>> getMostCookedRecipes({int limit = 10}) async {
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .get();

    // Count occurrences of each recipe
    final recipeCounts = <String, int>{};
    final recipeDataMap = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final recipeId = data['recipeId'] ?? '';
      final recipeData = data['recipe'] as Map<String, dynamic>? ?? {};

      if (recipeId.isNotEmpty) {
        recipeCounts[recipeId] = (recipeCounts[recipeId] ?? 0) + 1;
        if (!recipeDataMap.containsKey(recipeId)) {
          recipeDataMap[recipeId] = _normalizeRecipeData(recipeData);
        }
      }
    }

    // Sort by count and return top recipes
    final sortedRecipeIds = recipeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedRecipeIds.take(limit).map((entry) {
      final recipeId = entry.key;
      return {
        ...recipeDataMap[recipeId]!,
        'cookCount': entry.value,
      };
    }).toList();
  }

  // ADDED: Record week completion
  Future<void> recordWeekCompletion(int weekNumber, String goal, String goalQuestion) async {
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('week_completions')
          .add({
        'weekNumber': weekNumber,
        'goal': goal,
        'goalQuestion': goalQuestion,
        'completedAt': Timestamp.now(),
        'userId': user!.uid,
        'userEmail': user!.email,
        'totalFavorites': await getFavoriteCount(),
        'totalHistory': await getHistoryCount(),
      });

      // Update user's progress summary
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('progress_summary')
          .doc('weekly')
          .set({
        'lastCompletedWeek': weekNumber,
        'totalWeeksCompleted': FieldValue.increment(1),
        'lastGoal': goal,
        'lastGoalQuestion': goalQuestion,
        'updatedAt': Timestamp.now(),
        'totalFavorites': await getFavoriteCount(),
        'totalHistory': await getHistoryCount(),
      }, SetOptions(merge: true));

      print('✅ Week $weekNumber completion recorded successfully in FavoritesRepository');
    } catch (e) {
      print('❌ Error recording week completion in FavoritesRepository: $e');
      // Don't throw to avoid breaking user experience
    }
  }

  // ADDED: Record day completion
  Future<void> recordDayCompletion(String day, int weekNumber, String goal, double budgetUsed) async {
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('day_completions')
          .add({
        'day': day,
        'weekNumber': weekNumber,
        'goal': goal,
        'budgetUsed': budgetUsed,
        'completedAt': Timestamp.now(),
        'userId': user!.uid,
        'totalFavorites': await getFavoriteCount(),
      });

      print('✅ Day $day completion recorded for week $weekNumber');
    } catch (e) {
      print('❌ Error recording day completion: $e');
    }
  }

  // ADDED: Get user progress statistics
  Future<Map<String, dynamic>> getUserProgressStats() async {
    if (user == null) return {};

    try {
      final weekCompletions = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('week_completions')
          .get();

      final dayCompletions = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('day_completions')
          .get();

      final favoriteCount = await getFavoriteCount();
      final historyCount = await getHistoryCount();

      return {
        'totalWeeksCompleted': weekCompletions.size,
        'totalDaysCompleted': dayCompletions.size,
        'totalFavorites': favoriteCount,
        'totalHistoryItems': historyCount,
        'completionRate': weekCompletions.size > 0 ? (dayCompletions.size / (weekCompletions.size * 7) * 100).round() : 0,
        'averageFavoritesPerWeek': weekCompletions.size > 0 ? (favoriteCount / weekCompletions.size).round() : favoriteCount,
      };
    } catch (e) {
      print('❌ Error getting user progress stats: $e');
      return {};
    }
  }

  // ADDED: Get week completion history
  Future<List<Map<String, dynamic>>> getWeekCompletionHistory() async {
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('week_completions')
          .orderBy('completedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'completedAt': (data['completedAt'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting week completion history: $e');
      return [];
    }
  }

  // NEW: Get user's reviews for Settings Page
  Future<List<Map<String, dynamic>>> getUserReviews() async {
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'reviewId': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
          'updatedAt': data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting user reviews: $e');
      return [];
    }
  }

  // NEW: Update user review for Settings Page
  Future<void> updateUserReview(String reviewId, int rating, String review) async {
    if (user == null || reviewId.isEmpty) return;

    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'rating': rating,
        'review': review.isNotEmpty ? review : null,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('❌ Error updating review: $e');
      throw Exception('Failed to update review');
    }
  }

  // NEW: Delete user review for Settings Page
  Future<void> deleteUserReview(String reviewId) async {
    if (user == null || reviewId.isEmpty) return;

    try {
      await _firestore.collection('reviews').doc(reviewId).delete();
    } catch (e) {
      print('❌ Error deleting review: $e');
      throw Exception('Failed to delete review');
    }
  }

  // NEW: Get user's favorite recipes count by type
  Future<Map<String, int>> getFavoriteStats() async {
    if (user == null) return {};

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('favorites')
          .get();

      final stats = <String, int>{
        'total': snapshot.size,
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
        'snack': 0,
        'aiRecipes': 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final mealType = (data['mealType'] ?? '').toString().toLowerCase();
        
        if (mealType.contains('breakfast')) {
          stats['breakfast'] = stats['breakfast']! + 1;
        } else if (mealType.contains('lunch')) stats['lunch'] = stats['lunch']! + 1;
        else if (mealType.contains('dinner')) stats['dinner'] = stats['dinner']! + 1;
        else if (mealType.contains('snack')) stats['snack'] = stats['snack']! + 1;
        
        if (data['isAIRecipe'] == true) {
          stats['aiRecipes'] = stats['aiRecipes']! + 1;
        }
      }

      return stats;
    } catch (e) {
      print('❌ Error getting favorite stats: $e');
      return {'total': 0};
    }
  }

  // Normalize recipe data - improved version
  Map<String, dynamic> _normalizeRecipeData(Map<String, dynamic> recipe) {
    final normalized = Map<String, dynamic>.from(recipe);
   
    // Ensure consistent title/name
    if (normalized['title'] != null && normalized['name'] == null) {
      normalized['name'] = normalized['title'];
    } else if (normalized['name'] != null && normalized['title'] == null) {
      normalized['title'] = normalized['name'];
    }
   
    // Ensure consistent nutrition fields
    normalized['calories'] = _parseNumber(normalized['calories']) ?? 0;
    normalized['protein'] = _parseNumber(normalized['protein']) ?? 0;
    normalized['carbs'] = _parseNumber(normalized['carbs']) ?? 0;
    normalized['fats'] = _parseNumber(normalized['fats']) ?? 0;
   
    // Ensure consistent time fields
    normalized['totalTime'] = _parseNumber(normalized['totalTime']) ??
                             _parseNumber(normalized['cookingTime']) ?? 0;
    normalized['cookingTime'] = normalized['totalTime'];
   
    // Ensure ID field
    if (normalized['id'] == null) {
      // Generate a simple ID if none exists (for local recipes)
      normalized['id'] = 'local_${DateTime.now().millisecondsSinceEpoch}';
    }
   
    // Ensure basic structure for arrays
    if (normalized['ingredients'] == null || normalized['ingredients'] is! List) {
      normalized['ingredients'] = [];
    }
   
    if (normalized['instructions'] == null || normalized['instructions'] is! List) {
      normalized['instructions'] = [];
    }
   
    if (normalized['tags'] == null || normalized['tags'] is! List) {
      normalized['tags'] = [];
    }
   
    if (normalized['goalTags'] == null || normalized['goalTags'] is! List) {
      normalized['goalTags'] = [];
    }

    return normalized;
  }

  // Helper method to parse numbers from various types
  int? _parseNumber(dynamic value) {
    if (value == null) return null;
   
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      try {
        return int.tryParse(value) ?? double.tryParse(value)?.round();
      } catch (e) {
        return null;
      }
    }
   
    return null;
  }

  // Stream for real-time favorites updates
  Stream<List<Map<String, dynamic>>> get favoritesStream {
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('favorites')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          final recipeData = data['recipe'] as Map<String, dynamic>? ?? {};
          return {
            ..._normalizeRecipeData(recipeData),
            'favoriteId': doc.id,
            'addedAt': (data['addedAt'] as Timestamp).toDate(),
          };
        }).toList());
  }

  // Stream for real-time history updates
  Stream<List<Map<String, dynamic>>> get historyStream {
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .orderBy('cookedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          final recipeData = data['recipe'] as Map<String, dynamic>? ?? {};
          final cookedAt = (data['cookedAt'] as Timestamp).toDate();

          return {
            ..._normalizeRecipeData(recipeData),
            'historyId': doc.id,
            'cookedAt': cookedAt,
            'userRating': data['rating'] ?? 0,
            'userComment': data['comment'] ?? '',
          };
        }).toList());
  }

  // ADDED: Stream for week completions
  Stream<List<Map<String, dynamic>>> get weekCompletionsStream {
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('week_completions')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
            'completedAt': (data['completedAt'] as Timestamp).toDate(),
          };
        }).toList());
  }

  // NEW: Stream for user reviews (for Settings Page)
  Stream<List<Map<String, dynamic>>> get userReviewsStream {
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('reviews')
        .where('userId', isEqualTo: user!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'reviewId': doc.id,
            ...data,
            'createdAt': (data['createdAt'] as Timestamp).toDate(),
            'updatedAt': data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
          };
        }).toList());
  }
}
