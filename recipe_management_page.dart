import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_recipe_page.dart';

class RecipeManagementPage extends StatefulWidget {
  final String collection;
  
  const RecipeManagementPage({super.key, required this.collection});

  @override
  State<RecipeManagementPage> createState() => _RecipeManagementPageState();
}

class _RecipeManagementPageState extends State<RecipeManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _recipes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      print('🔄 Loading recipes from ${widget.collection}...');
      
      final recipesSnapshot = await _firestore
          .collection(widget.collection)
          .orderBy('name')
          .get();

      // Use Set to remove duplicates by document ID
      final uniqueRecipes = <String, QueryDocumentSnapshot>{};
      for (var doc in recipesSnapshot.docs) {
        uniqueRecipes[doc.id] = doc;
      }

      setState(() {
        _recipes = uniqueRecipes.values.toList();
        _isLoading = false;
      });
      
      print('✅ Loaded ${_recipes.length} unique recipes from ${widget.collection}');
    } catch (e) {
      print('❌ Error loading recipes: $e');
      setState(() => _isLoading = false);
    }
  }

  List<QueryDocumentSnapshot> get _filteredRecipes {
    if (_searchQuery.isEmpty) {
      return _recipes;
    }
    
    return _recipes.where((recipe) {
      final data = recipe.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      final description = data['description']?.toString().toLowerCase() ?? '';
      final mealType = data['mealType']?.toString().toLowerCase() ?? '';
      
      return name.contains(_searchQuery.toLowerCase()) ||
             description.contains(_searchQuery.toLowerCase()) ||
             mealType.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _navigateToAddRecipe() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecipePage(
          collection: widget.collection,
          isEditing: false,
        ),
      ),
    ).then((value) {
      // Refresh when returning from AddRecipePage
      if (value == true) {
        print('🔄 Refreshing recipes list after adding...');
        _loadRecipes();
      }
    });
  }

  void _showRecipeDetails(QueryDocumentSnapshot recipeDoc) {
    final recipe = recipeDoc.data() as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe['name'] ?? 'Recipe Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem('Name', recipe['name'] ?? 'N/A'),
                _buildDetailItem('Description', recipe['description'] ?? 'N/A'),
                _buildDetailItem('Meal Type', recipe['mealType'] ?? 'N/A'),
                _buildDetailItem('Complexity', recipe['complexity'] ?? 'N/A'),
                _buildDetailItem('Prep Time', '${recipe['prepTime'] ?? 0} min'),
                _buildDetailItem('Cook Time', '${recipe['cookTime'] ?? 0} min'),
                _buildDetailItem('Total Time', 
                  '${recipe['totalTime'] ?? recipe['cookingTime'] ?? 0} min'),
                _buildDetailItem('Calories', '${recipe['calories'] ?? 0} cal'),
                _buildDetailItem('Protein', '${recipe['protein'] ?? 0}g'),
                _buildDetailItem('Carbs', '${recipe['carbs'] ?? 0}g'),
                _buildDetailItem('Fats', '${recipe['fats'] ?? 0}g'),
                _buildDetailItem('Fiber', '${recipe['fiber'] ?? 0}g'),
                
                if (recipe['ingredients'] != null && 
                    (recipe['ingredients'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Ingredients:', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...(recipe['ingredients'] as List).map((ingredient) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $ingredient'),
                    )
                  ).toList(),
                ],
                
                if (recipe['instructions'] != null && 
                    (recipe['instructions'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Instructions:', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...(recipe['instructions'] as List).map((instruction) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('• $instruction'),
                    )
                  ).toList(),
                ],
                
                if (recipe['tags'] != null && 
                    (recipe['tags'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Tags:', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (recipe['tags'] as List).map((tag) => Chip(
                      label: Text(tag.toString()),
                      backgroundColor: Colors.green.shade100,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                ],

                if (recipe['goalTags'] != null && 
                    (recipe['goalTags'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Goal Tags:', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (recipe['goalTags'] as List).map((tag) => Chip(
                      label: Text(tag.toString()),
                      backgroundColor: Colors.blue.shade100,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                ],
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
            onPressed: () => _navigateToEditRecipe(recipeDoc),
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => _showDeleteConfirmation(recipeDoc),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToEditRecipe(QueryDocumentSnapshot recipeDoc) {
    Navigator.pop(context); // Close details dialog first
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecipePage(
          collection: widget.collection,
          isEditing: true,
          recipeData: recipeDoc.data() as Map<String, dynamic>,
          recipeId: recipeDoc.id,
        ),
      ),
    ).then((value) {
      // Refresh when returning from Edit
      if (value == true) {
        print('🔄 Refreshing recipes list after editing...');
        _loadRecipes();
      }
    });
  }

  Future<void> _deleteRecipe(QueryDocumentSnapshot recipeDoc) async {
    try {
      await _firestore.collection(widget.collection).doc(recipeDoc.id).delete();
      
      // Remove from local list
      setState(() {
        _recipes.removeWhere((recipe) => recipe.id == recipeDoc.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting recipe: $e')),
      );
    }
  }

  void _showDeleteConfirmation(QueryDocumentSnapshot recipeDoc) {
    final recipe = recipeDoc.data() as Map<String, dynamic>;
    final recipeName = recipe['name'] ?? 'Unknown Recipe';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "$recipeName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRecipe(recipeDoc);
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
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.collection} Management'),
        foregroundColor: Colors.black,
        backgroundColor: const Color(0xFFF8F8F8),  
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecipes,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddRecipe,
        backgroundColor: const Color(0xFF1C4322),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search recipes...',
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

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collection: ${widget.collection}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: Colors.grey
                  ),
                ),
                Text(
                  '${_filteredRecipes.length} of ${_recipes.length} recipes',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Recipes List - FIXED WITH UNIQUE KEYS
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecipes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _recipes.isEmpty 
                                ? 'No Recipes Found' 
                                : 'No Matching Recipes',
                              style: const TextStyle(
                                fontSize: 18, 
                                color: Colors.grey
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _recipes.isEmpty
                                ? 'Add your first recipe to get started'
                                : 'Try a different search term',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            if (_recipes.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _navigateToAddRecipe,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1C4322),
                                ),
                                child: const Text('Add First Recipe'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRecipes,
                        child: ListView.builder(
                          itemCount: _filteredRecipes.length,
                          itemBuilder: (context, index) {
                            final recipeDoc = _filteredRecipes[index];
                            final recipe = recipeDoc.data() as Map<String, dynamic>;
                            
                            return Card(
                              key: ValueKey(recipeDoc.id), // Add unique key
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16, 
                                vertical: 8
                              ),
                              elevation: 2,
                              child: ListTile(
                                leading: recipe['imageUrl'] != null && 
                                        recipe['imageUrl'].toString().isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage: 
                                          NetworkImage(recipe['imageUrl'].toString()),
                                        backgroundColor: Colors.grey.shade200,
                                        radius: 25,
                                        onBackgroundImageError: (error, stackTrace) {
                                          print('❌ Error loading image: $error');
                                        },
                                      )
                                    : const CircleAvatar(
                                        backgroundColor: Color(0xFF1C4322),
                                        child: Icon(
                                          Icons.restaurant, 
                                          color: Colors.white
                                        ),
                                      ),
                                title: Text(
                                  recipe['name'] ?? 'Unnamed Recipe',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      recipe['description'] ?? 'No description',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        Chip(
                                          label: Text(recipe['mealType'] ?? 'N/A'),
                                          backgroundColor: Colors.blue.shade50,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Chip(
                                          label: Text(
                                            '${recipe['calories']?.toInt() ?? 0} cal'
                                          ),
                                          backgroundColor: Colors.green.shade50,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        if (recipe['complexity'] != null)
                                          Chip(
                                            label: Text(recipe['complexity'].toString()),
                                            backgroundColor: Colors.orange.shade50,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _navigateToEditRecipe(recipeDoc),
                                      tooltip: 'Edit Recipe',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _showDeleteConfirmation(recipeDoc),
                                      tooltip: 'Delete Recipe',
                                    ),
                                  ],
                                ),
                                onTap: () => _showRecipeDetails(recipeDoc),
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
