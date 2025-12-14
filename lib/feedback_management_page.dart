
// feedback_management_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FeedbackManagementPage extends StatefulWidget {
  const FeedbackManagementPage({super.key});

  @override
  State<FeedbackManagementPage> createState() => _FeedbackManagementPageState();
}

class _FeedbackManagementPageState extends State<FeedbackManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _recipeReviews = [];
  List<Map<String, dynamic>> _monthlyFeedback = [];
  bool _isLoading = true;
  bool _loadingMonthlyFeedback = false;
  String _searchQuery = '';
  int _totalUsers = 0;
  int _currentUserIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAllFeedbackOptimized();
  }

  // OPTIMIZED: Load recipe reviews first, then monthly feedback in background
  Future<void> _loadAllFeedbackOptimized() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _loadingMonthlyFeedback = false;
          _currentUserIndex = 0;
        });
      }

      // Load recipe reviews (usually faster)
      await _loadRecipeReviews();
      
      // Start loading monthly feedback in background
      _loadMonthlyFeedbackOptimized();

    } catch (e) {
      print('❌ Error loading feedback: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMonthlyFeedback = false;
        });
      }
    }
  }

  Future<void> _loadRecipeReviews() async {
    try {
      // Limit to 100 reviews initially for faster loading
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      if (mounted) {
        setState(() {
          _recipeReviews = reviewsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'type': 'recipe_review',
              'id': doc.id,
              'userId': data['userId'] ?? 'unknown',
              'userName': data['userName'] ?? 'Anonymous',
              'userEmail': data['userEmail'] ?? 'No email',
              'recipeName': data['recipeName'] ?? 'Unknown Recipe',
              'recipeId': data['recipeId'] ?? 'unknown',
              'rating': (data['rating'] ?? 0).toInt(),
              'review': data['review']?.toString() ?? '',
              'goal': data['goal']?.toString() ?? 'N/A',
              'dietType': data['dietType']?.toString() ?? 'N/A',
              'createdAt': data['createdAt'],
            };
          }).toList();
          
          // Recipe reviews are loaded, show UI while monthly feedback loads in background
          _isLoading = false;
        });
      }
      
      print('✅ Loaded ${_recipeReviews.length} recipe reviews');
    } catch (e) {
      print('⚠️ Error loading recipe reviews: $e');
      if (mounted) {
        setState(() {
          _recipeReviews = [];
          _isLoading = false;
        });
      }
    }
  }

  // OPTIMIZED: Load monthly feedback more efficiently
  Future<void> _loadMonthlyFeedbackOptimized() async {
    try {
      if (mounted) {
        setState(() {
          _loadingMonthlyFeedback = true;
          _monthlyFeedback = [];
        });
      }

      // Get user IDs first (faster than getting all user data)
      final usersSnapshot = await _firestore.collection('users').get();
      _totalUsers = usersSnapshot.docs.length;
      
      if (_totalUsers == 0) {
        if (mounted) {
          setState(() {
            _loadingMonthlyFeedback = false;
          });
        }
        return;
      }

      List<Map<String, dynamic>> monthlyFeedback = [];
      final userDocs = usersSnapshot.docs;
      
      // Process in smaller batches with delays
      const batchSize = 3;
      
      for (int i = 0; i < userDocs.length; i += batchSize) {
        if (!mounted) break;
        
        final batchEnd = i + batchSize > userDocs.length ? userDocs.length : i + batchSize;
        
        // Process current batch in parallel
        final batchFutures = <Future<List<Map<String, dynamic>>>>[];
        
        for (int j = i; j < batchEnd; j++) {
          final userDoc = userDocs[j];
          batchFutures.add(_getUserMonthlyFeedback(userDoc));
        }
        
        final batchResults = await Future.wait(batchFutures);
        
        // Add all results from this batch
        for (final result in batchResults) {
          monthlyFeedback.addAll(result);
        }
        
        // Update progress
        if (mounted) {
          setState(() {
            _currentUserIndex = batchEnd;
            _monthlyFeedback = [...monthlyFeedback]; // Update UI with current results
          });
        }
        
        // Small delay between batches to avoid overwhelming Firestore
        if (batchEnd < userDocs.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      if (mounted) {
        setState(() {
          _monthlyFeedback = monthlyFeedback;
          _loadingMonthlyFeedback = false;
        });
      }
      
      print('✅ Loaded ${_monthlyFeedback.length} monthly feedback entries from $_totalUsers users');
    } catch (e) {
      print('⚠️ Error loading monthly feedback: $e');
      if (mounted) {
        setState(() {
          _loadingMonthlyFeedback = false;
        });
      }
    }
  }

  // Get monthly feedback for a single user
  Future<List<Map<String, dynamic>>> _getUserMonthlyFeedback(
    QueryDocumentSnapshot userDoc,
  ) async {
    try {
      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = _getUserName(userData);
      final userEmail = userData['email']?.toString() ?? 'No email';
      
      // Get monthly feedback for this user with limit
      final feedbackSnapshot = await _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('monthlyFeedback')
          .orderBy('submittedAt', descending: true)
          .limit(5) // Limit to last 5 months per user
          .get();

      return feedbackSnapshot.docs.map((feedbackDoc) {
        final feedbackData = feedbackDoc.data();
        final monthlyStats = feedbackData['monthlyStats'] as Map<String, dynamic>? ?? {};
        final mostCookedRecipe = monthlyStats['mostCookedRecipe'] as Map<String, dynamic>?;
        
        return {
          'type': 'monthly_feedback',
          'id': feedbackDoc.id,
          'userId': userDoc.id,
          'userName': userName,
          'userEmail': userEmail,
          'rating': (feedbackData['rating'] ?? 0).toInt(),
          'feedback': feedbackData['feedback']?.toString() ?? '',
          'month': feedbackData['month']?.toString() ?? 'Unknown Month',
          'submittedAt': feedbackData['submittedAt'],
          'monthlyStats': {
            'cookedMeals': monthlyStats['cookedMeals'] ?? 0,
            'averageRating': (monthlyStats['averageRating'] ?? 0.0).toDouble(),
            'favoriteRecipes': monthlyStats['favoriteRecipes'] ?? 0,
            'mostCookedRecipe': mostCookedRecipe,
          },
        };
      }).toList();
    } catch (e) {
      print('⚠️ Error loading monthly feedback for user ${userDoc.id}: $e');
      return [];
    }
  }

  String _getUserName(Map<String, dynamic> userData) {
    return userData['name']?.toString() ??
           userData['displayName']?.toString() ??
           userData['username']?.toString() ??
           userData['email']?.toString().split('@').first ??
           'Unknown User';
  }

  // DELETE RECIPE REVIEW FUNCTIONALITY
  Future<void> _deleteRecipeReview(String reviewId, String recipeName, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: Text('Are you sure you want to delete the review for "$recipeName" by "$userName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Deleting review...'),
              ],
            ),
          ),
        );

        await _firestore.collection('reviews').doc(reviewId).delete();

        if (mounted) {
          setState(() {
            _recipeReviews.removeWhere((review) => review['id'] == reviewId);
          });
        }

        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Review for "$recipeName" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting review: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // DELETE MONTHLY FEEDBACK FUNCTIONALITY
  Future<void> _deleteMonthlyFeedback(String feedbackId, String userId, String month, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Monthly Feedback'),
        content: Text('Are you sure you want to delete the monthly feedback for "$month" by "$userName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Deleting feedback...'),
              ],
            ),
          ),
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('monthlyFeedback')
            .doc(feedbackId)
            .delete();

        if (mounted) {
          setState(() {
            _monthlyFeedback.removeWhere((feedback) => feedback['id'] == feedbackId);
          });
        }

        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Monthly feedback for "$month" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting feedback: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRecipeReviews {
    if (_searchQuery.isEmpty) return _recipeReviews;
    
    final query = _searchQuery.toLowerCase();
    return _recipeReviews.where((review) {
      return review['userName'].toString().toLowerCase().contains(query) ||
             review['userEmail'].toString().toLowerCase().contains(query) ||
             review['review'].toString().toLowerCase().contains(query) ||
             review['recipeName'].toString().toLowerCase().contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredMonthlyFeedback {
    if (_searchQuery.isEmpty) return _monthlyFeedback;
    
    final query = _searchQuery.toLowerCase();
    return _monthlyFeedback.where((feedback) {
      return feedback['userName'].toString().toLowerCase().contains(query) ||
             feedback['userEmail'].toString().toLowerCase().contains(query) ||
             feedback['feedback'].toString().toLowerCase().contains(query) ||
             feedback['month'].toString().toLowerCase().contains(query);
    }).toList();
  }

  void _showRecipeReviewDetails(Map<String, dynamic> review) {
    final createdAt = review['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null 
        ? DateFormat('MMM d, yyyy - HH:mm').format(createdAt.toDate())
        : 'Not available';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recipe Review Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('User Name', review['userName'].toString()),
              _buildDetailItem('User Email', review['userEmail'].toString()),
              _buildDetailItem('Recipe', review['recipeName'].toString()),
              _buildDetailItem('Rating', '${review['rating']}/5'),
              
              const SizedBox(height: 8),
              const Text('Review:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(review['review'].toString().isEmpty ? 'No review provided' : review['review'].toString()),
              
              const SizedBox(height: 8),
              _buildDetailItem('Goal', review['goal'].toString()),
              _buildDetailItem('Diet Type', review['dietType'].toString()),
              
              const SizedBox(height: 8),
              _buildDetailItem('Submitted', formattedDate),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRecipeReview(
                review['id'].toString(),
                review['recipeName'].toString(),
                review['userName'].toString(),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMonthlyFeedbackDetails(Map<String, dynamic> feedback) {
    final submittedAt = feedback['submittedAt'] as Timestamp?;
    final formattedDate = submittedAt != null 
        ? DateFormat('MMM d, yyyy - HH:mm').format(submittedAt.toDate())
        : 'Not available';
    
    final monthlyStats = feedback['monthlyStats'] as Map<String, dynamic>;
    final mostCookedRecipe = monthlyStats['mostCookedRecipe'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly Feedback Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('User Name', feedback['userName'].toString()),
              _buildDetailItem('User Email', feedback['userEmail'].toString()),
              _buildDetailItem('Month', feedback['month'].toString()),
              _buildDetailItem('Rating', '${feedback['rating']}/5'),
              
              const SizedBox(height: 8),
              const Text('Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(feedback['feedback'].toString().isEmpty ? 'No feedback provided' : feedback['feedback'].toString()),
              
              const SizedBox(height: 16),
              const Text('Monthly Stats:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailItem('Meals Cooked', '${monthlyStats['cookedMeals']}'),
              _buildDetailItem('Average Rating', '${(monthlyStats['averageRating'] as double).toStringAsFixed(1)}/5'),
              _buildDetailItem('Favorite Recipes', '${monthlyStats['favoriteRecipes']}'),
              
              if (mostCookedRecipe != null)
                _buildDetailItem(
                  'Most Cooked Recipe',
                  '${mostCookedRecipe['name']} (${mostCookedRecipe['count']} times)'
                ),
              
              const SizedBox(height: 8),
              _buildDetailItem('Submitted', formattedDate),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMonthlyFeedback(
                feedback['id'].toString(),
                feedback['userId'].toString(),
                feedback['month'].toString(),
                feedback['userName'].toString(),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          Icons.star,
          size: 16,
          color: index < rating ? Colors.amber : Colors.grey.shade300,
        );
      }),
    );
  }

  void _showRecipeReviewActions(BuildContext context, Map<String, dynamic> review) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('View Details'),
            onTap: () {
              Navigator.pop(context);
              _showRecipeReviewDetails(review);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Review', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteRecipeReview(
                review['id'].toString(),
                review['recipeName'].toString(),
                review['userName'].toString(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showMonthlyFeedbackActions(BuildContext context, Map<String, dynamic> feedback) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('View Details'),
            onTap: () {
              Navigator.pop(context);
              _showMonthlyFeedbackDetails(feedback);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Feedback', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteMonthlyFeedback(
                feedback['id'].toString(),
                feedback['userId'].toString(),
                feedback['month'].toString(),
                feedback['userName'].toString(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeReviewItem(Map<String, dynamic> review) {
    final createdAt = review['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null 
        ? DateFormat('MMM d, yyyy').format(createdAt.toDate())
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            _getAvatarText(review['userName'].toString()),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          review['recipeName'].toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('By: ${review['userName']}'),
            const SizedBox(height: 4),
            _buildRatingStars(review['rating'] as int),
            const SizedBox(height: 4),
            Text(
              review['review'].toString().isEmpty ? 'No review provided' : review['review'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: review['review'].toString().isEmpty ? Colors.grey : null,
                fontStyle: review['review'].toString().isEmpty ? FontStyle.italic : null,
              ),
            ),
            if (formattedDate.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showRecipeReviewActions(context, review),
          tooltip: 'Review Actions',
        ),
        onTap: () => _showRecipeReviewDetails(review),
      ),
    );
  }

  Widget _buildMonthlyFeedbackItem(Map<String, dynamic> feedback) {
    final monthlyStats = feedback['monthlyStats'] as Map<String, dynamic>;
    final averageRating = monthlyStats['averageRating'] as double;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Text(
            _getAvatarText(feedback['userName'].toString()),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          feedback['userName'].toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(feedback['month'].toString()),
            const SizedBox(height: 4),
            _buildRatingStars(feedback['rating'] as int),
            const SizedBox(height: 4),
            Text(
              feedback['feedback'].toString().isEmpty ? 'No additional feedback' : feedback['feedback'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: feedback['feedback'].toString().isEmpty ? Colors.grey : null,
                fontStyle: feedback['feedback'].toString().isEmpty ? FontStyle.italic : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Meals: ${monthlyStats['cookedMeals']} | '
              'Avg: ${averageRating.toStringAsFixed(1)}/5',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showMonthlyFeedbackActions(context, feedback),
          tooltip: 'Feedback Actions',
        ),
        onTap: () => _showMonthlyFeedbackDetails(feedback),
      ),
    );
  }

  String _getAvatarText(String name) {
    if (name.isEmpty || name == 'Unknown User') {
      return '?';
    }
    
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) return '?';
    
    return cleanedName.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feedback Management'),
       foregroundColor: Colors.black,
backgroundColor: const Color(0xFFF8F8F8), 
          automaticallyImplyLeading: false, 
          bottom: const TabBar(

            tabs: [
              
              Tab(
                icon: Icon(Icons.restaurant),
                text: 'Recipe Reviews',
                
              ),
              Tab(
                icon: Icon(Icons.calendar_today),
                text: 'Monthly Feedback',
              ),
            ],
          ),
          actions: [
            if (_loadingMonthlyFeedback)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading || _loadingMonthlyFeedback ? null : _loadAllFeedbackOptimized,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Search feedback...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
           
            // Results Count and Progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Showing ${_filteredRecipeReviews.length} recipe reviews and ${_filteredMonthlyFeedback.length} monthly feedback entries',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (_loadingMonthlyFeedback && _totalUsers > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Loading monthly feedback: $_currentUserIndex/$_totalUsers users',
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
           
            const SizedBox(height: 8),
           
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading recipe reviews...'),
                        ],
                      ),
                    )
                  : TabBarView(
                      children: [
                        // Recipe Reviews Tab
                        _filteredRecipeReviews.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.reviews, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No Recipe Reviews Found',
                                      style: TextStyle(fontSize: 18, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredRecipeReviews.length,
                                itemBuilder: (context, index) {
                                  return _buildRecipeReviewItem(_filteredRecipeReviews[index]);
                                },
                              ),
                       
                        // Monthly Feedback Tab
                        _loadingMonthlyFeedback && _monthlyFeedback.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Loading monthly feedback...',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_totalUsers > 0)
                                      Text(
                                        'Processed $_currentUserIndex/$_totalUsers users',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              )
                            : _filteredMonthlyFeedback.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.feedback, size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text(
                                          'No Monthly Feedback Found',
                                          style: TextStyle(fontSize: 18, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _filteredMonthlyFeedback.length,
                                    itemBuilder: (context, index) {
                                      return _buildMonthlyFeedbackItem(_filteredMonthlyFeedback[index]);
                                    },
                                  ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
