import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';

class IngredientSearchPage extends StatefulWidget {
  final String goal;

  const IngredientSearchPage({super.key, required this.goal});

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

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          recipes = (data["results"] as List).map((r) => {
                "name": r["title"],
                "ingredients": (r["extendedIngredients"] as List?)
                        ?.map((i) => i["name"])
                        .toList() ??
                    [],
                "time": r["readyInMinutes"] ?? 0,
                "imageUrl": r["image"] ?? "",
                "instructions": r["summary"] ?? "No instructions available",
              }).toList();
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load recipes");
      }
    } catch (e) {
      setState(() {
        recipes = [];
        isLoading = false;
      });
      print("Error fetching recipes: $e");
    }
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
              Text(
                recipe["name"],
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
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
      // appBar: AppBar(
      //   title: const Text("Smart Recipe Finder"),
      //   backgroundColor: Colors.green.shade600,
      // ),
                    backgroundColor: const Color.fromARGB(255, 249, 249, 249), // Light blue background

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            
               Align(
        alignment: Alignment.centerLeft, // Aligns the text to the left
        child: Text(
          "Your goal: ${widget.goal}",
          style: const TextStyle(
            locale: Locale.fromSubtags(),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromRGBO(165, 214, 167, 1),
          ),
        ),
      ),
            const SizedBox(height: 12),

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
                const SizedBox(width: 8,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add,
                  color: Colors.white,),
                  label: const Text("Add",
                  style: TextStyle(color: Colors.white),),
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
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Max Time:"),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8, // space between buttons
        children: maxTimeOptions.map((time) {
          final isSelected = selectedMaxTime == time;
          return ChoiceChip(
            label: Text("$time min"),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                selectedMaxTime = time;
                _fetchRecipes(); // refresh meal list
              });
            },
            selectedColor: const Color.fromRGBO(165, 214, 167, 1),
            backgroundColor: Colors.grey[200],
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : Colors.grey[800],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _fetchRecipes,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C4322)),
              child: const Text("Search Recipes",
              style: TextStyle(color: Colors.white),),
            ),

            const SizedBox(height: 20),

            // Results
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : recipes.isEmpty
                      ? const Center(child: Text("No recipes yet"))
                      : ListView.builder(
                          itemCount: recipes.length,
                          itemBuilder: (context, index) {
                            final r = recipes[index];

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image with rounded top corners
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                    child: r["imageUrl"] != ""
                                        ? Image.network(
                                            r["imageUrl"],
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            height: 180,
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.fastfood,
                                                size: 60),
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r["name"],
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "Cooking Time: ${r["time"]} min",
                                          style: const TextStyle(fontSize: 14),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: Text("• $ing"),
                                            )),
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _showInstructions(r),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                const Color(0xFF1C4322),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                            ),
                                            child: const Text("View Steps",
                                            style: TextStyle(color: Colors.white),),
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
}
