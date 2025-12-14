import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MonthlyFeedbackPage extends StatefulWidget {
  const MonthlyFeedbackPage({super.key});

  @override
  State<MonthlyFeedbackPage> createState() => _MonthlyFeedbackPageState();
}

class _MonthlyFeedbackPageState extends State<MonthlyFeedbackPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late Future<Map<String, dynamic>> _monthlyDataFuture;
  int _selectedRating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _monthlyDataFuture = _loadMonthlyData();
    _checkIfFeedbackAlreadySubmitted();
  }

  Future<Map<String, dynamic>> _loadMonthlyData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    
    // Convert to Timestamps for Firestore query
    final firstDayTimestamp = Timestamp.fromDate(firstDayOfMonth);
    final lastDayTimestamp = Timestamp.fromDate(lastDayOfMonth);

    try {
      // 1. Get reviews for this month (this collection EXISTS)
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: firstDayTimestamp)
          .where('createdAt', isLessThanOrEqualTo: lastDayTimestamp)
          .get();

      // 2. Try to get favorites (check if collection exists)
      int favoriteCount = 0;
      try {
        final favoritesQuery = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .get();
        favoriteCount = favoritesQuery.docs.length;
      } catch (e) {
        print('Favorites collection might not exist yet: $e');
      }

      // 3. Calculate stats from reviews
      final reviewedRecipes = reviewsSnapshot.docs.length;
      final averageRating = _calculateAverageRating(reviewsSnapshot.docs);
      final mostReviewedRecipe = _findMostReviewedRecipe(reviewsSnapshot.docs);

      return {
        'reviewedRecipes': reviewedRecipes,
        'averageRating': averageRating,
        'favoriteRecipes': favoriteCount,
        'mostReviewedRecipe': mostReviewedRecipe,
        'month': DateFormat('MMMM yyyy').format(now),
      };
    } catch (e) {
      print('Error loading monthly data: $e');
      // Return default values
      return {
        'reviewedRecipes': 0,
        'averageRating': 0.0,
        'favoriteRecipes': 0,
        'mostReviewedRecipe': null,
        'month': DateFormat('MMMM yyyy').format(now),
      };
    }
  }

  double _calculateAverageRating(List<QueryDocumentSnapshot> reviews) {
    if (reviews.isEmpty) return 0.0;
    
    double totalRating = 0;
    
    for (final review in reviews) {
      final rating = review['rating'] as int? ?? 0;
      if (rating > 0) {
        totalRating += rating.toDouble();
      }
    }
    
    return totalRating / reviews.length;
  }

  Map<String, dynamic>? _findMostReviewedRecipe(List<QueryDocumentSnapshot> reviews) {
    if (reviews.isEmpty) return null;
    
    final recipeCount = <String, int>{};
    
    for (final review in reviews) {
      final recipeId = review['recipeId'] as String?;
      final recipeName = review['recipeName'] as String?;
      
      if (recipeId != null && recipeId.isNotEmpty) {
        recipeCount[recipeId] = (recipeCount[recipeId] ?? 0) + 1;
      }
    }
    
    if (recipeCount.isEmpty) return null;
    
    // Find recipe with most reviews
    final mostReviewedId = recipeCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    // Try to get the recipe name from any review with this ID
    String recipeName = 'Unknown Recipe';
    for (final review in reviews) {
      final recipeId = review['recipeId'] as String?;
      if (recipeId == mostReviewedId) {
        recipeName = review['recipeName'] as String? ?? 'Unknown Recipe';
        break;
      }
    }
    
    return {
      'name': recipeName,
      'count': recipeCount[mostReviewedId],
    };
  }

  Future<void> _checkIfFeedbackAlreadySubmitted() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(now);

    try {
      final feedbackDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('monthlyFeedback')
          .doc(monthKey)
          .get();

      if (feedbackDoc.exists && mounted) {
        final data = feedbackDoc.data()!;
        setState(() {
          _selectedRating = data['rating'] ?? 0;
          _feedbackController.text = data['feedback'] ?? '';
        });
      }
    } catch (e) {
      print('Error checking existing feedback: $e');
      // It's okay if the collection doesn't exist yet
    }
  }

  Future<void> _submitFeedback() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final now = DateTime.now();
      final monthKey = DateFormat('yyyy-MM').format(now);

      final monthlyData = await _monthlyDataFuture;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('monthlyFeedback')
          .doc(monthKey)
          .set({
        'rating': _selectedRating,
        'feedback': _feedbackController.text.trim(),
        'submittedAt': Timestamp.now(),
        'monthlyStats': monthlyData,
        'month': monthlyData['month'],
        'userId': user.uid,
        'userEmail': user.email,
      }, SetOptions(merge: true)); // Use merge to update if exists

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        
        // Optional: Add a delay before navigating back
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error submitting feedback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildRatingStars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'How was your cooking month?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRating = index + 1;
                });
              },
              child: Icon(
                index < _selectedRating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 40,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          _getRatingText(_selectedRating),
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1: return 'Could be better';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent!';
      default: return 'Tap stars to rate';
    }
  }

  Widget _buildMonthlyStats(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: Color(0xFF1C4322)),
                const SizedBox(width: 8),
                Text(
                  'Your ${data['month']} Summary',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C4322),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatItem('Recipes Reviewed', '${data['reviewedRecipes']}'),
            _buildStatItem('Average Rating', '${data['averageRating'].toStringAsFixed(1)}/5'),
            _buildStatItem('Favorite Recipes', '${data['favoriteRecipes']}'),
            if (data['mostReviewedRecipe'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Most Reviewed: ${data['mostReviewedRecipe']['name']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '(${data['mostReviewedRecipe']['count']}x)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C4322),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C4322),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Feedback'),
        backgroundColor: const Color(0xFF1C4322),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _monthlyDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1C4322)),
                  SizedBox(height: 16),
                  Text('Loading your monthly stats...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _monthlyDataFuture = _loadMonthlyData();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C4322),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final monthlyData = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Monthly Stats
                _buildMonthlyStats(monthlyData),
                
                const SizedBox(height: 32),
                
                // Rating Section
                _buildRatingStars(),
                
                const SizedBox(height: 32),
                
                // Feedback Section
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share Your Thoughts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C4322),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'What worked well? What could be improved? Any recipe suggestions?',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _feedbackController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Type your feedback here...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C4322),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Submit Feedback',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF1C4322)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your feedback helps us improve the app and suggest better recipes for you!',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}
