
// user_management_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _loadingReviewsAndFavorites = false;
  String? _errorMessage;
  int _currentLoadStep = 0; // Track loading progress
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadUsersOptimized();
  }

  // OPTIMIZED: Load only basic user data first, then load additional data lazily
  Future<void> _loadUsersOptimized() async {
    try {
      print('🔄 Loading users from Firestore...');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentLoadStep = 1;
      });

      // STEP 1: Load only basic user data (fast)
      final usersSnapshot = await _firestore.collection('users').get();
      print('📊 Found ${usersSnapshot.docs.length} users in collection');
     
      if (usersSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _users = [];
            _isLoading = false;
          });
        }
        return;
      }

      _totalUsers = usersSnapshot.docs.length;

      // Process only basic user data first
      List<Map<String, dynamic>> basicUsers = [];

      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data() as Map<String, dynamic>? ?? {};
          
          basicUsers.add({
            'id': userDoc.id,
            'name': _getUserName(userData),
            'email': userData['email']?.toString() ?? 'No email',
            'age': _getUserAge(userData),
            'goal': userData['goal']?.toString() ?? userData['fitnessGoal']?.toString() ?? 'Not set',
            'dietType': userData['dietType']?.toString() ?? userData['diet']?.toString() ?? 'Not specified',
            'dislikes': userData['dislikes']?.toString() ?? userData['allergies']?.toString() ?? 'None',
            'progress': {'weekNumber': 1, 'dayNumber': 1, 'completedDays': [], 'weekCompleted': false},
            'reviewsCount': 0, // Placeholder
            'favoritesCount': 0, // Placeholder
            'isFullyLoaded': false, // Mark as not fully loaded
          });
        } catch (e) {
          print('⚠️ Error processing user ${userDoc.id}: $e');
          basicUsers.add(_createMinimalUserData(userDoc.id, {}));
        }
      }

      // Show basic data immediately
      if (mounted) {
        setState(() {
          _users = basicUsers;
          _isLoading = false;
          _currentLoadStep = 2;
        });
      }

      print('✅ Basic user data loaded: ${_users.length} users');

      // STEP 2: Load additional data in background (lazy loading)
      _loadAdditionalUserData(basicUsers.map((u) => u['id'] as String).toList());

    } catch (e) {
      print('❌ Error loading users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading users: ${e.toString()}';
        });
      }
    }
  }

  // Load additional data (progress, reviews, favorites) in background
  Future<void> _loadAdditionalUserData(List<String> userIds) async {
    try {
      setState(() {
        _loadingReviewsAndFavorites = true;
      });

      // Process users in smaller batches to avoid overwhelming Firestore
      const batchSize = 5;
      
      for (int i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.sublist(
          i, 
          i + batchSize > userIds.length ? userIds.length : i + batchSize
        );

        // Process batch in parallel
        final batchResults = await Future.wait(
          batch.map((userId) => _loadUserAdditionalData(userId)),
          eagerError: false,
        );

        // Update UI with each batch
        for (int j = 0; j < batchResults.length; j++) {
          final result = batchResults[j];
          if (result != null) {
            final userId = batch[j];
            final userIndex = _users.indexWhere((user) => user['id'] == userId);
            
            if (userIndex != -1 && mounted) {
              setState(() {
                _users[userIndex] = {
                  ..._users[userIndex],
                  ...result,
                  'isFullyLoaded': true,
                };
              });
            }
          }
        }

        // Small delay between batches to avoid overwhelming
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Additional user data loaded for ${userIds.length} users');
      
    } catch (e) {
      print('⚠️ Error loading additional user data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingReviewsAndFavorites = false;
        });
      }
    }
  }

  // Load additional data for a single user
  Future<Map<String, dynamic>?> _loadUserAdditionalData(String userId) async {
    try {
      final progress = await _getUserProgress(userId);
      final reviewsCount = await _getUserReviewsCount(userId); // OPTIMIZED: Get count only
      final favoritesCount = await _getUserFavoritesCount(userId); // OPTIMIZED: Get count only

      return {
        'progress': progress,
        'reviewsCount': reviewsCount,
        'favoritesCount': favoritesCount,
      };
    } catch (e) {
      print('⚠️ Error loading additional data for user $userId: $e');
      return null;
    }
  }

  Map<String, dynamic> _createMinimalUserData(String userId, Map<String, dynamic> userData) {
    return {
      'id': userId,
      'name': _getUserName(userData),
      'email': userData['email']?.toString() ?? 'No email',
      'age': _getUserAge(userData),
      'goal': 'Not set',
      'dietType': 'Not specified',
      'dislikes': 'None',
      'progress': {'weekNumber': 1, 'dayNumber': 1, 'completedDays': [], 'weekCompleted': false},
      'reviewsCount': 0,
      'favoritesCount': 0,
      'isFullyLoaded': true,
    };
  }

  String _getUserName(Map<String, dynamic> userData) {
    final name = userData['name']?.toString() ??
                userData['displayName']?.toString() ??
                userData['username']?.toString() ??
                userData['firstName']?.toString() ??
                '${userData['firstName']?.toString() ?? ''} ${userData['lastName']?.toString() ?? ''}'.trim();
   
    if (name.isEmpty) {
      final email = userData['email']?.toString();
      if (email != null && email.isNotEmpty) {
        return email.split('@').first;
      }
      return 'Unknown User';
    }
   
    return name;
  }

  String _getUserAge(Map<String, dynamic> userData) {
    final age = userData['age'];
    if (age == null) return 'N/A';
   
    if (age is String) {
      return age.isNotEmpty ? age : 'N/A';
    } else if (age is int) {
      return age.toString();
    } else if (age is double) {
      return age.toInt().toString();
    }
   
    return 'N/A';
  }

  String _getAvatarText(String name) {
    if (name.isEmpty || name == 'Unknown User') {
      return '?';
    }
   
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) return '?';
   
    return cleanedName.substring(0, 1).toUpperCase();
  }

  Future<Map<String, dynamic>> _getUserProgress(String userId) async {
    try {
      // Try only the most likely path first
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc('current_week')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'weekNumber': data['weekNumber'] ?? data['currentWeek'] ?? 1,
          'dayNumber': data['dayNumber'] ?? data['currentDay'] ?? 1,
          'completedDays': data['completedDays'] ?? data['completed_days'] ?? [],
          'weekCompleted': data['weekCompleted'] ?? data['week_completed'] ?? false,
        };
      }
      
      return {
        'weekNumber': 1,
        'dayNumber': 1,
        'completedDays': [],
        'weekCompleted': false,
      };
    } catch (e) {
      return {
        'weekNumber': 1,
        'dayNumber': 1,
        'completedDays': [],
        'weekCompleted': false,
      };
    }
  }

  // OPTIMIZED: Get only review count, not all review documents
  Future<int> _getUserReviewsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      // Try alternative field name
      try {
        final snapshot = await _firestore
            .collection('reviews')
            .where('user_id', isEqualTo: userId)
            .count()
            .get();

        return snapshot.count ?? 0;
      } catch (e2) {
        return 0;
      }
    }
  }

  // OPTIMIZED: Get only favorites count, not all favorite documents
  Future<int> _getUserFavoritesCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // DELETE USER FUNCTIONALITY
  Future<void> _deleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete user "$userName"? This action cannot be undone.'),
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
                Text('Deleting user...'),
              ],
            ),
          ),
        );

        await _firestore.collection('users').doc(userId).delete();

        if (mounted) {
          setState(() {
            _users.removeWhere((user) => user['id'] == userId);
          });
        }

        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "$userName" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // UPDATE USER FUNCTIONALITY (unchanged)
  Future<void> _updateUser(Map<String, dynamic> user) async {
    final TextEditingController nameController = TextEditingController(text: user['name']);
    final TextEditingController emailController = TextEditingController(text: user['email']);
    final TextEditingController ageController = TextEditingController(text: user['age'] != 'N/A' ? user['age'] : '');
    final TextEditingController goalController = TextEditingController(text: user['goal'] != 'Not set' ? user['goal'] : '');
    final TextEditingController dietTypeController = TextEditingController(text: user['dietType'] != 'Not specified' ? user['dietType'] : '');
    final TextEditingController dislikesController = TextEditingController(text: user['dislikes'] != 'None' ? user['dislikes'] : '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: goalController,
                decoration: const InputDecoration(labelText: 'Goal'),
              ),
              TextField(
                controller: dietTypeController,
                decoration: const InputDecoration(labelText: 'Diet Type'),
              ),
              TextField(
                controller: dislikesController,
                decoration: const InputDecoration(labelText: 'Dislikes/Allergies'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Updating user...'),
                      ],
                    ),
                  ),
                );

                final updateData = {
                  if (nameController.text.isNotEmpty) 'name': nameController.text,
                  if (emailController.text.isNotEmpty) 'email': emailController.text,
                  if (ageController.text.isNotEmpty) 'age': int.tryParse(ageController.text) ?? ageController.text,
                  if (goalController.text.isNotEmpty) 'goal': goalController.text,
                  if (dietTypeController.text.isNotEmpty) 'dietType': dietTypeController.text,
                  if (dislikesController.text.isNotEmpty) 'dislikes': dislikesController.text,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                await _firestore.collection('users').doc(user['id']).update(updateData);

                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  _loadUsersOptimized();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('User "${user['name']}" updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details: ${user['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem('User ID', user['id'].toString()),
                _buildDetailItem('Name', user['name'].toString()),
                _buildDetailItem('Email', user['email'].toString()),
                _buildDetailItem('Age', user['age'].toString()),
                _buildDetailItem('Goal', user['goal'].toString()),
                _buildDetailItem('Diet Type', user['dietType'].toString()),
                _buildDetailItem('Dislikes', user['dislikes'].toString()),
               
                const SizedBox(height: 16),
                const Text('Progress:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildDetailItem('Week', user['progress']['weekNumber']?.toString() ?? '1'),
                _buildDetailItem('Current Day', user['progress']['dayNumber']?.toString() ?? '1'),
                _buildDetailItem('Completed Days', (user['progress']['completedDays'] as List).length.toString()),
                _buildDetailItem('Week Completed', user['progress']['weekCompleted']?.toString() ?? 'false'),
               
                const SizedBox(height: 16),
                const Text('Activity:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildDetailItem('Reviews', user['reviewsCount'].toString()),
                _buildDetailItem('Favorites', user['favoritesCount'].toString()),
               
                if (!(user['isFullyLoaded'] ?? true))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text('Loading additional data...', style: TextStyle(fontSize: 12, color: Colors.orange)),
                      ],
                    ),
                  ),
              ],
            ),
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
              _updateUser(user);
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(user['id'], user['name']);
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
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserActions(BuildContext context, Map<String, dynamic> user) {
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
              _showUserDetails(user);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit User'),
            onTap: () {
              Navigator.pop(context);
              _updateUser(user);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete User', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteUser(user['id'], user['name']);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
         foregroundColor: Colors.black,
backgroundColor: const Color(0xFFF8F8F8), 
          automaticallyImplyLeading: false, // <-- removes back arrow

        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadUsersOptimized,
            tooltip: 'Refresh Users',
          ),
          if (_loadingReviewsAndFavorites)
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
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Loading basic user data...'),
                  if (_currentLoadStep == 1 && _totalUsers > 0)
                    Text('Found $_totalUsers users', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsersOptimized,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C4322),
                        ),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No Users Found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'No users were found in the database.',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadUsersOptimized,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1C4322),
                            ),
                            child: const Text('Refresh', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            color: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.people, color: Colors.blue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total Users: ${_users.length}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        if (_loadingReviewsAndFavorites)
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
                                                Text(
                                                  'Loading additional data...',
                                                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                       
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadUsersOptimized,
                            child: ListView.builder(
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final progress = user['progress'] as Map<String, dynamic>;
                                final userName = user['name'].toString();
                                final isFullyLoaded = user['isFullyLoaded'] ?? false;
                               
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  elevation: 2,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF1C4322),
                                      child: Text(
                                        _getAvatarText(userName),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          user['email'].toString(),
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Goal: ${user['goal']}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          'Progress: Week ${progress['weekNumber'] ?? 1}, Day ${progress['dayNumber'] ?? 1}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (!isFullyLoaded)
                                          const Row(
                                            children: [
                                              SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1)),
                                              SizedBox(width: 4),
                                              Text('Loading...', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Wrap(
                                          spacing: 4,
                                          children: [
                                            Chip(
                                              label: Text(
                                                '${user['reviewsCount']} rev',
                                                style: const TextStyle(fontSize: 10),
                                              ),
                                              backgroundColor: Colors.blue.shade100,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            Chip(
                                              label: Text(
                                                '${user['favoritesCount']} fav',
                                                style: const TextStyle(fontSize: 10),
                                              ),
                                              backgroundColor: Colors.green.shade100,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.more_vert),
                                          onPressed: () => _showUserActions(context, user),
                                          tooltip: 'User Actions',
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showUserDetails(user),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
