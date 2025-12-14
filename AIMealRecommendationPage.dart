import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'RecipeDetailPage.dart';

class AIMealRecommendationPage extends StatefulWidget {
  final String goal;

  const AIMealRecommendationPage({super.key, required this.goal});

  @override
  State<AIMealRecommendationPage> createState() => _AIMealRecommendationPageState();
}

class _AIMealRecommendationPageState extends State<AIMealRecommendationPage> {
  List<Map<String, String>> aiMeals = [];
  bool isLoading = false;
  final TextEditingController ingredientsController = TextEditingController();

  Future<void> fetchAIMeals() async {
    setState(() {
      isLoading = true;
      aiMeals = [];
    });

    final ingredients = ingredientsController.text.trim();
    final prompt = """
Suggest 5 recipes for ${widget.goal}${ingredients.isNotEmpty ? " using these ingredients: $ingredients" : ""}.
Return JSON array with: title, description, cookingTime (minutes), calories, protein (g), carbs (g), fats (g).
""";

    try {
      final response = await http.post(
  Uri.parse("https://api-inference.huggingface.co/models/google/flan-t5-small"),
  headers: {
    "Authorization": "Bearer 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",
    "Content-Type": "application/json",
  },
  body: jsonEncode({
    "inputs": "Suggest 5 recipes for weight loss. Return JSON array with title, description, cookingTime, calories, protein, carbs, fats."
  }),
);


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Hugging Face returns generated_text inside a list
        final content = data[0]['generated_text'];

        // Parse JSON array from generated text
        final List parsed = jsonDecode(content);
        setState(() {
          aiMeals = parsed.map<Map<String, String>>((item) {
            return {
              "title": item["title"] ?? "No Title",
              "description": item["description"] ?? "",
              "cookingTime": item["cookingTime"]?.toString() ?? "0",
              "calories": item["calories"]?.toString() ?? "0",
              "protein": item["protein"]?.toString() ?? "0",
              "carbs": item["carbs"]?.toString() ?? "0",
              "fats": item["fats"]?.toString() ?? "0",
            };
          }).toList();
        });
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("❌ Exception: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    ingredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Meal & Nutrition Recommendations"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: ingredientsController,
              decoration: const InputDecoration(
                hintText: "Enter ingredients (optional)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.kitchen),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: fetchAIMeals,
              child: const Text("Get AI Suggestions"),
            ),
            const SizedBox(height: 12),
            if (isLoading) const CircularProgressIndicator(),
            Expanded(
              child: ListView.builder(
                itemCount: aiMeals.length,
                itemBuilder: (context, index) {
                  final meal = aiMeals[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(meal["title"]!),
                      subtitle: Text(
                        "${meal["description"]}\n"
                        "Cooking Time: ${meal["cookingTime"]} mins\n"
                        "Calories: ${meal["calories"]} kcal | "
                        "Protein: ${meal["protein"]} g | "
                        "Carbs: ${meal["carbs"]} g | "
                        "Fats: ${meal["fats"]} g",
                      ),
                      isThreeLine: true,
                      onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RecipeDetailPage(
        recipe: meal,
        recipeId: "ai_$index",
        goal: meal['goal'] ?? "general",
        dietType: meal['dietType'] ?? "none",
      ),
    ),
  );
},

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
