
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'monthly_feedback_page.dart';
import 'NotificationService.dart';
import 'favorites_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Settings
  bool _notifications = true;
  bool _darkMode = false;
  String _measurementUnit = 'metric';
  bool _vegetarian = false;
  bool _showNutrition = true;

  // User data
  final FavoritesRepository _favoritesRepository = FavoritesRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
 
  // Loading states
  bool _loadingReviews = false;
  bool _loadingFavorites = false;
  List<Map<String, dynamic>> _userReviews = [];
  List<Map<String, dynamic>> _userFavorites = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserData();
  }

  void _loadUserData() {
    _loadReviews();
    _loadFavorites();
  }

  // Load reviews directly from Firestore
  Future<void> _loadReviews() async {
    final user = _auth.currentUser;
    if (user == null) return;
   
    setState(() => _loadingReviews = true);
    try {
      final repositoryReviews = await _favoritesRepository.getUserReviews();
      final firestoreReviews = await _getReviewsFromFirestore(user.uid);
     
      // Combine both lists, removing duplicates
      final allReviews = [...repositoryReviews, ...firestoreReviews];
      final uniqueReviews = _removeDuplicateReviews(allReviews);
     
      setState(() => _userReviews = uniqueReviews);
    } catch (e) {
      print('Error loading reviews: $e');
      _showMessage('Error loading reviews: $e');
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  // Get reviews directly from Firestore 'reviews' collection
  Future<List<Map<String, dynamic>>> _getReviewsFromFirestore(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final reviews = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'reviewId': doc.id,
          'recipeId': data['recipeId'] ?? '',
          'recipeName': data['recipeName'] ?? 'Unknown Recipe',
          'rating': data['rating'] ?? 0,
          'review': data['review'],
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
          'userName': data['userName'] ?? 'User',
          'userEmail': data['userEmail'] ?? '',
        };
      }).toList();

      return reviews;
    } catch (e) {
      print('Error fetching reviews from Firestore: $e');
      return [];
    }
  }

  // Remove duplicate reviews based on reviewId
  List<Map<String, dynamic>> _removeDuplicateReviews(List<Map<String, dynamic>> reviews) {
    final uniqueReviews = <String, Map<String, dynamic>>{};
   
    for (final review in reviews) {
      final reviewId = review['reviewId']?.toString() ?? '';
      if (reviewId.isNotEmpty && !uniqueReviews.containsKey(reviewId)) {
        uniqueReviews[reviewId] = review;
      }
    }
   
    return uniqueReviews.values.toList();
  }

  Future<void> _loadFavorites() async {
    final user = _auth.currentUser;
    if (user == null) return;
   
    setState(() => _loadingFavorites = true);
    try {
      final favorites = await _favoritesRepository.getFavorites();
      setState(() => _userFavorites = favorites);
    } catch (e) {
      print('Error loading favorites: $e');
      _showMessage('Error loading favorites');
    } finally {
      setState(() => _loadingFavorites = false);
    }
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notifications = prefs.getBool('notifications') ?? true;
        _darkMode = prefs.getBool('darkMode') ?? false;
        _measurementUnit = prefs.getString('measurementUnit') ?? 'metric';
        _vegetarian = prefs.getBool('vegetarian') ?? false;
        _showNutrition = prefs.getBool('showNutrition') ?? true;
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // Save a setting
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      print('Error saving setting: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // IMPROVED: Logout with proper navigation
  void _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Close dialog first
                Navigator.pop(context);
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                // Sign out
                await _auth.signOut();
                
                // Navigate to login/splash screen
                Navigator.pushNamedAndRemoveUntil(
                  context, 
                  '/login', // Change this to your login route
                  (route) => false
                );
                
                _showMessage('Logged out successfully');
              } catch (e) {
                Navigator.pop(context); // Close loading dialog
                _showMessage('Error during logout: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _changePassword() {
    final user = _auth.currentUser;
    if (user?.email != null) {
      _auth.sendPasswordResetEmail(email: user!.email!);
      _showMessage('Password reset email sent to ${user.email}');
    } else {
      _showMessage('No user logged in');
    }
  }

  void _navigateToFeedback() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MonthlyFeedbackPage()),
    );
  }

  // Update review in Firestore
  Future<void> _updateReview(String reviewId, int newRating, String newComment) async {
    try {
      setState(() => _loadingReviews = true);
     
      await _firestore.collection('reviews').doc(reviewId).update({
        'rating': newRating,
        'review': newComment.isNotEmpty ? newComment : null,
        'updatedAt': Timestamp.now(),
      });
     
      _showMessage('Review updated successfully');
      await _loadReviews();
    } catch (e) {
      print('Error updating review: $e');
      _showMessage('Error updating review: $e');
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  // Delete review from Firestore
  Future<void> _deleteReview(String reviewId) async {
    try {
      setState(() => _loadingReviews = true);
     
      await _firestore.collection('reviews').doc(reviewId).delete();
     
      _showMessage('Review deleted successfully');
      await _loadReviews();
    } catch (e) {
      print('Error deleting review: $e');
      _showMessage('Error deleting review: $e');
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  // Show edit review dialog
  void _showEditReviewDialog(Map<String, dynamic> review) {
    int rating = review['rating'] as int;
    final TextEditingController commentController = TextEditingController(
      text: review['review']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Your Review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  review['recipeName'] ?? 'Recipe',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Update your rating:'),
                const SizedBox(height: 8),
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
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Your review (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Share your experience...',
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
              ElevatedButton(
                onPressed: () {
                  _updateReview(
                    review['reviewId'],
                    rating,
                    commentController.text.trim(),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show delete confirmation
  void _showDeleteConfirmation(Map<String, dynamic> review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteReview(review['reviewId']);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Remove from favorites
  Future<void> _removeFromFavorites(String recipeId, String recipeName) async {
    try {
      setState(() => _loadingFavorites = true);
      await _favoritesRepository.removeFromFavorite(recipeId);
      _showMessage('Removed "$recipeName" from favorites');
      await _loadFavorites();
    } catch (e) {
      _showMessage('Error removing from favorites: $e');
    } finally {
      setState(() => _loadingFavorites = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF1C4322),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF8F8F8),
        foregroundColor: const Color(0xFF1C4322),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1C4322)),
      ),
      body: _buildSettingsTab(user),
    );
  }

  Widget _buildSettingsTab(User? user) {
    return ListView(
      children: [
        // User Info
        _buildUserCard(user),
       
        // App Settings
        _buildSection('App Settings', [
          _buildSwitchTile(
            'Notifications',
            'Receive meal reminders',
            _notifications,
            (value) async {
              setState(() => _notifications = value);
              await _saveSetting('notifications', value);
              if (!value) {
                await NotificationService().cancelAllNotifications();
                _showMessage('Notifications disabled and cancelled');
              } else {
                _showMessage('Notifications enabled');
              }
            },
          ),
        ]),

        // My Content Section - Reviews and Favorites as Columns
        _buildMyContentSection(),

        // Account Actions
        _buildSection('Account', [
          _buildActionTile(
            'Monthly Feedback',
            Icons.feedback,
            _navigateToFeedback,
          ),
          _buildActionTile(
            'Logout',
            Icons.logout,
            _logout,
            isDestructive: true,
          ),
        ]),

        const SizedBox(height: 20),
      ],
    );
  }

  // NEW: My Content Section with Reviews and Favorites as Columns
  Widget _buildMyContentSection() {
    return _buildSection('My Content', [
      // Reviews Column
      _buildContentColumn(
        title: 'My Reviews',
        icon: Icons.star,
        count: _userReviews.length,
        loading: _loadingReviews,
        onTap: _userReviews.isEmpty ? null : () => _showReviewsPreview(),
        emptyMessage: 'No reviews yet',
        onEmptyTap: () {
          // Navigate to recipes page
          Navigator.pop(context);
        },
      ),
      
      const SizedBox(height: 16),
      
      // Favorites Column
      _buildContentColumn(
        title: 'My Favorites',
        icon: Icons.favorite,
        count: _userFavorites.length,
        loading: _loadingFavorites,
        onTap: _userFavorites.isEmpty ? null : () => _showFavoritesPreview(),
        emptyMessage: 'No favorites yet',
        onEmptyTap: () {
          // Navigate to recipes page
          Navigator.pop(context);
        },
      ),
    ]);
  }

  // NEW: Content Column Widget
  Widget _buildContentColumn({
    required String title,
    required IconData icon,
    required int count,
    required bool loading,
    required VoidCallback? onTap,
    required String emptyMessage,
    required VoidCallback onEmptyTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1C4322)),
        title: Text(title),
        subtitle: loading 
            ? const Text('Loading...')
            : count == 0
                ? Text(emptyMessage)
                : Text('$count items'),
        trailing: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // NEW: Show Reviews Preview
  void _showReviewsPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1C4322),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'My Reviews',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _userReviews.isEmpty
                  ? _buildNoReviewsState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _userReviews.length,
                      itemBuilder: (context, index) {
                        final review = _userReviews[index];
                        return _buildReviewCard(review);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Show Favorites Preview
  void _showFavoritesPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1C4322),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'My Favorites',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _userFavorites.isEmpty
                  ? _buildNoFavoritesState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _userFavorites.length,
                      itemBuilder: (context, index) {
                        final recipe = _userFavorites[index];
                        return _buildFavoriteCard(recipe);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Reviews Widgets
  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = review['rating'] as int;
    final reviewText = review['review'] as String?;
    final recipeName = review['recipeName'] ?? 'Unknown Recipe';
    final createdAt = review['createdAt'];
    final updatedAt = review['updatedAt'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe name and rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    recipeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C4322),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        Icons.star,
                        size: 16,
                        color: index < rating ? Colors.amber : Colors.grey.shade300,
                      );
                    }),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Review text
            if (reviewText != null && reviewText.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reviewText,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                ],
              ),

            // Date and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(createdAt, updatedAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (!_loadingReviews)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _showEditReviewDialog(review),
                      tooltip: 'Edit review',
                      color: Colors.blue,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => _showDeleteConfirmation(review),
                      tooltip: 'Delete review',
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Favorites Widgets
  Widget _buildFavoriteCard(Map<String, dynamic> recipe) {
    final recipeName = recipe['name'] ?? recipe['title'] ?? 'Unknown Recipe';
    final recipeId = recipe['id'] ?? '';
    final imageUrl = recipe['imageUrl'] ?? '';
    final cookingTime = recipe['cookingTime'] ?? recipe['totalTime'] ?? 0;
    final calories = recipe['calories'] ?? 0;
    final description = recipe['description'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildRecipePlaceholder();
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildRecipePlaceholder();
                  },
                ),
              )
            : _buildRecipePlaceholder(),
        title: Text(
          recipeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                if (cookingTime > 0)
                  _buildInfoChip(
                    Icons.schedule,
                    '$cookingTime min',
                  ),
                if (calories > 0)
                  _buildInfoChip(
                    Icons.local_fire_department,
                    '$calories cal',
                  ),
              ],
            ),
          ],
        ),
        trailing: _loadingFavorites
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () => _removeFromFavorites(recipeId, recipeName),
                tooltip: 'Remove from favorites',
              ),
      ),
    );
  }

  // Empty States
  Widget _buildNoReviewsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.reviews, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Reviews Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your recipe reviews will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C4322),
            ),
            child: const Text('Browse Recipes'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFavoritesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Favorites Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the heart icon on recipes to add them to favorites',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C4322),
            ),
            child: const Text('Browse Recipes'),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  Widget _buildRecipePlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.restaurant, color: Colors.grey),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic createdAt, dynamic updatedAt) {
    String formatTimestamp(dynamic timestamp) {
      if (timestamp is DateTime) {
        return DateFormat('MMM d, yyyy').format(timestamp);
      }
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return DateFormat('MMM d, yyyy').format(date);
      }
      return 'Unknown date';
    }

    final created = formatTimestamp(createdAt);
    final updated = updatedAt != null ? formatTimestamp(updatedAt) : null;

    if (updated != null && updated != created) {
      return 'Created: $created • Updated: $updated';
    }
    return 'Created: $created';
  }

  // Existing helper methods
  Widget _buildUserCard(User? user) {
    return Card(
      color: const Color(0xFFF8F8F8),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF1C4322),
              radius: 30,
              child: Text(
                user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user?.email ?? 'Not logged in',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (user?.emailVerified == true) ...[
              const SizedBox(height: 4),
              const Text(
                '✓ Verified',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C4322),
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF1C4322),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildActionTile(String title, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return Column(
      children: [
        ListTile(
          title: Text(
            title,
            style: TextStyle(color: isDestructive ? Colors.red : null),
          ),
          leading: Icon(
            icon,
            color: isDestructive ? Colors.red : const Color(0xFF1C4322),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (!isDestructive) const Divider(height: 1),
      ],
    );
  }
}
