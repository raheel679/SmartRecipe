import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'favorites_repository.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoritesRepository _repository = FavoritesRepository();
  late Future<List<Map<String, dynamic>>> _favoritesFuture;
  

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _repository.getFavorites();
  }

  void _refreshFavorites() {
    setState(() {
      _favoritesFuture = _repository.getFavorites();
    });
  }

  String _getRecipeTitle(Map<String, dynamic> recipe) {
    return recipe['name'] ?? recipe['title'] ?? 'Untitled Recipe';
  }

  String _getRecipeDescription(Map<String, dynamic> recipe) {
    return recipe['description']?.toString() ?? '';
  }

  int _getCookingTime(Map<String, dynamic> recipe) {
    return recipe['cookingTime'] ?? recipe['totalTime'] ?? 0;
  }

  int _getCalories(Map<String, dynamic> recipe) {
    return recipe['calories'] ?? 0;
  }

  int _getProtein(Map<String, dynamic> recipe) {
    return recipe['protein'] ?? 0;
  }

  void _showRecipeDetails(Map<String, dynamic> recipe) {
    final description = _getRecipeDescription(recipe);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _getRecipeTitle(recipe),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C4322),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // IMAGE
              if (recipe['imageUrl'] != null &&
                  recipe['imageUrl'].toString().isNotEmpty)
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(recipe['imageUrl'].toString()),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant, size: 60, color: Colors.grey),
                ),

              const SizedBox(height: 16),

              if (description.isNotEmpty) ...[
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C4322),
                  ),
                ),
                const SizedBox(height: 8),
                Text(description,
                    style: const TextStyle(fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 16),
              ],

              const Text(
                'Nutrition Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C4322),
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildNutritionInfo('Calories', '${_getCalories(recipe)} cal'),
                  _buildNutritionInfo('Protein', '${_getProtein(recipe)}g'),
                  if (recipe['carbs'] != null)
                    _buildNutritionInfo('Carbs', '${recipe['carbs']}g'),
                  if (recipe['fats'] != null)
                    _buildNutritionInfo('Fat', '${recipe['fats']}g'),
                  _buildNutritionInfo('Time', '${_getCookingTime(recipe)} min'),
                ],
              ),
              const SizedBox(height: 16),

              if (recipe['ingredients'] != null &&
                  (recipe['ingredients'] as List).isNotEmpty) ...[
                const Text(
                  'Ingredients',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C4322),
                  ),
                ),
                const SizedBox(height: 8),

                ...List.generate(
                  recipe['ingredients'].length,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.circle,
                            size: 8, color: Color(0xFF1C4322)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _formatIngredient(recipe['ingredients'][i]),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (recipe['instructions'] != null &&
                  recipe['instructions'].toString().isNotEmpty) ...[
                const Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C4322),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInstructions(recipe['instructions']),
              ],

              if (recipe['tags'] != null &&
                  (recipe['tags'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Tags',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C4322),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (recipe['tags'] as List)
                      .map((t) => Chip(
                            label: Text(t.toString(),
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor:
                                const Color.fromARGB(255, 230, 213, 162),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Expanded(
                  //   child: ElevatedButton(
                  //     onPressed: () {
                  //       Navigator.pop(context);
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(
                  //           builder: (_) => RecipeDetailPage(
                  //             recipe: recipe,
                  //             recipeId: recipe['id'],
                  //           ),
                  //         ),
                  //       );
                  //     },
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: const Color(0xFF1C4322),
                  //       foregroundColor: Colors.white,
                  //       padding: const EdgeInsets.symmetric(vertical: 12),
                  //       shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12)),
                  //     ),
                  //     child: const Text('View Full Recipe'),
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions(dynamic instructions) {
    if (instructions is String) {
      return Html(
        data: instructions,
        style: {"body": Style(fontSize: FontSize(16), color: Colors.black87)},
      );
    }

    if (instructions is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          instructions.length,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C4322),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(instructions[i].toString(),
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Text(instructions.toString(),
        style: const TextStyle(fontSize: 14, color: Colors.black87));
  }

  String _formatIngredient(dynamic ingredient) {
    if (ingredient is Map) {
      final amount = ingredient['amount'];
      final unit = ingredient['unit'];
      final name = ingredient['name'];

      if (amount != null && unit != null && name != null) {
        return '$amount $unit $name';
      }
      if (amount != null && name != null) return '$amount $name';
      if (name != null) return name.toString();
    }
    return ingredient.toString();
  }

  Widget _buildNutritionInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C4322))),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              backgroundColor: const Color(0xFFF8F8F8),

      appBar: AppBar(
        title: const Text('Favorite Recipes'),
        backgroundColor: const Color(0xFFF8F8F8),
        foregroundColor: const Color(0xFF1C4322),
        actions: [
          IconButton(
              onPressed: _refreshFavorites,
              icon: const Icon(Icons.refresh))
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final favorites = snapshot.data ?? [];
          if (favorites.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) =>
                _buildRecipeCard(favorites[index]),
          );
        },
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final description = _getRecipeDescription(recipe);

    return Card(
           color:   const Color(0xFFF8F8F8)
,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showRecipeDetails(recipe),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(_getRecipeTitle(recipe),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C4322)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    onPressed: () async {
                      await _repository.toggleFavorite(recipe);
                      _refreshFavorites();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Removed from favorites'),
                            duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.favorite, color: Colors.red),
                  )
                ],
              ),

              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.grey)),
                ),

              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.schedule,
                      '${_getCookingTime(recipe)} min'),
                  _buildInfoChip(Icons.local_fire_department,
                      '${_getCalories(recipe)} cal'),
                  if (_getProtein(recipe) > 0)
                    _buildInfoChip(
                        Icons.fitness_center, '${_getProtein(recipe)}g protein'),
                ],
              ),

              if (recipe['tags'] != null &&
                  (recipe['tags'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    children: (recipe['tags'] as List)
                        .take(3)
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  const Color.fromARGB(255, 230, 213, 162),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(tag.toString(),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.brown)),
                          ),
                        )
                        .toList(),
                  ),
                ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showRecipeDetails(recipe),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1C4322)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(text,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF1C4322))),
          SizedBox(height: 16),
          Text('Loading your favorites...',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error loading favorites',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshFavorites,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C4322),
                foregroundColor: Colors.white),
            child: const Text('Try Again'),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 50, color: Colors.grey),
          SizedBox(height: 16),
          Text('No favorites yet',
              style:
                  TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          // const Text('Tap the heart icon to add recipes here',
          //     textAlign: TextAlign.center,
          //     style: TextStyle(color: Colors.grey)),
          // const SizedBox(height: 30),
          // ElevatedButton.icon(
          //   onPressed: () => Navigator.pop(context),
          //   icon: const Icon(Icons.restaurant),
          //   label: const Text('Browse Recipes'),
          //   style: ElevatedButton.styleFrom(
          //       backgroundColor: const Color(0xFF1C4322),
          //       foregroundColor: Colors.white),
          // )
        ],
      ),
    );
  }
}
