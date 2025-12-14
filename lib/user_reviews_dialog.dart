// user_reviews_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserReviewsDialog extends StatefulWidget {
  final String userId;
  final String userName;

  const UserReviewsDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserReviewsDialog> createState() => _UserReviewsDialogState();
}

class _UserReviewsDialogState extends State<UserReviewsDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserReviews();
  }

  Future<void> _loadUserReviews() async {
    try {
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _reviews = reviewsSnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user reviews: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).delete();
      _loadUserReviews(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'User Reviews',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text('For: ${widget.userName}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : _reviews.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Text('No reviews found'),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _reviews.length,
                          itemBuilder: (context, index) {
                            final review = _reviews[index].data() as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(review['recipeName'] ?? 'Unknown Recipe'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (review['review'] != null)
                                      Text(review['review']!),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        ...List.generate(5, (i) => Icon(
                                          Icons.star,
                                          size: 16,
                                          color: i < review['rating'] ? Colors.amber : Colors.grey,
                                        )),
                                        const Spacer(),
                                        if (review['createdAt'] != null)
                                          Text(
                                            DateFormat('MMM d, yyyy').format(
                                              (review['createdAt'] as Timestamp).toDate()
                                            ),
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _deleteReview(_reviews[index].id),
                                ),
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
}

class UserFavoritesDialog extends StatefulWidget {
  final String userId;
  final String userName;

  const UserFavoritesDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserFavoritesDialog> createState() => _UserFavoritesDialogState();
}

class _UserFavoritesDialogState extends State<UserFavoritesDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserFavorites();
  }

  Future<void> _loadUserFavorites() async {
    try {
      final favoritesSnapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      setState(() {
        _favorites = favoritesSnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user favorites: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(String favoriteId) async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('favorites')
          .doc(favoriteId)
          .delete();
      
      _loadUserFavorites(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Favorite removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'User Favorites',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text('For: ${widget.userName}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : _favorites.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Text('No favorites found'),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) {
                            final favorite = _favorites[index].data() as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.favorite, color: Colors.red),
                                title: Text(favorite['title'] ?? favorite['name'] ?? 'Unknown Recipe'),
                                subtitle: favorite['description'] != null
                                    ? Text(favorite['description']!)
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _removeFavorite(_favorites[index].id),
                                ),
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
}
