
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'favorites_repository.dart';
import 'RecipeDetailPage.dart';


class MealRecommendationPage extends StatefulWidget {
  final String goal;


  const MealRecommendationPage({super.key, required this.goal});


  @override
  State<MealRecommendationPage> createState() => _MealRecommendationPageState();
}


class _MealRecommendationPageState extends State<MealRecommendationPage> {
  // Firebase meals state
  late Future<List<Map<String, dynamic>>> _firebaseMealsFuture;
  final List<String> timerOptions = ["All", "<15", "15-30", ">30"];
  String? userName;
  String categoryFilter = "All";
  List<String> dynamicCategories = ["All", "Snack", "Dinner", "Breakfast", "Lunch"]; // UPDATED HERE
  String searchQuery = "";
  String timerFilter = "All";


  // Tab state
  final int _currentTab = 0;
  final FavoritesRepository _favoritesRepository = FavoritesRepository();


  @override
  void initState() {
    super.initState();
    _firebaseMealsFuture = _fetchFirebaseMeals();
    _fetchUserName();
  }


  // Firebase meals methods
  Future<List<Map<String, dynamic>>> _fetchFirebaseMeals() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('recipe')
          .where('goal', isEqualTo: widget.goal);


      final snapshot = await query.get();


      List<Map<String, dynamic>> meals = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return data;
      }).toList();


      // Apply cooking time filter
      meals = meals.where((meal) {
        final time = (meal['cookingTime'] ?? 0);
        if (time is! int) return false;
        if (timerFilter == "<15") return time < 15;
        if (timerFilter == "15-30") return time >= 15 && time <= 30;
        if (timerFilter == ">30") return time > 30;
        return true;
      }).toList();


      // Apply category filter - only show meals that match our allowed categories
      if (categoryFilter != "All") {
        meals = meals.where((meal) {
          final cat = meal['category']?.toString() ?? '';
          return cat == categoryFilter;
        }).toList();
      } else {
        // When "All" is selected, only show meals from our allowed categories
        meals = meals.where((meal) {
          final cat = meal['category']?.toString() ?? '';
          return dynamicCategories.contains(cat);
        }).toList();
      }


      // Apply search filter
      if (searchQuery.isNotEmpty) {
        meals = meals.where((meal) {
          final title = meal['title']?.toString().toLowerCase() ?? '';
          return title.contains(searchQuery.toLowerCase());
        }).toList();
      }


      return meals;
    } catch (e) {
      print("❌ Error fetching meals: $e");
      return [];
    }
  }


  void _refreshFirebaseMeals() {
    setState(() {
      _firebaseMealsFuture = _fetchFirebaseMeals();
    });
  }


  Future<void> _fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();
        if (doc.exists) {
          setState(() {
            userName = doc.data()?['name'] ?? "";
          });
        }
      }
    } catch (e) {
      print("❌ Error fetching user name: $e");
    }
  }


  // Favorite button widget
  Widget _buildFavoriteButton(Map<String, dynamic> meal) {
    return FutureBuilder<bool>(
      future: _favoritesRepository.isFavorite(meal['id'] ?? ''),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;
        
        return IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.grey,
          ),
          onPressed: () async {
            await _favoritesRepository.toggleFavorite(meal);
            // Refresh the UI
            if (mounted) {
              setState(() {});
            }
            
            // Show feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isFavorite ? 'Removed from favorites' : 'Added to favorites!',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: isFavorite ? Colors.grey : const Color(0xFF1C4322),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }


  // Mark as cooked functionality
  void _markAsCooked(Map<String, dynamic> recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Cooked'),
        content: const Text('Would you like to rate this recipe?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add to history without rating
              _favoritesRepository.addToHistory(recipe);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Added to cooking history!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showRatingDialog(recipe);
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }


  // Show rating dialog
  void _showRatingDialog(Map<String, dynamic> recipe) {
    int rating = 0;
    final TextEditingController commentController = TextEditingController();


    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rate this Recipe'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How was your cooking experience?'),
                const SizedBox(height: 16),
                // Star rating
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
                // Comment field
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comments (optional)',
                    border: OutlineInputBorder(),
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
              TextButton(
                onPressed: () async {
                  if (rating > 0) {
                    await _favoritesRepository.addToHistory(
                      recipe, 
                      userRating: rating, 
                      userComment: commentController.text
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rated $rating stars and added to history!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    // Add without rating if user doesn't rate
                    await _favoritesRepository.addToHistory(recipe);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to cooking history!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          toolbarHeight: 5,
          backgroundColor: const Color(0xFFF8F8F8),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Color.fromARGB(255, 206, 145, 14),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
            ),
            tabs: [
              Tab(icon: Icon(Icons.restaurant), text: 'Recipe Library'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'Smart Search'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFirebaseRecipesTab(),
            IngredientSearchPage(goal: widget.goal, favoritesRepository: _favoritesRepository),
          ],
        ),
      ),
    );
  }


  Widget _buildFirebaseRecipesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Field
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search recipes...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
              _refreshFirebaseMeals();
            },
          ),
        ),


        // Filters Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Filter
              const Text(
                "Category:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: dynamicCategories.length,
                  itemBuilder: (context, index) {
                    final category = dynamicCategories[index];
                    final isSelected = categoryFilter == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            categoryFilter = category;
                            _refreshFirebaseMeals();
                          });
                        },
                        selectedColor: const Color(0xFF1C4322),
                        backgroundColor: Colors.grey.shade200,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),


              // Timer Filter
              const Text(
                "Cooking Time:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: timerOptions.map((option) {
                  final isSelected = timerFilter == option;
                  return ChoiceChip(
                    label: Text(option == "All" ? "Any Time" : "$option mins"),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        timerFilter = option;
                        _refreshFirebaseMeals();
                      });
                    },
                    selectedColor: const Color(0xFF1C4322),
                    backgroundColor: Colors.grey.shade200,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),


        const SizedBox(height: 16),


        // Meals List
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _firebaseMealsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Loading recipes..."),
                    ],
                  ),
                );
              }


              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        "Error loading recipes",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _refreshFirebaseMeals,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C4322),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                );
              }


              final meals = snapshot.data ?? [];
              if (meals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "No recipes found",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        searchQuery.isNotEmpty || categoryFilter != "All" || timerFilter != "All"
                            ? "Try adjusting your filters"
                            : "No recipes found for '${widget.goal}'",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _refreshFirebaseMeals,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C4322),
                        ),
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                );
              }


              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: meals.length,
                itemBuilder: (context, index) {
                  final meal = meals[index];
                  return _buildMealCard(meal);
                },
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildMealCard(Map<String, dynamic> meal) {
    return Card(
      color: const Color(0xFFF8F8F8),

      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RecipeDetailPage(
        recipe: meal,
        recipeId: meal['id'],
        goal: meal['goal'] ?? "general",
        dietType: meal['dietType'] ?? "any",
      ),
    ),
  );
},

        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                meal['title'] ?? 'Recipe',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1C4322),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Cook button and Favorite button
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                  onPressed: () => _markAsCooked(meal),
                                  tooltip: 'Mark as cooked',
                                ),
                                _buildFavoriteButton(meal),
                              ],
                            ),
                          ],
                        ),
                        if (meal['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            meal['description']!,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),


              // Nutrition and time info
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.schedule, '${meal['cookingTime'] ?? 0} min'),
                  _buildInfoChip(Icons.local_fire_department, '${meal['calories'] ?? 0} cal'),
                  if (meal['protein'] != null)
                    _buildInfoChip(Icons.fitness_center, '${meal['protein']}g protein'),
                ],
              ),


              // Tags
              if (meal['tags'] != null && (meal['tags'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: (meal['tags'] as List<dynamic>)
                      .take(3)
                      .map((tag) => Chip(
                            label: Text(
                              tag.toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
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
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}


// Your working Spoonacular API page - integrated as the AI tab
class IngredientSearchPage extends StatefulWidget {
  final String goal;
  final FavoritesRepository favoritesRepository;


  const IngredientSearchPage({
    super.key, 
    required this.goal,
    required this.favoritesRepository,
  });


  @override
  State<IngredientSearchPage> createState() => _IngredientSearchPageState();
}


class _IngredientSearchPageState extends State<IngredientSearchPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController ingredientController = TextEditingController();
  final List<int> maxTimeOptions = [15, 30, 45, 60];


  List<String> ingredients = [];
  int selectedMaxTime = 30;
  bool isLoading = false;
  List<Map<String, dynamic>> recipes = [];


  @override
  bool get wantKeepAlive => true;


  String _getGoalFilter() {
    switch (widget.goal.toLowerCase()) {
      case "weight loss":
        return "&maxCalories=500";
      case "muscle gain":
        return "&minProtein=20";
      case "healthy lifestyle":
      case "healthy maintenance":
        return "&minProtein=10&maxCalories=700";
      default:
        return "";
    }
  }


  Future<void> _fetchRecipes() async {
    if (ingredients.isEmpty) return;


    setState(() => isLoading = true);


    try {
      const apiKey = "39e25ec02d7e4e39889a38a7e08b5ee4";
      final query = ingredients.join(",");
      final goalFilter = _getGoalFilter();


      final url =
          "https://api.spoonacular.com/recipes/complexSearch"
          "?apiKey=$apiKey"
          "&includeIngredients=$query"
          "&maxReadyTime=$selectedMaxTime"
          "$goalFilter"
          "&number=10"
          "&addRecipeInformation=true";


      print("🔍 Calling Spoonacular API: $url");


      final response = await http.get(Uri.parse(url));


      if (response.statusCode == 200) {
        final data = json.decode(response.body);


        setState(() {
          recipes = (data["results"] as List).map((r) => {
                "title": r["title"],
                "description": _parseDescription(r["summary"] ?? "Delicious recipe created for you."),
                "ingredients": (r["extendedIngredients"] as List?)
                        ?.map((i) => i["name"])
                        .toList() ??
                    [],
                "cookingTime": r["readyInMinutes"] ?? 0,
                "calories": _extractCalories(r),
                "protein": _extractProtein(r),
                "carbs": _extractCarbs(r),
                "fats": _extractFats(r),
                "imageUrl": r["image"] ?? "",
                "instructions": r["summary"] ?? "No instructions available",
                "isAI": true,
                "id": "spoonacular_${r["id"]}",
                "tags": _extractTags(r),
              }).toList();
          isLoading = false;
        });
       
        print("✅ Found ${recipes.length} recipes from Spoonacular");
      } else {
        throw Exception("Failed to load recipes: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        recipes = [];
        isLoading = false;
      });
      print("❌ Error fetching recipes: $e");
     
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to fetch recipes. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  String _parseDescription(String summary) {
    // Clean up HTML tags and limit length
    final cleanText = summary.replaceAll(RegExp(r'<[^>]*>'), '');
    return cleanText.length > 150
        ? '${cleanText.substring(0, 150)}...'
        : cleanText;
  }


  int _extractCalories(Map<String, dynamic> recipe) {
    try {
      final nutrition = recipe["nutrition"];
      if (nutrition != null && nutrition["nutrients"] != null) {
        final calories = (nutrition["nutrients"] as List).firstWhere(
          (nutrient) => nutrient["name"]?.toLowerCase().contains("calorie") == true,
          orElse: () => {"amount": 0},
        );
        return (calories["amount"] ?? 0).toInt();
      }
    } catch (e) {
      print("Error extracting calories: $e");
    }
    return 350;
  }


  int _extractProtein(Map<String, dynamic> recipe) {
    try {
      final nutrition = recipe["nutrition"];
      if (nutrition != null && nutrition["nutrients"] != null) {
        final protein = (nutrition["nutrients"] as List).firstWhere(
          (nutrient) => nutrient["name"]?.toLowerCase().contains("protein") == true,
          orElse: () => {"amount": 0},
        );
        return (protein["amount"] ?? 0).toInt();
      }
    } catch (e) {
      print("Error extracting protein: $e");
    }
    return 20;
  }


  int _extractCarbs(Map<String, dynamic> recipe) {
    try {
      final nutrition = recipe["nutrition"];
      if (nutrition != null && nutrition["nutrients"] != null) {
        final carbs = (nutrition["nutrients"] as List).firstWhere(
          (nutrient) => nutrient["name"]?.toLowerCase().contains("carb") == true,
          orElse: () => {"amount": 0},
        );
        return (carbs["amount"] ?? 0).toInt();
      }
    } catch (e) {
      print("Error extracting carbs: $e");
    }
    return 45;
  }


  int _extractFats(Map<String, dynamic> recipe) {
    try {
      final nutrition = recipe["nutrition"];
      if (nutrition != null && nutrition["nutrients"] != null) {
        final fat = (nutrition["nutrients"] as List).firstWhere(
          (nutrient) => nutrient["name"]?.toLowerCase().contains("fat") == true,
          orElse: () => {"amount": 0},
        );
        return (fat["amount"] ?? 0).toInt();
      }
    } catch (e) {
      print("Error extracting fats: $e");
    }
    return 12;
  }


  List<String> _extractTags(Map<String, dynamic> recipe) {
    final tags = <String>[];
   
    if (recipe["vegetarian"] == true) tags.add("vegetarian");
    if (recipe["vegan"] == true) tags.add("vegan");
    if (recipe["glutenFree"] == true) tags.add("gluten-free");
   
    final time = recipe["readyInMinutes"] ?? 0;
    if (time < 20) tags.add("quick");
    if (time > 45) tags.add("slow-cooked");
   
    tags.add("api-generated");
    tags.add(widget.goal.toLowerCase());
   
    return tags.take(4).toList();
  }


  // Favorite button for Spoonacular recipes
  Widget _buildFavoriteButton(Map<String, dynamic> recipe) {
    return FutureBuilder<bool>(
      future: widget.favoritesRepository.isFavorite(recipe['id'] ?? ''),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;
        
        return IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.grey,
          ),
          onPressed: () async {
            await widget.favoritesRepository.toggleFavorite(recipe);
            // Refresh the UI
            if (mounted) {
              setState(() {});
            }
            
            // Show feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isFavorite ? 'Removed from favorites' : 'Added to favorites!',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: isFavorite ? Colors.grey : const Color(0xFF1C4322),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }


  // Mark as cooked functionality for Spoonacular recipes
  void _markAsCooked(Map<String, dynamic> recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Cooked'),
        content: const Text('Would you like to rate this recipe?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.favoritesRepository.addToHistory(recipe);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Added to cooking history!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showRatingDialog(recipe);
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }


  // Show rating dialog for Spoonacular recipes
  void _showRatingDialog(Map<String, dynamic> recipe) {
    int rating = 0;
    final TextEditingController commentController = TextEditingController();


    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rate this Recipe'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How was your cooking experience?'),
                const SizedBox(height: 16),
                // Star rating
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
                // Comment field
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comments (optional)',
                    border: OutlineInputBorder(),
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
              TextButton(
                onPressed: () async {
                  if (rating > 0) {
                    await widget.favoritesRepository.addToHistory(
                      recipe, 
                      userRating: rating, 
                      userComment: commentController.text
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rated $rating stars and added to history!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    // Add without rating if user doesn't rate
                    await widget.favoritesRepository.addToHistory(recipe);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to cooking history!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }


  void _showInstructions(Map<String, dynamic> recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      recipe["title"],
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                        onPressed: () => _markAsCooked(recipe),
                        tooltip: 'Mark as cooked',
                      ),
                      _buildFavoriteButton(recipe),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Html(data: recipe["instructions"]),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 249, 249),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input + button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ingredientController,
                    decoration: InputDecoration(
                      labelText: "Enter ingredient",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Add", style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    if (ingredientController.text.isNotEmpty) {
                      setState(() {
                        ingredients.add(ingredientController.text.trim());
                        ingredientController.clear();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C4322)),
                ),
              ],
            ),


            const SizedBox(height: 10),


            // Chips
            Wrap(
              spacing: 8,
              children: ingredients
                  .map((ing) => Chip(
                        backgroundColor: Colors.green.shade100,
                        label: Text(ing),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () {
                          setState(() {
                            ingredients.remove(ing);
                          });
                        },
                      ))
                  .toList(),
            ),


            const SizedBox(height: 10),


            // Max time
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT — Max Time + Chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Max Time:",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: maxTimeOptions.map((time) {
                            final isSelected = selectedMaxTime == time;
                            return ChoiceChip(
                              label: Text("$time min"),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  selectedMaxTime = time;
                                });
                              },
                              selectedColor: const Color.fromRGBO(165, 214, 167, 1),
                              backgroundColor: Colors.grey[200],
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : Colors.grey[800],
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),


                  // RIGHT — Search Button
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _fetchRecipes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C4322),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Search Recipes",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),


            const SizedBox(height: 20),


            // Results
            Expanded(
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Searching for recipes..."),
                        ],
                      ),
                    )
                  : recipes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                "No recipes yet",
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Add ingredients and search to find recipes!",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: recipes.length,
                          itemBuilder: (context, index) {
                            final r = recipes[index];


                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              color: const Color.fromARGB(255, 243, 240, 231),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Title with favorite button
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                r["title"],
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                                  onPressed: () => _markAsCooked(r),
                                                  tooltip: 'Mark as cooked',
                                                ),
                                                _buildFavoriteButton(r),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "Cooking Time: ${r["cookingTime"]} min",
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            _buildNutritionChip(
                                                Icons.local_fire_department,
                                                '${r["calories"]} cal'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "Ingredients:",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        ...r["ingredients"].map<Widget>((ing) =>
                                            Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 2),
                                              child: Text("• $ing"),
                                            )),
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton(
                                            onPressed: () => _showInstructions(r),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color.fromARGB(255, 230, 213, 162),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12)),
                                            ),
                                            child: const Text("View Steps", style: TextStyle(color: Colors.white)),
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
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildNutritionChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color.fromARGB(255, 68, 26, 26)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 178, 70, 70)),
          ),
        ],
      ),
    );
  }
}
