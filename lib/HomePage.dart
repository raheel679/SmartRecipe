import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  final String goal;
  const HomePage({super.key, required this.goal});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<String> ingredients = [];

  // Add ingredient to the list
  void _addIngredient() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !ingredients.contains(text)) {
      setState(() {
        ingredients.add(text);
        _controller.clear();
      });
    }
  }

  // Build Firestore query based on ingredients
  Stream<QuerySnapshot> _getRecipesStream() {
    if (ingredients.isEmpty) {
      return FirebaseFirestore.instance.collection('meals').snapshots();
    } else {
      // Assuming each meal document has a field "ingredients" which is a List<String>
      return FirebaseFirestore.instance
          .collection('meals')
          .where('ingredients', arrayContainsAny: ingredients)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Recipe App"),
        backgroundColor: const Color(0xFF1C4322),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your selected goal: ${widget.goal}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF485935),
              ),
            ),
            const SizedBox(height: 20),

            // Ingredient input
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Add Ingredient",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addIngredient,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addIngredient(),
            ),
            const SizedBox(height: 10),

            // Display ingredients as chips
            Wrap(
              spacing: 8,
              children: ingredients
                  .map((ingredient) => Chip(
                        label: Text(ingredient),
                        onDeleted: () {
                          setState(() {
                            ingredients.remove(ingredient);
                          });
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            const Text(
              "Recipes:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Recipes list from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getRecipesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No recipes found."));
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final meal = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          leading: meal['imageUrl'] != null
                              ? Image.network(meal['imageUrl'], width: 60, fit: BoxFit.cover)
                              : null,
                          title: Text(meal['name'] ?? 'Unnamed Meal'),
                          subtitle: Text(
                              "${meal['dietType'] ?? ''} • ${meal['time'] ?? 0} min"),
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
    );
  }
}
