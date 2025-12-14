
// admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_recipe_app/WelcomeScreen.dart';
import 'user_management_page.dart';
import 'feedback_management_page.dart';
import 'recipe_management_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 
  int _currentIndex = 0;
  Map<String, dynamic> _stats = {
    'users': 0,
    'reviews': 0,
    'recipes': 0,
    'recipe': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      print('🔄 Loading admin dashboard stats...');
      
      // Load all counts using manual document counting
      final usersCount = await _getCollectionCount('users');
      final reviewsCount = await _getCollectionCount('reviews');
      final recipesCount = await _getCollectionCount('recipes');
      final recipeCount = await _getCollectionCount('recipe');

      setState(() {
        _stats = {
          'users': usersCount,
          'reviews': reviewsCount,
          'recipes': recipesCount,
          'recipe': recipeCount,
        };
        _isLoading = false;
      });
      
      print('✅ Dashboard stats loaded:');
      print('   👥 Users: $usersCount');
      print('   💬 Reviews: $reviewsCount');
      print('   🍳 Recipes: $recipesCount');
      // print('   🥗 Spoonacular: $recipeCount');
    } catch (e) {
      print('❌ Error loading stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<int> _getCollectionCount(String collectionName) async {
    try {
      print('   📊 Counting documents in $collectionName...');
      final querySnapshot = await _firestore.collection(collectionName).get();
      final count = querySnapshot.docs.length;
      print('   ✅ $collectionName: $count documents');
      return count;
    } catch (e) {
      print('   ❌ Error counting $collectionName: $e');
      return 0;
    }
  }

  void _refreshStats() {
    setState(() {
      _isLoading = true;
    });
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color.fromARGB(255, 222, 233, 219),
        foregroundColor: const Color.fromARGB(255, 3, 3, 2),
          automaticallyImplyLeading: false, // <-- removes back arrow

        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStats,
            tooltip: 'Refresh Stats',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromARGB(255, 222, 233, 219),
        selectedItemColor: const Color.fromARGB(255, 133, 194, 120),
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feedback),
            label: 'Feedback',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Recipes',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const UserManagementPage();
      case 2:
        return const FeedbackManagementPage();
      case 3:
        return const RecipeManagementPage(collection: 'recipes');
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading statistics...'),
                ],
              ),
            )
          else
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
                children: [
                  _buildStatCard(
                    'Total Users', 
                    _stats['users'] ?? 0, 
                    Icons.people, 
                    Colors.blue,
                    'Registered users in the app'
                  ),
                  _buildStatCard(
                    'Recipe Reviews', 
                    _stats['reviews'] ?? 0, 
                    Icons.reviews, 
                    Colors.orange,
                    'User reviews on recipes'
                  ),
                  _buildStatCard(
                    'Firebase Recipes', 
                    _stats['recipes'] ?? 0, 
                    Icons.restaurant, 
                    Colors.green,
                    'Recipes in Firebase collection'
                  ),
                  // _buildStatCard(
                  //   'Spoonacular Recipes', 
                  //   _stats['recipe'] ?? 0, 
                  //   Icons.fastfood, 
                  //   Colors.purple,
                  //   'Recipes from Spoonacular API'
                  // ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color, String description) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

 Future<void> _signOut() async {
  try {
    await _auth.signOut();

    // After sign out, go to Welcome Page
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  } catch (e) {
    print('Error signing out: $e');
  }
}

}
