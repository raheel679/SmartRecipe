import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final CollectionReference recipesRef = FirebaseFirestore.instance.collection('recipe');
  final CollectionReference usersRef = FirebaseFirestore.instance.collection('users');
  final CollectionReference reviewsRef = FirebaseFirestore.instance.collection('reviews');

  // Controllers for recipe form
  final TextEditingController titleController = TextEditingController();
  final TextEditingController cookingTimeController = TextEditingController();
  final TextEditingController goalController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();
  final TextEditingController ingredientsController = TextEditingController();
  final TextEditingController stepsController = TextEditingController();
  String? editingRecipeId;

  // Search controllers
  final TextEditingController searchController = TextEditingController();

  // For filtering lists
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    searchController.addListener(() {
      setState(() {
        searchQuery = searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    titleController.dispose();
    cookingTimeController.dispose();
    goalController.dispose();
    imageUrlController.dispose();
    ingredientsController.dispose();
    stepsController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> fetchRecipes() async {
    final snapshot = await recipesRef.get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final snapshot = await usersRef.get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
  }

  Future<List<Map<String, dynamic>>> fetchReviews() async {
    final snapshot = await reviewsRef.get();

    final futures = snapshot.docs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;

      String userName = "Unknown User";
      String recipeTitle = "Unknown Recipe";

      try {
        if (data["userId"] != null) {
          final userDoc = await usersRef.doc(data["userId"]).get();
          if (userDoc.exists) userName = userDoc["name"] ?? userName;
        }
        if (data["recipeId"] != null) {
          final recipeDoc = await recipesRef.doc(data["recipeId"]).get();
          if (recipeDoc.exists) recipeTitle = recipeDoc["title"] ?? recipeTitle;
        }
      } catch (e) {
        print("Error fetching review related data: $e");
      }

      return {
        "id": doc.id,
        "rating": data["rating"] ?? 0,
        "comment": data["comment"] ?? "",
        "userName": userName,
        "recipeTitle": recipeTitle,
      };
    }).toList();

    return await Future.wait(futures);
  }

  void showRecipeDialog({Map<String, dynamic>? recipe}) {
    if (recipe != null) {
      editingRecipeId = recipe['id'];
      titleController.text = recipe['title'] ?? '';
      cookingTimeController.text = recipe['cookingTime']?.toString() ?? '';
      goalController.text = recipe['goal'] ?? '';
      imageUrlController.text = recipe['imageUrl'] ?? '';
      ingredientsController.text = (recipe['ingredients'] as List<dynamic>).join('\n');
      stepsController.text = (recipe['steps'] as List<dynamic>).join('\n');
    } else {
      clearRecipeForm();
    }

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(editingRecipeId != null ? 'Update Recipe' : 'Add Recipe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(titleController, 'Title', validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 10),
                _buildTextField(cookingTimeController, 'Cooking Time (min)',
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a valid number' : null),
                const SizedBox(height: 10),
                _buildTextField(goalController, 'Goal'),
                const SizedBox(height: 10),
                _buildTextField(imageUrlController, 'Image URL'),
                const SizedBox(height: 10),
                _buildTextField(ingredientsController, 'Ingredients (one per line)', maxLines: 3),
                const SizedBox(height: 10),
                _buildTextField(stepsController, 'Steps (one per line)', maxLines: 5),
                if (imageUrlController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(imageUrlController.text, height: 120,width: 120, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  clearRecipeForm();
                },
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Title is required')),
                    );
                    return;
                  }
                  final recipeData = {
                    'title': titleController.text.trim(),
                    'cookingTime': int.tryParse(cookingTimeController.text.trim()) ?? 0,
                    'goal': goalController.text.trim(),
                    'imageUrl': imageUrlController.text.trim(),
                    'ingredients': ingredientsController.text.trim().split('\n'),
                    'steps': stepsController.text.trim().split('\n'),
                  };

                  if (editingRecipeId != null) {
                    await recipesRef.doc(editingRecipeId).update(recipeData);
                  } else {
                    await recipesRef.add(recipeData);
                  }

                  Navigator.pop(context);
                  clearRecipeForm();
                  setState(() {});
                },
                child: Text(editingRecipeId != null ? 'Update' : 'Add')),
          ],
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  void clearRecipeForm() {
    editingRecipeId = null;
    titleController.clear();
    cookingTimeController.clear();
    goalController.clear();
    imageUrlController.clear();
    ingredientsController.clear();
    stepsController.clear();
  }

  Future<void> _refreshCurrentTab() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1C4322);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: primaryColor,
          automaticallyImplyLeading: false, // <-- removes back arrow

        titleTextStyle: const TextStyle(color: Colors.white),
        bottom: TabBar(
  controller: _tabController,
  indicatorColor: Colors.white,
  labelColor: Colors.white,           // Color for selected tab (icon + text)
  unselectedLabelColor: Colors.grey[300], // Color for unselected tabs
  tabs: const [
    Tab(icon: Icon(Icons.book), text: 'Recipes'),
    Tab(icon: Icon(Icons.person), text: 'Users'),
    Tab(icon: Icon(Icons.rate_review), text: 'Reviews'),
  ],
),),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Recipes Tab
                RefreshIndicator(
                  onRefresh: _refreshCurrentTab,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: fetchRecipes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final recipes = snapshot.data ?? [];
                      final filtered = recipes.where((r) {
                        final title = (r['title'] ?? '').toString().toLowerCase();
                        final goal = (r['goal'] ?? '').toString().toLowerCase();
                        return title.contains(searchQuery) || goal.contains(searchQuery);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('No recipes found.'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final recipe = filtered[index];
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: (recipe['imageUrl'] != null && recipe['imageUrl'].isNotEmpty)
                                    ? Image.network(recipe['imageUrl'], width: 60, height: 60, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                                    : const Icon(Icons.book, size: 50, color: Colors.grey),
                              ),
                              title: Text(recipe['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Goal: ${recipe['goal']} | Time: ${recipe['cookingTime']} min'),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Edit Recipe',
                                    onPressed: () => showRecipeDialog(recipe: recipe),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Delete Recipe',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("Confirm Delete"),
                                          content: const Text("Are you sure you want to delete this recipe?"),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text("Cancel")),
                                            ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text("Delete")),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await recipesRef.doc(recipe['id']).delete();
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Users Tab
                RefreshIndicator(
                  onRefresh: _refreshCurrentTab,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: fetchUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final users = snapshot.data ?? [];
                      final filtered = users.where((u) {
                        final name = (u['name'] ?? '').toString().toLowerCase();
                        final email = (u['email'] ?? '').toString().toLowerCase();
                        final role = (u['role'] ?? '').toString().toLowerCase();
                        return name.contains(searchQuery) || email.contains(searchQuery) || role.contains(searchQuery);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('No users found.'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryColor,
                                child: Text(
                                  (user['name'] != null && user['name'].isNotEmpty)
                                      ? user['name'][0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${user['email']} | Role: ${user['role']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete User',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Confirm Delete"),
                                      content: const Text(
                                          "Are you sure you want to delete this user? This will also remove their reviews."),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text("Cancel")),
                                        ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text("Delete")),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await usersRef.doc(user['id']).delete();
                                    final userReviews = await reviewsRef.where("userId", isEqualTo: user['id']).get();
                                    for (var r in userReviews.docs) {
                                      await reviewsRef.doc(r.id).delete();
                                    }
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Reviews Tab
                RefreshIndicator(
                  onRefresh: _refreshCurrentTab,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: fetchReviews(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final reviews = snapshot.data ?? [];
                      final filtered = reviews.where((r) {
                        final userName = (r['userName'] ?? '').toString().toLowerCase();
                        final recipeTitle = (r['recipeTitle'] ?? '').toString().toLowerCase();
                        final comment = (r['comment'] ?? '').toString().toLowerCase();
                        return userName.contains(searchQuery) ||
                            recipeTitle.contains(searchQuery) ||
                            comment.contains(searchQuery);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('No reviews found.'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final review = filtered[index];
                          return Card(
  elevation: 3,
  margin: const EdgeInsets.symmetric(vertical: 6),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: ListTile(
    leading: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < (review['rating'] ?? 0) ? Icons.star : Icons.star_border,
          color: Colors.orange,
          size: 20,
        );
      }),
    ),
    title: Text(
      ':User   ${review['userName']}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Text('Recipe: ${review['recipeTitle']}\nComment: ${review['comment']}'),
    isThreeLine: true,
    trailing: IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      tooltip: 'Delete Review',
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Confirm Delete"),
            content: const Text("Are you sure you want to delete this review?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Delete")),
            ],
          ),
        );
        if (confirm == true) {
          await reviewsRef.doc(review['id']).delete();
          setState(() {});
        }
      },
    ),
  ),
);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
     floatingActionButton: _tabController.index == 0
    ? FloatingActionButton(
        onPressed: () => showRecipeDialog(),
        backgroundColor: primaryColor,
        tooltip: 'Add Recipe',
        child: const Icon(Icons.add, color: Colors.white,),
      )
    : null,
    );
  }
}